//
//  AEBaiduStorage.swift
//  AECloudStorage
//
//  Created on 2026/09/05.
//

import Foundation
import CommonCrypto
import AELogProxy

/// 百度网盘云存储（AEStorageInterface provider 实现）
public final class AEBaiduStorage: AEStorageInterface, AEBDCredentialDelegate {

    // MARK: - Constants

    private static let panHost = "https://pan.baidu.com"
    private static let urlFile = panHost + "/rest/2.0/xpan/file"            // list/precreate/create/search
    private static let urlUInfo = panHost + "/rest/2.0/xpan/nas"             // uinfo
    private static let urlSuperFile = "https://d.pcs.baidu.com/rest/2.0/pcs/superfile2"  // 上传分片
    private static let urlDownload = "https://d.pcs.baidu.com/rest/2.0/pcs/file"          // 下载

    private static let pageLimit = 1000
    private static let uploadChunk = 4 * 1024 * 1024   // 4MB
    private static let uploadRtype = 3                  // 重名策略
    private static let emptyMd5 = "d41d8cd98f00b204e9800998ecf8427e"

    // MARK: - Properties

    public let uid: String
    public let name = "AEBaiduStorage"
    public let baseDir: String
    public private(set) var isLoaded = false

    public let appName: String
    public let credentialPath: URL
    public let credential: AEBDCredential

    // MARK: - Init

    public init(appName: String, appKey: String, appSecret: String, credentialPath: URL) {

        self.appName = appName
        self.credentialPath = credentialPath
        self.baseDir = "/apps/" + appName
        self.uid = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        self.credential = AEBDCredential(appName: appName,
                                          appKey: appKey,
                                          appSecret: appSecret,
                                          credentialPath: credentialPath)
        self.credential.delegate = self
    }

    // MARK: - AEBDCredentialDelegate

    func credentialOnValid(_ cred: AEBDCredential) {
        isLoaded = true
    }

    func credentialOnRefreshed(_ cred: AEBDCredential) {
        isLoaded = true
    }

    /// 首次授权校验（构造后调用；内部刷新/标记 isLoaded）
    public func verify() async -> Bool {
        let ok = await credential.verify()
        isLoaded = ok || isLoaded
        return ok
    }

    // MARK: - HTTP

    /// GET（access_token + openapi=xpansdk 在 query）
    private func get(_ url: String, query: [String: String]) async throws -> [String: Any] {
        try await request(url: url, method: "GET", query: query, body: nil, contentType: nil)
    }

    /// POST 表单
    private func postForm(_ url: String, query: [String: String], body: [String: String]) async throws -> [String: Any] {
        let bodyStr = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        return try await request(url: url, method: "POST", query: query,
                                 body: bodyStr.data(using: .utf8),
                                 contentType: "application/x-www-form-urlencoded")
    }

    /// POST multipart（单个 file 分片，用于 superfile2）
    private func postMultipart(_ url: String, query: [String: String], fileData: Data, fileName: String) async throws -> [String: Any] {

        let boundary = "----AEBoundary" + UUID().uuidString
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        return try await request(url: url, method: "POST", query: query,
                                 body: body,
                                 contentType: "multipart/form-data; boundary=\(boundary)")
    }

