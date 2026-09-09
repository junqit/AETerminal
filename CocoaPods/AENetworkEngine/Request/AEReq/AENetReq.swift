//
//  AENetReq.swift
//  AENetworkEngine
//
//  Created by 田峻岐 on 2026/4/1.
//

import Foundation
import AELogProxy

/// 网络请求协议类型
public enum AENetProtocolType {
    
    case socket   // Socket/UDP 请求
    case http     // HTTP 请求
    case cloudstorage // 云存储请求
}

/// 消息类型标识（request / response），序列化到 req.headers.type
public enum AENetMessageType: Int {

    case request
    case response
}

/// HTTP 请求方式枚举
public enum AEHttpMethod: String {
    
    case GET                = "GET"
    case POST               = "POST"
    case PUT                = "PUT"
    case DELETE             = "DELETE"
    case PATCH              = "PATCH"
    case HEAD               = "HEAD"
    case OPTIONS            = "OPTIONS"
}

/// HTTP 请求对象
public class AENetReq {

    /// 请求唯一标识（内部 CRC32 生成）
    public private(set) var requestId: String

    /// 网络请求协议类型（默认为 socket）
    public var protocolType: AENetProtocolType = .socket

    /// 请求方式
    public var method: AEHttpMethod

    /// 请求路径（相对路径）
    public var path: String

    /// 请求参数
    public var parameters: [String: Any]?

    /// 请求头
    public var headers: [String: String]?

    /// 请求体（用于 POST、PUT 等）
    public var body: Data?

    /// 超时时间（秒）
    public var timeout: TimeInterval = 99999999

    /// 接收数据流回调（流式响应，可能多次调用）
    public var onStreamReceived: ((AENetRsp) -> Void)?

    /// 接收完整数据回调（请求完成时调用一次）
    public var onCompleted: ((AENetRsp) -> Void)?

    /// 初始化方法
    /// - Parameters:
    ///   - method: 请求方式
    ///   - path: 请求路径
    ///   - parameters: 请求参数
    ///   - headers: 请求头
    ///   - body: 请求体
    public init(method: AEHttpMethod,
                path: String,
                parameters: [String: Any]? = nil,
                headers: [String: String]? = nil,
                body: Data? = nil) {
        self.requestId = AENetReq.generateRequestId()
        self.method = method
        self.path = path
        self.parameters = parameters
        self.headers = headers
        self.body = body
    }

    /// 便利初始化方法 - GET 请求
    public convenience init(get path: String,
                           parameters: [String: Any]? = nil,
                           headers: [String: String]? = nil,
                           protocolType: AENetProtocolType = .socket) {
        self.init(method: .GET, path: path, parameters: parameters, headers: headers)
        self.protocolType = protocolType
    }

    /// 便利初始化方法 - POST 请求
    public convenience init(post path: String,
                           parameters: [String: Any]? = nil,
                           headers: [String: String]? = nil,
                           body: Data? = nil,
                           protocolType: AENetProtocolType = .socket) {
        self.init(method: .POST, path: path, parameters: parameters, headers: headers, body: body)
        self.protocolType = protocolType
    }

    // MARK: - Private

    private static var counter: UInt32 = 0

    private static func generateRequestId() -> String {
        counter &+= 1
        let timestamp = UInt32(Date().timeIntervalSince1970)
        let seed = timestamp ^ counter
        let crc = crc32(seed)
        return String(format: "%08x", crc)
    }

    private static func crc32(_ value: UInt32) -> UInt32 {
        var crc = value ^ 0xFFFFFFFF
        for _ in 0..<32 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xEDB88320
            } else {
                crc = crc >> 1
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    /// 从字典创建实例
    /// 数据结构: {"req":{"headers":{"type":"request","requestId":"...","path":"..."}, "body":{...}}, "con":{...}, ...}
    public static func fromMap(_ map: [String: Any]) -> AENetReq? {
        guard let header = map["header"] as? [String: Any],
              let requestId = header["requestId"] as? String,
              let path = header["path"] as? String else {
            AELog("⚠️ [AENetReq] fromMap: 缺少 header.requestId 或 header.path")
            return nil
        }

        let method: AEHttpMethod = .POST

        // 用户 HTTP headers = header 内除 type/requestId/path 外的键
        let transportKeys: Set<String> = ["type", "requestId", "path"]
        var userHeaders: [String: String] = [:]
        for (key, value) in header where !transportKeys.contains(key) {
            if let strValue = value as? String {
                userHeaders[key] = strValue
            }
        }

        // parameters: 除 header 外的字段扁平合并（con、body 由外部添加）
        var parameters: [String: Any] = [:]
        for (key, value) in map where key != "header" {
            parameters[key] = value
        }

        let instance = AENetReq(method: method, path: path, parameters: parameters.isEmpty ? nil : parameters, headers: userHeaders.isEmpty ? nil : userHeaders)
        instance.requestId = requestId
        return instance
    }

    /// 将请求编码为字典
    public func toMap() -> [String: Any] {
        var dataMap: [String: Any] = [:]

        // header: type + requestId + path（+ 用户 HTTP headers 合并）
        var header: [String: Any] = [:]
        header["type"] = AENetMessageType.request.rawValue
        header["requestId"] = requestId
        header["path"] = path
        if let userHeaders = self.headers {
            for (key, value) in userHeaders {
                header[key] = value
            }
        }
        dataMap["header"] = header

        // parameters 扁平合并（cont、user、ques … 由外部添加）
        if let parameters = parameters {
            for (key, value) in parameters {
                dataMap[key] = value
            }
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: dataMap, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            AELog("[AENetReq] \(path):\n\(jsonString)")
        }

        return dataMap
    }

    /// 将请求编码为 JSON Data
    public func encode() throws -> Data {
        let dataMap = toMap()

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataMap, options: []) else {
            throw NSError(domain: "AENetReq", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON 编码失败"])
        }

        return jsonData
    }
}
