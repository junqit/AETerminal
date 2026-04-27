//
//  AEAINetworkModule.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AEModuleCenter
import AENetworkEngine

/// AEAI 网络模块 - 负责初始化和管理 UDP 网络连接
public class AEAINetworkModule: NSObject, AEModuleProtocol, AEAINetworkProtocol {

    // MARK: - Properties

    /// Socket 管理器实例
    private var socketManager: AENetworkSocket?

    /// 监听者管理器
    private let listenerManager: AENetworkListenerManager

    /// Socket 网络配置
    private var socketConfig: AEAISocketConfig?

    /// HTTP 网络配置
    private var httpConfig: AENetConfig?

    /// 是否已初始化
    private var isInitialized: Bool = false

    /// 初始化锁
    private let initLock = NSLock()

    /// 消息发送队列
    private let sendQueue = DispatchQueue(label: "com.aeai.network.send", qos: .userInitiated)

    // MARK: - Initialization

    public override init() {
        self.listenerManager = AENetworkListenerManager()
        super.init()
    }

    // MARK: - Configuration

    /// 配置网络参数
    /// - Parameter config: 网络配置
    public func configure(with config: AENetworkConfig) {
        switch config.type {
        case .http:
            // 配置 HTTP 引擎
            let httpNetConfig = AENetConfig(host: config.host, port: config.port)
            AENetHttpEngine.configure(config: httpNetConfig)
            self.httpConfig = httpNetConfig
            print("✅ HTTP 网络配置成功: \(config.host):\(config.port)")

        case .socket:
            // 配置 Socket
            let socketNetConfig = AEAISocketConfig(
                serverIP: config.host,
                serverPort: config.port,
                protocolType: .udp
            )
            self.socketConfig = socketNetConfig
            print("✅ Socket 网络配置成功: \(config.host):\(config.port)")
        }
    }

    /// 配置网络参数（旧方法，保持兼容）
    /// - Parameter config: Socket 配置
    /// - Returns: 自身实例，支持链式调用
    @discardableResult
    @available(*, deprecated, message: "使用 configure(with: AENetworkConfig) 替代")
    public func configure(with config: AEAISocketConfig) -> Self {
        self.socketConfig = config
        return self
    }

    /// 配置网络参数（便捷方法，旧方法，保持兼容）
    /// - Parameters:
    ///   - serverIP: 服务器 IP 地址
    ///   - serverPort: 服务器端口
    ///   - protocolType: 协议类型（默认 UDP）
    /// - Returns: 自身实例，支持链式调用
    @discardableResult
    @available(*, deprecated, message: "使用 configure(with: AENetworkConfig) 替代")
    public func configure(
        serverIP: String,
        serverPort: UInt16,
        protocolType: AESocketProtocol = .udp
    ) -> Self {
        let config = AEAISocketConfig(
            serverIP: serverIP,
            serverPort: serverPort,
            protocolType: protocolType
        )
        return configure(with: config)
    }

    // MARK: - AEModuleProtocol - macOS

#if os(macOS)
    /// Application 启动完成 (macOS)
    public func applicationDidFinishLaunching(_ notification: Notification) {
        initializeNetwork()
    }

    /// Application 将要终止 (macOS)
    public func applicationWillTerminate(_ notification: Notification) {
        shutdownNetwork()
    }
#endif

    // MARK: - AEModuleProtocol - iOS

#if os(iOS)
    /// Application 启动完成 (iOS)
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        initializeNetwork()
        return true
    }

    /// Application 将要终止 (iOS)
    public func applicationWillTerminate(_ application: UIApplication) {
        shutdownNetwork()
    }

    /// Application 进入后台 (iOS)
    public func applicationDidEnterBackground(_ application: UIApplication) {
        // 可选：在进入后台时保持连接或断开连接
        // 根据具体需求决定是否断开连接
    }

    /// Application 进入前台 (iOS)
    public func applicationWillEnterForeground(_ application: UIApplication) {
        // 可选：重新连接（如果之前断开了）
        reconnectIfNeeded()
    }
