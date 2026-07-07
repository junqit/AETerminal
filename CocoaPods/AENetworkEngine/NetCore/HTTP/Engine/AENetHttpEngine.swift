//
//  AENetHttpEngine.swift
//  AENetworkEngine
//
//  Created by 田峻岐 on 2026/4/1.
//

import Foundation

/// HTTP 请求引擎
public class AENetHttpEngine: AENetCoreProtocol {

    // MARK: - AENetCoreProtocol

    /// 网络核心代理
    public weak var delegate: AENetCoreDelegate?

    /// 网络核心类型
    public var coreType: AENetworkType {
        return .http
    }

    // MARK: - Properties

    /// 引擎配置
    private var config: AENetConfig

    /// 默认超时时间
    private var timeout: TimeInterval

    /// 默认请求头
    private var defaultHeaders: [String: String]

    /// URLSession
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        return URLSession(configuration: configuration)
    }()

    // MARK: - Initialization

    /// 初始化引擎
    /// - Parameters:
    ///   - config: 配置信息
    ///   - timeout: 超时时间（默认30秒）
    ///   - defaultHeaders: 默认请求头
    public init(config: AENetConfig,
                timeout: TimeInterval = 30,
                defaultHeaders: [String: String] = [:]) {
        self.config = config
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
    }

    // MARK: - AENetCoreProtocol Methods

    /// 发送 HTTP 请求
    /// - Parameter request: 请求对象
    public func send(request: AENetReq) {
        // 构建完整 URL
        let baseURL = config.host.isEmpty ? "http://\(config.ip):\(config.port)" : "http://\(config.host):\(config.port)"
        let urlString = baseURL + request.path
        guard var urlComponents = URLComponents(string: urlString) else {
            let rsp = AENetRsp(
                requestId: request.requestId,
                protocolType: request.protocolType,
                code: .badRequest
            )
            request.onCompleted?(rsp)
            return
        }

        // 添加 URL 参数（GET 请求）
        if request.method == .GET, let parameters = request.parameters {
            urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }

        guard let url = urlComponents.url else {
            let rsp = AENetRsp(
                requestId: request.requestId,
                protocolType: request.protocolType,
                code: .badRequest
            )
            request.onCompleted?(rsp)
            return
        }

        // 创建 URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = request.timeout

        // 设置默认请求头
        defaultHeaders.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        // 设置请求特定的请求头
        request.headers?.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }

        // 设置请求体（POST、PUT 等）
        if let body = request.body {
            urlRequest.httpBody = body
        } else if request.method != .GET, let parameters = request.parameters {
            if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
                urlRequest.httpBody = jsonData
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // 发送请求
        let task = session.dataTask(with: urlRequest) { data, response, error in
            let httpResponse = response as? HTTPURLResponse
            let rsp = AENetRsp(
                requestId: request.requestId,
                protocolType: request.protocolType,
                code: AENetRspCode(rawValue: httpResponse?.statusCode ?? -1) ?? .unknown,
                headers: httpResponse?.allHeaderFields,
                data: data
            )
            request.onCompleted?(rsp)
        }
        task.resume()
    }

    // MARK: - Async/Await Support

    /// 发送 HTTP 请求（async/await）
    /// - Parameter request: 请求对象
    /// - Returns: 响应对象
    @available(iOS 13.0, macOS 10.15, *)
    public func send(request: AENetReq) async -> AENetRsp {
        await withCheckedContinuation { continuation in
            send(request: request)
        }
    }
}
