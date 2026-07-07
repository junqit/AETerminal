//
//  AENetSocketEngineEngine.swift
//  AENetworkEngine
//
//  Created by Claude on 2026/4/23.
//

import Foundation
import Network
import AEFoundation
import AELogProxy

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
public class AENetSocketEngine {

    // MARK: - Properties

    /// IP 地址
    public let ip: String

    /// 端口号
    public let port: UInt16

    /// 协议类型
    public let protocolType: AENetSocketType

    /// 连接状态（原子包装）
    private let _state = AEAtom<AESocketState>(.disconnected)

    public var state: AESocketState {
        var current: AESocketState = .disconnected
        _state.read { current = $0 }
        return current
    }

    /// NWConnection 连接对象
    private var connection: NWConnection?

    /// 网络IO队列
    private let queue = DispatchQueue(label: "com.aenetwork.socket.io", qos: .userInitiated)

    /// 数据解析队列
    private let parseQueue = DispatchQueue(label: "com.aenetwork.socket.parse", qos: .userInitiated)

    /// 状态变化回调
    public var onStateChanged: ((AESocketState) -> Void)?

    /// 接收响应回调（解析后的 AENetRsp）
    public var onResponseReceived: ((AENetRsp) -> Void)?

    /// 待处理的请求 [requestId: AENetReq]
    private var pendingRequests: [String: AENetReq] = [:]
    private let pendingLock = NSLock()

    /// 数据包解析器
    private let packetParser = AEPacketParser()

    // MARK: - Initialization

    /// 初始化 Socket
    /// - Parameters:
    ///   - ip: IP 地址
    ///   - port: 端口号
    ///   - protocolType: 协议类型（TCP/UDP）
    public init(ip: String, port: UInt16, protocolType: AENetSocketType = .tcp) {
        
        self.ip = ip
        self.port = port
        self.protocolType = protocolType

        // 配置解析器代理
        packetParser.delegate = self

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
            AELog("⚠️ [Socket] 连接已存在，跳过重复连接")
            return
        }

        AELog("🔌 [Socket] 开始连接: \(ip):\(port) (\(protocolType == .tcp ? "TCP" : "UDP"))")

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
        AELog("🔌 [Socket] 断开连接: \(ip):\(port)")
        connection?.cancel()
        connection = nil

        // 清空缓冲区
        packetParser.reset()

        // 清空待处理请求
        pendingLock.lock()
        pendingRequests.removeAll()
        pendingLock.unlock()

        updateState(.disconnected)
    }

    // MARK: - Send Data

    /// 发送 AENetReq 消息
    /// - Parameter request: 请求对象，响应通过 request.onStreamReceived / request.onCompleted 回调
    /// - Throws: 未连接时抛出错误
    public func send(_ request: AENetReq) throws {
        guard case .connected = state else {
            throw AESocketError.notConnected
        }

        pendingLock.lock()
        pendingRequests[request.requestId] = request
        pendingLock.unlock()

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
                AELog("❌ [Socket] 发送数据失败: \(error)")
                self?.updateState(.failed(AESocketError.sendFailed))
            }
        })
    }

    // MARK: - Private Methods

    private func handleResponse(_ response: AENetRsp) {

        pendingLock.lock()
        let request = pendingRequests[response.requestId]
        if response.isCompleted {
            pendingRequests.removeValue(forKey: response.requestId)
        }
        pendingLock.unlock()

        if let request = request {
            if response.isCompleted, let callback = request.onCompleted {
                callback(response)
                return
            }
            if !response.isCompleted, let callback = request.onStreamReceived {
                callback(response)
                return
            }
        }

        onResponseReceived?(response)
    }

    private func handleStateChange(_ newState: NWConnection.State) {
        switch newState {
        case .ready:
            AELog("✅ [Socket] 连接成功: \(ip):\(port)")
            updateState(.connected)

        case .waiting(let error):
            AELog("⏳ [Socket] 连接等待: \(error)")
            updateState(.failed(error))

        case .failed(let error):
            AELog("❌ [Socket] 连接失败: \(error)")
            updateState(.failed(error))

        case .cancelled:
            AELog("🔌 [Socket] 连接已取消")
            updateState(.disconnected)

        case .setup:
            AELog("🔧 [Socket] 连接设置中...")

        case .preparing:
            AELog("⚙️ [Socket] 连接准备中...")

        @unknown default:
            AELog("⚠️ [Socket] 未知状态: \(newState)")
        }
    }

    private func updateState(_ newState: AESocketState) {
        _state.write { $0 = newState }
        onStateChanged?(newState)
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {

                // 解析放到独立线程，不阻塞下一次接收
                self.parseQueue.async { [weak self] in
                    self?.packetParser.appendData(data)
                }
            }

            if let error = error {
                AELog("❌ [Socket] 接收数据错误: \(error)")
                self.updateState(.failed(error))
                return
            }

            if isComplete {
                if self.protocolType == .udp {
                    // UDP: isComplete 表示当前数据报完整，继续接收下一个
                    // 异步调度避免递归栈溢出
                    self.queue.async { [weak self] in
                        self?.receiveData()
                    }
                } else {
                    // TCP: isComplete 且无后续数据表示对端关闭
                    if data == nil || data!.isEmpty {
                        AELog("🔌 [Socket] TCP 连接关闭")
                        self.updateState(.disconnected)
                    } else {
                        self.queue.async { [weak self] in
                            self?.receiveData()
                        }
                    }
                }
            } else {
                // 未完成，异步调度继续接收，避免递归栈溢出
                self.queue.async { [weak self] in
                    self?.receiveData()
                }
            }
        }
    }

    private func encodeRequest(_ request: AENetReq) throws -> Data {
        do {
            return try request.encode()
        } catch {
            throw AESocketError.encodingFailed
        }
    }

    // MARK: - Deinit

    deinit {
        disconnect()
    }
}

// MARK: - AEPacketParserDelegate

extension AENetSocketEngine: AEPacketParserDelegate {

    public func parser(_ parser: AEPacketParser, didReceiveRequest request: AENetReq) {
        AELog("📥 [Socket] 收到请求类型数据包: requestId=\(request.requestId)")
    }

    public func parser(_ parser: AEPacketParser, didReceiveResponse response: AENetRsp) {
        handleResponse(response)
    }


}