    private func request(url: String, method: String, query: [String: String], body: Data?, contentType: String?) async throws -> [String: Any] {

        var components = URLComponents(string: url)
        var items = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "openapi", value: "xpansdk"))
        items.append(URLQueryItem(name: "access_token", value: try await credential.getAccessToken()))
        components?.queryItems = items

        guard let url = components?.url else {
            throw NSError(domain: "AEBaiduStorage", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL 无效"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
            if let contentType = contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            AELog("⚠️ [CloudStorage] Baidu 接口请求失败")
            throw NSError(domain: "AEBaiduStorage", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP 错误"])
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            AELog("⚠️ [CloudStorage] Baidu 响应解析失败")
            throw NSError(domain: "AEBaiduStorage", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "JSON 解析失败"])
        }
        return json
    }

    /// 校验 errno（0/nil 为成功）
    private func checkErrno(_ json: [String: Any]) throws {
        let errno = json["errno"] as? Int
        if errno == 0 || errno == nil { return }
        AELog("⚠️ [CloudStorage] Baidu 接口返回错误 errno:\(errno ?? -1)")
        throw NSError(domain: "AEBaiduStorage", code: -4,
                      userInfo: [NSLocalizedDescriptionKey: "Baidu errno \(errno ?? -1)"])
    }

    // MARK: - AEStorageInterface: listFiles

    public func listFiles(remoteDir: String) async throws -> [AECloudFile] {
        let dir = resolvePath(remoteDir)
        var result: [AECloudFile] = []
        var start = 0
        repeat {
            let json = try await get(AEBaiduStorage.urlFile, query: [
                "method": "list",
                "dir": dir,
                "order": "time",
                "desc": "1",
                "start": String(start),
                "limit": String(AEBaiduStorage.pageLimit),
                "web": "web",
                "showempty": "1"
            ])
            try checkErrno(json)
            let batch = (json["list"] as? [[String: Any]]) ?? []
            result.append(contentsOf: batch.compactMap { AEBDFile.fromDict($0) })
            start += AEBaiduStorage.pageLimit
            if batch.count < AEBaiduStorage.pageLimit { break }
        } while true
        return result
    }

    // MARK: - AEStorageInterface: upload（precreate → superfile2 → create）

    public func upload(localPath: String, remotePath: String) async throws -> [String: Any] {
        let url = URL(fileURLWithPath: localPath)
        let fileData = try Data(contentsOf: url)
        let size = fileData.count
        let remote = resolvePath(remotePath)
        let basename = (remote as NSString).lastPathComponent

        // 1. 计算 block_list（每 4MB 分片 MD5；空文件 → [emptyMd5]）
        let blockList: [String]
        if size == 0 {
            blockList = [AEBaiduStorage.emptyMd5]
        } else {
            var blocks: [String] = []
            var offset = 0
            while offset < size {
                let end = min(offset + AEBaiduStorage.uploadChunk, size)
                let chunk = fileData.subdata(in: offset..<end)
                blocks.append(md5Hex(chunk))
                offset = end
            }
            blockList = blocks
        }
        let blockListJson = (try? JSONSerialization.data(withJSONObject: blockList))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        // 2. precreate
        let pre = try await postForm(AEBaiduStorage.urlFile, query: ["method": "precreate"], body: [
            "path": remote,
            "isdir": "0",
            "size": String(size),
            "autoinit": "1",
            "block_list": blockListJson,
            "rtype": String(AEBaiduStorage.uploadRtype)
        ])
        try checkErrno(pre)
        guard let uploadid = pre["uploadid"] as? String else {
            throw NSError(domain: "AEBaiduStorage", code: -5,
                          userInfo: [NSLocalizedDescriptionKey: "precreate 无 uploadid"])
        }

        // 3. superfile2（逐分片上传）
        var partseq = 0
        var offset = 0
        while offset < size {
            let end = min(offset + AEBaiduStorage.uploadChunk, size)
            let chunk = fileData.subdata(in: offset..<end)
            _ = try await postMultipart(AEBaiduStorage.urlSuperFile, query: [
                "method": "upload",
                "partseq": String(partseq),
                "path": remote,
                "uploadid": uploadid,
                "type": "tmpfile"
            ], fileData: chunk, fileName: basename)
            partseq += 1
            offset = end
        }

        // 4. create
        let create = try await postForm(AEBaiduStorage.urlFile, query: ["method": "create"], body: [
            "path": remote,
            "isdir": "0",
            "size": String(size),
            "uploadid": uploadid,
            "block_list": blockListJson,
            "rtype": String(AEBaiduStorage.uploadRtype)
        ])
        try checkErrno(create)
        return ["errno": create["errno"] ?? 0, "local": localPath, "remote": remote, "size": size]
    }

    // MARK: - AEStorageInterface: download

    public func download(remotePath: String, localPath: String) async throws -> String {
        let remote = resolvePath(remotePath)
        var components = URLComponents(string: AEBaiduStorage.urlDownload)
        components?.queryItems = [
            URLQueryItem(name: "method", value: "download"),
            URLQueryItem(name: "openapi", value: "xpansdk"),
            URLQueryItem(name: "access_token", value: try await credential.getAccessToken()),
            URLQueryItem(name: "path", value: remote)
        ]
        guard let url = components?.url else {
            throw NSError(domain: "AEBaiduStorage", code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "下载 URL 无效"])
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            AELog("⚠️ [CloudStorage] 下载失败")
            throw NSError(domain: "AEBaiduStorage", code: -7,
                          userInfo: [NSLocalizedDescriptionKey: "下载失败"])
        }
        let localURL = URL(fileURLWithPath: localPath)
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: localURL, options: [.atomic])
        return localPath
    }

    // MARK: - AEStorageInterface: mkdir（precreate isdir=1 → create）

    public func mkdir(remotePath: String) async throws -> [String: Any] {
        let remote = resolvePath(remotePath)
        let pre = try await postForm(AEBaiduStorage.urlFile, query: ["method": "precreate"], body: [
            "path": remote,
            "isdir": "1",
            "size": "0",
            "autoinit": "1",
            "block_list": "[]",
            "rtype": String(AEBaiduStorage.uploadRtype)
        ])
        guard let uploadid = pre["uploadid"] as? String else {
            throw NSError(domain: "AEBaiduStorage", code: -8,
                          userInfo: [NSLocalizedDescriptionKey: "mkdir 无 uploadid"])
        }
        let create = try await postForm(AEBaiduStorage.urlFile, query: ["method": "create"], body: [
            "path": remote,
            "isdir": "1",
            "size": "0",
            "uploadid": uploadid,
            "block_list": "[]",
            "rtype": String(AEBaiduStorage.uploadRtype)
        ])
        try checkErrno(create)
        return ["errno": create["errno"] ?? 0, "remote": remote]
    }

    // MARK: - AEStorageInterface: delete / exists（暂未实现，镜像参考）

    public func delete(remotePath: String) async throws -> [String: Any] {
        AELog("⚠️ [CloudStorage] delete 未实现")
        throw NSError(domain: "AEBaiduStorage", code: -9,
                      userInfo: [NSLocalizedDescriptionKey: "delete 未实现"])
    }

    public func exists(remotePath: String) async throws -> Bool {
        AELog("⚠️ [CloudStorage] exists 未实现")
        throw NSError(domain: "AEBaiduStorage", code: -10,
                      userInfo: [NSLocalizedDescriptionKey: "exists 未实现"])
    }

    // MARK: - UserInfo

    /// 百度网盘用户信息
    public func userInfo() async throws -> [String: Any] {
        try await get(AEBaiduStorage.urlUInfo, query: ["method": "uinfo"])
    }

    // MARK: - MD5

    private func md5Hex(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            if let base = ptr.baseAddress {
                _ = CC_MD5(base, CC_LONG(data.count), &hash)
            }
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
