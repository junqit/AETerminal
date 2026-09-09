//
//  AEBDCredential.swift
//  AECloudStorage
//
//  Created on 2026/09/05.
//

import Foundation
import AELogProxy

// MARK: - BDToken

/// Baidu 访问令牌（access/refresh/expires_at/scope）
public struct BDToken: Codable {

    var access_token: String?
    var refresh_token: String?
    var expires_at: Int64 = 0   // unix 秒；0 = 未知（依赖网络校验）
    var scope: String?

    var isPresent: Bool { !(access_token?.isEmpty ?? true) }

    /// 是否过期（margin 秒内视为过期；expires_at==0 未知 → false）
    func isExpired(margin: Int64 = AEBDCredential.refreshMargin) -> Bool {
        if expires_at == 0 { return false }
        return expires_at - margin <= Int64(Date().timeIntervalSince1970)
    }

    var isValid: Bool { isPresent && !isExpired() }

    /// 由 OAuth 响应构造（响应未返回 refresh_token 时保留 prev 的）
    static func fromResponse(_ resp: [String: Any], prev: BDToken) -> BDToken {

        var t = BDToken()
        t.access_token = resp["access_token"] as? String
        t.refresh_token = (resp["refresh_token"] as? String) ?? prev.refresh_token
        let expiresIn = (resp["expires_in"] as? Int64) ?? Int64((resp["expires_in"] as? Int) ?? 0)
        t.expires_at = Int64(Date().timeIntervalSince1970) + expiresIn
        t.scope = resp["scope"] as? String
        return t
    }
}

// MARK: - DeviceCodeInfo

/// 设备码授权信息（首次授权用，UI 展示二维码/验证码）
public struct AEDeviceCodeInfo {

    public let deviceCode: String
    public let userCode: String
    public let verificationUrl: String
    public let qrcodeUrl: String
    public let interval: Int
    public let expiresIn: Int
}

// MARK: - Delegate

/// 凭据回调（storage 实现，鉴权/刷新完成时触发）
protocol AEBDCredentialDelegate: AnyObject {

    func credentialOnValid(_ cred: AEBDCredential)
    func credentialOnRefreshed(_ cred: AEBDCredential)
}

// MARK: - AEBDCredential

/// Baidu OAuth 凭据（device-code 首次授权 + refresh + token 缓存）
public final class AEBDCredential {

    // MARK: - Constants

    static let openapiHost = "https://openapi.baidu.com"
    static let urlDeviceCode = openapiHost + "/oauth/2.0/device/code"
    static let urlToken = openapiHost + "/oauth/2.0/token"
    public static let defaultScope = "basic,netdisk"
    static let refreshMargin: Int64 = 60

    // MARK: - Properties

    public let appName: String
    public let appKey: String
    public let appSecret: String
    public let credentialPath: URL

    weak var delegate: AEBDCredentialDelegate?
    private(set) var token = BDToken()

    public var accessToken: String? { token.access_token }
    public var refreshToken: String? { token.refresh_token }
    public var isValid: Bool { token.isValid }
    public var hasRefreshToken: Bool { !(token.refresh_token?.isEmpty ?? true) }

    // MARK: - Init

    public init(appName: String, appKey: String, appSecret: String, credentialPath: URL) {

        self.appName = appName
        self.appKey = appKey
        self.appSecret = appSecret
        self.credentialPath = credentialPath
        self.token = loadFromCache()
    }

    // MARK: - Cache

    private func loadFromCache() -> BDToken {

        guard let data = try? Data(contentsOf: credentialPath),
              let decoded = try? JSONDecoder().decode(BDToken.self, from: data) else {
            return BDToken()
        }
        return decoded
    }

    private func saveToCache(_ t: BDToken) {

        do {
            let data = try JSONEncoder().encode(t)
            try FileManager.default.createDirectory(at: credentialPath.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: credentialPath, options: [.atomic])
        } catch {
            AELog("⚠️ [CloudStorage] token 缓存写入失败")
        }
    }

    // MARK: - HTTP

