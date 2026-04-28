//
//  AENetSocket.swift
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
public class AENetSocket {

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

    /// 接收响应回调（解析后的 AENetRsp）
    public var onResponseReceived: ((AENetRsp) -> Void)?

    /// 数据包解析器
    private let packetParser = AEPacketParser()

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

        // 配置数据包解析器回调
        packetParser.onResponseReceived = { [weak self] response in
            guard let self = self else { return }
            print("📦 [Socket] 收到解析后的响应: requestId=\(response.requestId)")
            // 通知上层业务
            self.onResponseReceived?(response)
        }

        packetParser.onParseError = { error in
            print("❌ [Socket] 数据包解析错误: \(error)")
        }

        // 启动解析器
        packetParser.start()
    }

    // MARK: - Connection Management

    /// 连接 Socket
    public func connect() throws {
        switch state {
        case .disconnected, .failed:
            break
        default:
            print("⚠️ [Socket] 连接已存在，跳过重复连接")
            return
        }

        print("🔌 [Socket] 开始连接: \(ip):\(port) (\(protocolType == .tcp ? "TCP" : "UDP"))")

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
        print("🔌 [Socket] 断开连接: \(ip):\(port)")
        connection?.cancel()
        connection = nil

        // 清空缓冲区
        packetParser.getBuffer().clear()

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

        print("📤 [Socket] 发送数据: \(data.count) bytes (封包后: \(packetData.count) bytes)")

        connection?.send(content: packetData, completion: .contentProcessed { [weak self] error in
            if let error = error {
                print("❌ [Socket] 发送数据失败: \(error)")
                self?.updateState(.failed(AESocketError.sendFailed))
            } else {
                print("✅ [Socket] 数据发送成功")
            }
        })
    }

    // MARK: - Private Methods

    private func handleStateChange(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            print("✅ [Socket] 连接成功: \(ip):\(port)")
            updateState(.connected)

        case .waiting(let error):
            print("⏳ [Socket] 连接等待: \(error)")
            updateState(.failed(error))

        case .failed(let error):
            print("❌ [Socket] 连接失败: \(error)")
            updateState(.failed(error))

        case .cancelled:
            print("🔌 [Socket] 连接已取消")
            updateState(.disconnected)

        case .setup:
            print("🔧 [Socket] 连接设置中...")

        case .preparing:
            print("⚙️ [Socket] 连接准备中...")

        @unknown default:
            print("⚠️ [Socket] 未知状态: \(newState)")
        }
    }

    private func updateState(_ newState: AESocketState) {
        state = newState
        onStateChanged?(newState)
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                print("📥 [Socket] 接收数据: \(data.count) bytes")

                // 将数据追加到缓冲区，并通知解析器
                self.packetParser.getBuffer().append(data)
                self.packetParser.notifyDataAvailable()
            }

            if let error = error {
                print("❌ [Socket] 接收数据错误: \(error)")
                self.updateState(.failed(error))
                return
            }

            // UDP 协议：isComplete 表示当前数据报完整，但应继续接收下一个数据报
            // TCP 协议：isComplete 表示连接关闭
            if isComplete && self.protocolType == .tcp {
                print("🔌 [Socket] TCP 连接关闭")
                self.updateState(.disconnected)
            } else {
                // 使用异步调度继续接收，避免递归栈溢出
                self.queue.async { [weak self] in
                    self?.receiveData()
                }
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
        } else if let parameters = request.parameters {
            // POST 等请求：将 parameters 序列化为 JSON 放到 body
            dataMap["body"] = parameters
        }
            
        // 添加超时时间
        dataMap["timeout"] = request.timeout
        
        print("socket reqeuest:\(dataMap)")

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

extension AENetSocket {

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
