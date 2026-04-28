//
//  AENetReq.swift
//  AENetworkEngine
//
//  Created by 田峻岐 on 2026/4/1.
//

import Foundation

/// 网络请求协议类型
public enum AENetProtocolType {
    case socket   // Socket/UDP 请求
    case http     // HTTP 请求
}

/// HTTP 请求方式枚举
public enum AEHttpMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
    case HEAD = "HEAD"
    case OPTIONS = "OPTIONS"
}

/// HTTP 请求对象
public class AENetReq {

    /// 请求唯一标识
    public let requestId: String

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
    public var timeout: TimeInterval = 30

    /// 初始化方法
    /// - Parameters:
    ///   - method: 请求方式
    ///   - path: 请求路径
    ///   - parameters: 请求参数
    ///   - headers: 请求头
    ///   - body: 请求体
    ///   - requestId: 请求唯一标识（默认自动生成）
    public init(method: AEHttpMethod,
                path: String,
                parameters: [String: Any]? = nil,
                headers: [String: String]? = nil,
                body: Data? = nil,
                requestId: String? = nil) {
        self.requestId = requestId ?? UUID().uuidString
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
                           protocolType: AENetProtocolType = .socket,
                           requestId: String? = nil) {
        self.init(method: .GET, path: path, parameters: parameters, headers: headers, requestId: requestId)
        self.protocolType = protocolType
    }

    /// 便利初始化方法 - POST 请求
    public convenience init(post path: String,
                           parameters: [String: Any]? = nil,
                           headers: [String: String]? = nil,
                           body: Data? = nil,
                           protocolType: AENetProtocolType = .socket,
                           requestId: String? = nil) {
        self.init(method: .POST, path: path, parameters: parameters, headers: headers, body: body, requestId: requestId)
        self.protocolType = protocolType
    }
}