    /// GET 请求（query），返回 JSON 字典
    private func get(_ url: String, query: [String: String]) async throws -> [String: Any] {

        var components = URLComponents(string: url)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else {
            throw NSError(domain: "AEBDCredential", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "URL 无效"])
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            AELog("⚠️ [CloudStorage] Baidu 凭据接口请求失败")
            throw NSError(domain: "AEBDCredential", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP 错误"])
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            AELog("⚠️ [CloudStorage] Baidu 凭据响应解析失败")
            throw NSError(domain: "AEBDCredential", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "JSON 解析失败"])
        }
        return json
    }

    /// 异步延时（DispatchQueue 实现，兼容 iOS 13）
    private func delay(_ seconds: Int) async {

        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(seconds)) {
                continuation.resume()
            }
        }
    }

    // MARK: - Save + notify

    @discardableResult
    private func save(_ response: [String: Any]) -> BDToken {

        let t = BDToken.fromResponse(response, prev: token)
        token = t
        saveToCache(t)
        return t
    }

    private func notifyValid() {
        AELog("✅ [CloudStorage] Baidu 凭据有效")
        delegate?.credentialOnValid(self)
    }

    private func notifyRefreshed() {
        AELog("🔄 [CloudStorage] Baidu 凭据已刷新")
        delegate?.credentialOnRefreshed(self)
    }

    // MARK: - OAuth

    /// 请求设备码（首次授权；返回供 UI 展示二维码/验证码）
    public func requestDeviceCode(scope: String = AEBDCredential.defaultScope) async throws -> AEDeviceCodeInfo {

        let json = try await get(AEBDCredential.urlDeviceCode, query: [
            "response_type": "device_code",
            "openapi": "xpansdk",
            "client_id": appKey,
            "scope": scope
        ])

        return AEDeviceCodeInfo(
            deviceCode: (json["device_code"] as? String) ?? "",
            userCode: (json["user_code"] as? String) ?? "",
            verificationUrl: (json["verification_url"] as? String) ?? "",
            qrcodeUrl: (json["qrcode_url"] as? String) ?? "",
            interval: (json["interval"] as? Int) ?? 5,
            expiresIn: (json["expires_in"] as? Int) ?? 1800
        )
    }

    /// 轮询设备码换取 token（直到成功/拒绝/超时）
    public func pollDeviceToken(_ info: AEDeviceCodeInfo, timeout: Int = 600) async throws -> BDToken {

        let deadline = min(info.expiresIn, timeout)
        var elapsed = 0

        while elapsed < deadline {

            let json = try await get(AEBDCredential.urlToken, query: [
                "grant_type": "device_token",
                "openapi": "xpansdk",
                "code": info.deviceCode,
                "client_id": appKey,
                "client_secret": appSecret
            ])

            if json["access_token"] as? String != nil {
                save(json)
                notifyValid()
                return token
            }

            let error = (json["error"] as? String) ?? ""
            if error == "expired_token" || error == "access_denied" {
                AELog("⚠️ [CloudStorage] 设备码授权失败")
                throw NSError(domain: "AEBDCredential", code: -4,
                              userInfo: [NSLocalizedDescriptionKey: "设备码授权失败"])
            }

            try await delay(info.interval)
            elapsed += info.interval
        }

        AELog("⚠️ [CloudStorage] 设备码授权超时")
        throw NSError(domain: "AEBDCredential", code: -5,
                      userInfo: [NSLocalizedDescriptionKey: "设备码授权超时"])
    }

    /// 用授权码换 token（authorization_code 流程）
    public func authorizeWithCode(_ code: String, redirectURI: String = "oob") async throws -> BDToken {

        let json = try await get(AEBDCredential.urlToken, query: [
            "grant_type": "authorization_code",
            "openapi": "xpansdk",
            "code": code,
            "client_id": appKey,
            "client_secret": appSecret,
            "redirect_uri": redirectURI
        ])

        save(json)
        notifyValid()
        return token
    }

    /// 用 refresh_token 刷新 token
    public func refresh() async throws -> BDToken {

        guard let rt = token.refresh_token, !rt.isEmpty else {
            AELog("⚠️ [CloudStorage] 无 refresh_token，无法刷新")
            throw NSError(domain: "AEBDCredential", code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "无 refresh_token"])
        }

        let json = try await get(AEBDCredential.urlToken, query: [
            "grant_type": "refresh_token",
            "openapi": "xpansdk",
            "refresh_token": rt,
            "client_id": appKey,
            "client_secret": appSecret
        ])

        save(json)
        notifyRefreshed()
        return token
    }

    /// 获取 access_token（有效→返回；有 refresh→刷新后返回；否则抛错）
    public func getAccessToken() async throws -> String {

        if token.isValid, let at = token.access_token { return at }
        if hasRefreshToken {
            _ = try await refresh()
            if let at = token.access_token { return at }
        }
        AELog("⚠️ [CloudStorage] 无可用 access_token，请先授权")
        throw NSError(domain: "AEBDCredential", code: -7,
                      userInfo: [NSLocalizedDescriptionKey: "无可用 access_token"])
    }

    /// 校验凭据（有效→标记；有 refresh→刷新；否则 false）
    public func verify() async -> Bool {

        if token.isValid {
            notifyValid()
            return true
        }
        if hasRefreshToken {
            _ = try? await refresh()
            return token.isValid
        }
        return false
    }
}