#endif

    // MARK: - Network Management

    /// 初始化网络
    private func initializeNetwork() {
        initLock.lock()
        defer { initLock.unlock() }

        guard !isInitialized else {
            log("⚠️ 网络已经初始化，跳过重复初始化")
            return
        }

        guard let config = socketConfig else {
            log("⚠️ 未配置 Socket 参数，跳过 Socket 初始化")
            return
        }

        log("🚀 开始初始化 AEAI Socket 网络...")

        // 创建 Socket
        socketManager = AENetworkSocket(
            ip: config.serverIP,
            port: config.serverPort,
            path: config.path,
            protocolType: config.protocolType
        )

        // 设置状态监听
        socketManager?.onStateChanged = { [weak self] state in
            self?.handleStateChange(state)
        }

        // 设置数据接收监听
        socketManager?.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }

        // 连接到服务器
        do {
            try socketManager?.connect()
        } catch {
            log("❌ AEAI Socket 连接失败: \(error.localizedDescription)")
        }
    }

    /// 关闭网络
    private func shutdownNetwork() {
        initLock.lock()
        defer { initLock.unlock() }

        guard isInitialized else { return }

        log("🛑 关闭 AEAI 网络连接...")
        socketManager?.disconnect()
        socketManager = nil
        isInitialized = false
        log("✅ AEAI 网络已关闭")
    }

    /// 重新连接（如果需要）
    private func reconnectIfNeeded() {
        initLock.lock()
        let needsReconnect = isInitialized && !isConnected
        initLock.unlock()

        if needsReconnect {
            log("🔄 重新连接 AEAI 网络...")
            do {
                try socketManager?.connect()
            } catch {
                log("❌ AEAI 网络重连失败: \(error.localizedDescription)")
            }
        }
    }

    /// 处理连接状态变化
    private func handleStateChange(_ state: AESocketState) {
        switch state {
        case .disconnected:
            log("📡 Socket 已断开")
            isInitialized = false
        case .connecting:
            log("📡 Socket 连接中...")
        case .connected:
            log("✅ AEAI 网络初始化成功")
            isInitialized = true
        case .failed(let error):
            log("❌ Socket 连接失败: \(error.localizedDescription)")
            isInitialized = false
        }
    }

    /// 处理接收到的数据
    private func handleReceivedData(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let requestId = json["requestId"] as? String else {
            log("⚠️ 无法解析接收到的数据或缺少 requestId")
            return
        }

        log("📨 收到消息: \(json["type"] ?? "unknown")")

        let response = AENetRsp(
            requestId: requestId,
            protocolType: .socket,
            statusCode: 200,
            data: data,
            error: nil
        )
        listenerManager.notifyListeners(response: response)
    }

    // MARK: - Public Methods

    /// 手动连接网络（用于需要延迟连接的场景）
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        guard let config = socketConfig else {
            let error = NSError(
                domain: "AEAINetworkModule",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未配置 Socket 参数"]
            )
            completion?(false, error)
            return
        }

        if socketManager == nil {
            socketManager = AENetworkSocket(
                ip: config.serverIP,
                port: config.serverPort,
                path: config.path,
                protocolType: config.protocolType
            )

            socketManager?.onStateChanged = { [weak self] state in
                self?.handleStateChange(state)

                // 通知完成回调
                switch state {
                case .connected:
                    completion?(true, nil)
                case .failed(let error):
                    completion?(false, error)
                default:
                    break
                }
            }

            socketManager?.onDataReceived = { [weak self] data in
                self?.handleReceivedData(data)
            }
        }

        do {
            try socketManager?.connect()
        } catch {
            completion?(false, error)
        }
    }

    /// 手动断开网络
    public func disconnect() {
        socketManager?.disconnect()
        socketManager = nil
        isInitialized = false
    }

    /// 获取网络连接状态
    public var isConnected: Bool {
        guard let socketManager = socketManager else { return false }
        switch socketManager.state {
        case .connected:
            return true
        default:
            return false
        }
    }

    // MARK: - Send Methods

    /// 发送请求并返回响应
    public func sendRequest(_ request: AENetReq, completion: ((AENetRsp) -> Void)?) {
        switch request.protocolType {
        case .socket:
            sendQueue.async { [weak self] in
                guard let self = self else {
                    let response = AENetRsp(requestId: request.requestId, protocolType: request.protocolType, error: NSError(domain: "AEAINetworkModule", code: -1, userInfo: [NSLocalizedDescriptionKey: "Module released"]))
                    completion?(response)
                    return
                }

                guard let socketManager = self.socketManager else {
                    let response = AENetRsp(requestId: request.requestId, protocolType: request.protocolType, error: NSError(domain: "AEAINetworkModule", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络未初始化"]))
                    completion?(response)
                    return
                }

                guard self.isConnected else {
                    let response = AENetRsp(requestId: request.requestId, protocolType: request.protocolType, error: NSError(domain: "AEAINetworkModule", code: -2, userInfo: [NSLocalizedDescriptionKey: "网络未连接"]))
                    completion?(response)
                    return
                }

                do {
                    try socketManager.send(request)
                } catch {
                    let response = AENetRsp(requestId: request.requestId, protocolType: request.protocolType, error: error)
                    DispatchQueue.main.async {
                        completion?(response)
                    }
                }
            }

        case .http:
            AENetHttpEngine.send(request: request) { [weak self] rsp in
                
                if let ss = self {
                    ss.listenerManager.notifyListeners(response: rsp)
                }
                
            }
        }
    }

    // MARK: - Listener Management

    /// 注册消息监听者
    /// - Parameter listener: 监听者实例
    public func addListener(_ listener: AENetworkMessageListener) {
        listenerManager.addListener(listener)
    }

    /// 移除消息监听者
    /// - Parameter listener: 监听者实例
    public func removeListener(_ listener: AENetworkMessageListener) {
        listenerManager.removeListener(listener)
    }

    /// 移除所有监听者
    public func removeAllListeners() {
        listenerManager.removeAllListeners()
    }

    /// 获取监听者数量
    public var listenerCount: Int {
        return listenerManager.count
    }

    // MARK: - Utilities

    /// 日志输出
    private func log(_ message: String) {
        print("[AEAINetworkModule] \(message)")
    }
}
