//
//  AENetworkSocket.swift
//  AENetworkEngine
//
//  Created by Claude on 2026/4/23.
//

import Foundation
import Network

/// Socket 协议类型
public enum AESocketProtocol {
    case tcp
    case udp
}

/// Socket 连接状态
public enum AESocketState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}

/// Socket 错误类型
public enum AESocketError: Error {
    case invalidAddress
    case connectionFailed
    case sendFailed
    case notConnected
    case encodingFailed
}

/// 网络 Socket 类，支持 TCP/UDP 连接
public class AENetworkSocket {

    // MARK: - Properties

    /// IP 地址
    public let ip: String

    /// 端口号
    public let port: UInt16

    /// 请求路径
    public let path: String

    /// 协议类型
    public let protocolType: AESocketProtocol

    /// 连接状态
    public private(set) var state: AESocketState = .disconnected

    /// NWConnection 连接对象
    private var connection: NWConnection?

    /// 消息队列
    private let queue = DispatchQueue(label: "com.aenetwork.socket", qos: .userInitiated)

    /// 状态变化回调
    public var onStateChanged: ((AESocketState) -> Void)?

    /// 接收数据回调
    public var onDataReceived: ((Data) -> Void)?

    // MARK: - Initialization

    /// 初始化 Socket
    /// - Parameters:
    ///   - ip: IP 地址
    ///   - port: 端口号
    ///   - path: 请求路径
    ///   - protocolType: 协议类型（TCP/UDP）
    public init(ip: String, port: UInt16, path: String, protocolType: AESocketProtocol = .tcp) {
        self.ip = ip
        self.port = port
        self.path = path
        self.protocolType = protocolType
    }

    // MARK: - Connection Management

    /// 连接 Socket
    public func connect() throws {
        switch state {
        case .disconnected, .failed:
            break
        default:
            return
        }

        let host = NWEndpoint.Host(ip)

        let port = NWEndpoint.Port(rawValue: self.port)!

        let parameters: NWParameters
        switch protocolType {
        case .tcp:
            parameters = .tcp
        case .udp:
            parameters = .udp
        }

        connection = NWConnection(host: host, port: port, using: parameters)

        updateState(.connecting)

        connection?.stateUpdateHandler = { [weak self] newState in
            self?.handleStateChange(newState)
        }

        connection?.start(queue: queue)

        // 开始接收数据
        receiveData()
    }

    /// 断开连接
    public func disconnect() {
        connection?.cancel()
        connection = nil
        updateState(.disconnected)
    }

    // MARK: - Send Data

    /// 发送 AENetReq 消息
    /// - Parameter request: HTTP 请求对象
    /// - Throws: 发送失败时抛出错误
    public func send(_ request: AENetReq) throws {
        switch state {
        case .connected:
            break
        default:
            throw AESocketError.notConnected
        }

        let data = try encodeRequest(request)
        try send(data)
    }

    /// 发送原始数据（封装为数据包）
    /// - Parameter data: 要发送的数据
    /// - Throws: 发送失败时抛出错误
    public func send(_ data: Data) throws {
        switch state {
        case .connected:
            break
        default:
            throw AESocketError.notConnected
        }

        // 使用 AEPacket 封装数据
        let packet = AEPacket.create(dataType: .request, data: data)
        let packetData = packet.toBytes()

        connection?.send(content: packetData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("发送数据失败: \(error)")
                self?.updateState(.failed(AESocketError.sendFailed))
            }
        })
    }

    // MARK: - Private Methods

    private func handleStateChange(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            updateState(.connected)

        case .waiting(let error):
            updateState(.failed(error))

        case .failed(let error):
            updateState(.failed(error))

        case .cancelled:
            updateState(.disconnected)

        default:
            break
        }
    }

    private func updateState(_ newState: AESocketState) {
        state = newState
        onStateChanged?(newState)
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.onDataReceived?(data)
            }

            if let error = error {
                print("接收数据错误: \(error)")
                self?.updateState(.failed(error))
                return
            }

            if isComplete {
                self?.updateState(.disconnected)
            } else {
                // 继续接收
                self?.receiveData()
            }
        }
    }

    /// 将 AENetReq 编码为数据（组装成 Map 格式，与 HTTP 层保持一致）
    private func encodeRequest(_ request: AENetReq) throws -> Data {
        var dataMap: [String: Any] = [:]

        // 添加请求方法
        dataMap["method"] = request.method.rawValue

        // 添加路径
        dataMap["path"] = request.path

        // 添加请求头
        if let headers = request.headers {
            dataMap["headers"] = headers
        }

        // 处理参数和 body（与 HTTP 层逻辑一致）
        if let body = request.body {
            // 如果有明确的 body，使用 base64 编码
            dataMap["body"] = body.base64EncodedString()
        } else if request.method != .GET, let parameters = request.parameters {
            // POST 等请求：将 parameters 序列化为 JSON 放到 body
            if let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: []) {
                dataMap["body"] = jsonData.base64EncodedString()

                // 添加 Content-Type header
                var headers = request.headers ?? [:]
                headers["Content-Type"] = "application/json"
                dataMap["headers"] = headers
            }
        } else if request.method == .GET, let parameters = request.parameters {
            // GET 请求：将 parameters 作为单独字段（服务端需要拼接到 URL）
            dataMap["parameters"] = parameters
        }

        // 添加超时时间
        dataMap["timeout"] = request.timeout

        // 将 map 序列化为 JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataMap, options: []) else {
            throw AESocketError.encodingFailed
        }

        return jsonData
    }

    // MARK: - Deinit

    deinit {
        disconnect()
    }
}

// MARK: - Extension for convenient usage

extension AENetworkSocket {

    /// 便利方法：连接并发送请求
    /// - Parameter request: HTTP 请求对象
    /// - Throws: 连接或发送失败时抛出错误
    public func connectAndSend(_ request: AENetReq) throws {
        try connect()

        // 等待连接成功
        let semaphore = DispatchSemaphore(value: 0)
        var connectError: Error?

        onStateChanged = { state in
            if case .connected = state {
                semaphore.signal()
            } else if case .failed(let error) = state {
                connectError = error
                semaphore.signal()
            }
        }

        // 超时等待
        let timeout = DispatchTime.now() + .seconds(Int(request.timeout))
        if semaphore.wait(timeout: timeout) == .timedOut {
            throw AESocketError.connectionFailed
        }

        if let error = connectError {
            throw error
        }

        // 发送请求
        try send(request)
    }
}
