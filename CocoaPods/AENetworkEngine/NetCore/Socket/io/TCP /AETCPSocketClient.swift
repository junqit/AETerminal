import Foundation
import Network

/// TCP Socket 客户端
public class AETCPSocketClient {
    // MARK: - Properties
    private var connection: NWConnection?
    private var config: AETCPSocketConfig
    private let receiveQueue = DispatchQueue(label: "com.aenetwork.tcp.receive")
    private let sendQueue = DispatchQueue(label: "com.aenetwork.tcp.send")

    private var isListening = false
    public private(set) var state: AETCPConnectionState = .disconnected
    public weak var delegate: AETCPConnectionDelegate?

    // MARK: - Initialization
    public init(config: AETCPSocketConfig) {
        self.config = config
    }

    // MARK: - Connection Management
    /// 连接到服务器
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        guard state == .disconnected else {
            completion?(false, NSError(domain: "AETCPSocketClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "已存在连接"]))
            return
        }

        updateState(.connecting)

        let host = NWEndpoint.Host(config.serverHost)
        let port = NWEndpoint.Port(rawValue: config.serverPort)!

        connection = NWConnection(host: host, port: port, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                self.log("✓ TCP 已连接到服务器: \(self.config.serverHost):\(self.config.serverPort)")
                self.updateState(.connected)
                self.delegate?.tcpConnectionDidConnect(self)
                self.startContinuousListening()
                self.confirmMTU()
                completion?(true, nil)

            case .failed(let error):
                self.log("✗ TCP 连接失败: \(error.localizedDescription)")
                self.updateState(.failed)
                self.delegate?.tcpConnection(self, didFailWithError: error)
                completion?(false, error)

            case .waiting(let error):
                self.log("⏳ TCP 等待连接: \(error.localizedDescription)")

            case .cancelled:
                self.log("✗ TCP 连接已取消")
                self.updateState(.disconnected)
                self.delegate?.tcpConnectionDidDisconnect(self)

            default:
                break
            }
        }

        connection?.start(queue: receiveQueue)

        // 超时处理
        receiveQueue.asyncAfter(deadline: .now() + config.timeout) { [weak self] in
            guard let self = self, self.state == .connecting else { return }
            let error = NSError(domain: "AETCPSocketClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "连接超时"])
            completion?(false, error)
            self.disconnect()
        }
    }

    /// 断开连接
    public func disconnect() {
        isListening = false
        connection?.cancel()
        connection = nil
        updateState(.disconnected)
        log("✓ TCP 已断开连接")
    }

    // MARK: - Send Data
    /// 同步发送数据
    public func send(data: Data, completion: ((Bool, Error?) -> Void)? = nil) {
        guard state == .connected else {
            let error = NSError(domain: "AETCPSocketClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "未连接到服务器"])
            completion?(false, error)
            return
        }

        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.log("✗ TCP 发送失败: \(error.localizedDescription)")
                completion?(false, error)
            } else {
                self?.log("✓ TCP 发送成功，大小: \(data.count) 字节")
                completion?(true, nil)
            }
        })
    }

    // MARK: - Receive Data
    /// 开始持续监听
    private func startContinuousListening() {
        guard !isListening else { return }
        isListening = true
        log("✓ 开始 TCP 持续监听")
        listenForNextMessage()
    }

    private func listenForNextMessage() {
        guard isListening, state == .connected else { return }

        connection?.receive(minimumIncompleteLength: 1, maximumLength: config.bufferSize) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.log("✗ TCP 接收错误: \(error.localizedDescription)")
                self.disconnect()
                return
            }

            if let data = data, !data.isEmpty {
                self.log("✓ TCP 收到数据: \(data.count) 字节")
                self.delegate?.tcpConnection(self, didReceive: data)
            }

            if isComplete {
                self.log("✓ TCP 连接关闭")
                self.disconnect()
                return
            }

            // 继续监听
            self.listenForNextMessage()
        }
    }

    // MARK: - MTU Confirmation
    /// 确认最优 MTU
    private func confirmMTU() {
        // TCP MTU 通常由系统自动协商
        // 这里可以实现自定义的 MTU 探测逻辑
        let optimalMTU = config.mtu
        log("✓ TCP MTU 确认: \(optimalMTU)")
        delegate?.tcpConnection(self, didConfirmMTU: optimalMTU)
    }

    // MARK: - State Management
    private func updateState(_ newState: AETCPConnectionState) {
        state = newState
        delegate?.tcpConnection(self, didChangeState: newState)
    }

    // MARK: - Logging
    private func log(_ message: String) {
        guard config.enableLog else { return }
        print("[AETCPSocketClient] \(message)")
    }
}
