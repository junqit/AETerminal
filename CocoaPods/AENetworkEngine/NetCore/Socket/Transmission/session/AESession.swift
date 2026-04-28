import Foundation

/// 网络会话 - 统一管理连接生命周期
public class AESession {
    // MARK: - Properties
    private let io: AEIOProtocol
    private let dataStream: AEDataStream
    private let security: AENetSecurity
    private let systemInfo: AESystemInfoManager

    private var receiveCallbacks: [String: (Data) -> Void] = [:]
    private let callbackLock = NSLock()

    public var sessionId: String
    public var isActive: Bool = false

    // MARK: - Initialization
    public init(io: AEIOProtocol) {
        self.io = io
        self.security = AENetSecurity()
        self.dataStream = AEDataStream(io: io, security: security)
        self.systemInfo = AESystemInfoManager()
        self.sessionId = UUID().uuidString

        setupReceiveHandler()
    }

    // MARK: - Session Lifecycle
    /// 启动会话（执行连接后的握手流程）
    public func start(completion: @escaping (Bool, Error?) -> Void) {
        guard io.isConnected else {
            completion(false, NSError(domain: "AESession", code: -1, userInfo: [NSLocalizedDescriptionKey: "IO 未连接"]))
            return
        }

        isActive = true

        // 1. 发送加密协商
        negotiateSecurity { [weak self] success in
            guard success, let self = self else {
                completion(false, NSError(domain: "AESession", code: -2, userInfo: [NSLocalizedDescriptionKey: "加密协商失败"]))
                return
            }

            // 2. 交换系统信息
            self.exchangeSystemInfo { success in
                if success {
                    print("[AESession] ✓ 会话启动成功: \(self.sessionId)")
                    completion(true, nil)
                } else {
                    completion(false, NSError(domain: "AESession", code: -3, userInfo: [NSLocalizedDescriptionKey: "系统信息交换失败"]))
                }
            }
        }
    }

    /// 关闭会话
    public func close() {
        isActive = false
        clearAllReceiveCallbacks()
        print("[AESession] ✓ 会话已关闭: \(sessionId)")
    }

    // MARK: - Security Negotiation
    private func negotiateSecurity(completion: @escaping (Bool) -> Void) {
        let request = security.generateNegotiationRequest()

        io.send(data: request) { [weak self] success, error in
            if success {
                print("[AESession] ✓ 加密协商请求已发送")
                // 实际应该等待响应，这里简化处理
                self?.security.completeKeyExchange(peerPublicKey: Data())
                completion(true)
            } else {
                print("[AESession] ✗ 加密协商失败: \(error?.localizedDescription ?? "unknown")")
                completion(false)
            }
        }
    }

    // MARK: - System Info Exchange
    private func exchangeSystemInfo(completion: @escaping (Bool) -> Void) {
        systemInfo.sendSystemInfo(via: io) { success in
            completion(success)
        }
    }

    // MARK: - Data Transmission
    /// 发送数据（自动加密和分包）
    public func send(data: Data, completion: ((Bool, Error?) -> Void)? = nil) {
        guard isActive else {
            completion?(false, NSError(domain: "AESession", code: -4, userInfo: [NSLocalizedDescriptionKey: "会话未激活"]))
            return
        }

        dataStream.send(data: data, completion: completion)
    }

    /// 发送 JSON 数据
    public func send(json: [String: Any], completion: ((Bool, Error?) -> Void)? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            completion?(false, NSError(domain: "AESession", code: -5, userInfo: [NSLocalizedDescriptionKey: "JSON 序列化失败"]))
            return
        }
        send(data: data, completion: completion)
    }

    // MARK: - Receive Callbacks
    private func setupReceiveHandler() {
        io.registerReceiveHandler(identifier: sessionId) { [weak self] data in
            self?.handleReceivedData(data)
        }
    }

    private func handleReceivedData(_ data: Data) {
        // 通过 dataStream 处理分包和解密
        if let completeData = dataStream.handleReceivedPacket(data) {
            // 触发所有注册的回调
            callbackLock.lock()
            let callbacks = receiveCallbacks
            callbackLock.unlock()

            callbacks.values.forEach { $0(completeData) }
        }
    }

    /// 注册接收回调
    public func registerReceiveCallback(identifier: String, callback: @escaping (Data) -> Void) {
        callbackLock.lock()
        receiveCallbacks[identifier] = callback
        callbackLock.unlock()
    }

    /// 移除接收回调
    public func removeReceiveCallback(identifier: String) {
        callbackLock.lock()
        receiveCallbacks.removeValue(forKey: identifier)
        callbackLock.unlock()
    }

    /// 清除所有接收回调
    public func clearAllReceiveCallbacks() {
        callbackLock.lock()
        receiveCallbacks.removeAll()
        callbackLock.unlock()
    }

    // MARK: - Utilities
    /// 获取本地系统信息
    public func getLocalSystemInfo() -> AESystemInfo {
        return systemInfo.getLocalInfo()
    }

    /// 获取对端系统信息
    public func getRemoteSystemInfo() -> AESystemInfo? {
        return systemInfo.getRemoteInfo()
    }
}
