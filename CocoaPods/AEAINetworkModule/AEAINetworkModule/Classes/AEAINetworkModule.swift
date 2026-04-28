//
//  AEAINetworkModule.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AEModuleCenter
import AENetworkEngine

/// AEAI 网络模块 - 负责管理网络连接
public class AEAINetworkModule: NSObject, AEModuleProtocol, AEAINetworkProtocol {

    // MARK: - Properties

    /// Socket 管理器实例
    private var socketManager: AEAISocketManager?

    /// 监听者管理器
    private let listenerManager: AENetworkListenerManager

    /// Socket 网络配置
    private var socketConfig: AEAISocketConfig?

    /// HTTP 网络配置
    private var httpConfig: AENetConfig?

    // MARK: - Initialization

    public override init() {
        self.listenerManager = AENetworkListenerManager()
        super.init()
    }

    // MARK: - Configuration

    /// 配置网络参数
    /// - Parameter config: 网络配置
    public func configure(with config: AENetConfig) {
        switch config.type {
        case .http:
            // 配置 HTTP 引擎
            AENetHttpEngine.configure(config: config)
            self.httpConfig = config
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
    @available(*, deprecated, message: "使用 configure(with: AENetConfig) 替代")
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
    @available(*, deprecated, message: "使用 configure(with: AENetConfig) 替代")
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
        // 可选：根据需求决定是否断开连接
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
        guard let config = socketConfig else {
            print("⚠️ 未配置 Socket 参数，跳过 Socket 初始化")
            return
        }

        print("🚀 开始初始化 AEAI Socket 网络...")

        // 创建 Socket Manager
        let manager = AEAISocketManager(
            serverIP: config.serverIP,
            serverPort: config.serverPort,
            path: config.path
        )

        // 设置状态监听
        manager.onConnectionStateChanged = { [weak self] state in
            self?.handleStateChange(state)
        }

        // 设置响应接收监听
        manager.onResponseReceived = { [weak self] response in
            self?.handleReceivedResponse(response)
        }

        self.socketManager = manager

        // 连接到服务器
        manager.connect { success, error in
            if success {
                print("✅ AEAI 网络初始化成功")
            } else {
                print("❌ AEAI Socket 连接失败: \(error?.localizedDescription ?? "未知错误")")
            }
        }
    }

    /// 关闭网络
    private func shutdownNetwork() {
        print("🛑 关闭 AEAI 网络连接...")
        socketManager?.disconnect()
        socketManager = nil
        print("✅ AEAI 网络已关闭")
    }

    /// 重新连接（如果需要）
    private func reconnectIfNeeded() {
        if let manager = socketManager, !manager.isConnected {
            print("🔄 重新连接 AEAI 网络...")
            manager.connect { success, error in
                if !success {
                    print("❌ AEAI 网络重连失败: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }

    /// 处理连接状态变化
    private func handleStateChange(_ state: AESocketState) {
        switch state {
        case .disconnected:
            print("📡 Socket 已断开")
        case .connecting:
            print("📡 Socket 连接中...")
        case .connected:
            print("✅ Socket 已连接")
        case .failed(let error):
            print("❌ Socket 连接失败: \(error.localizedDescription)")
        }
    }

    /// 处理接收到的响应
    private func handleReceivedResponse(_ response: AENetRsp) {
        print("📦 收到响应: requestId=\(response.requestId)")

        // 通知监听者
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
            // 创建 Socket Manager
            let manager = AEAISocketManager(
                serverIP: config.serverIP,
                serverPort: config.serverPort,
                path: config.path
            )

            // 设置状态监听
            manager.onConnectionStateChanged = { [weak self] state in
                self?.handleStateChange(state)
            }

            // 设置响应接收监听
            manager.onResponseReceived = { [weak self] response in
                self?.handleReceivedResponse(response)
            }

            self.socketManager = manager
        }

        // 连接
        socketManager?.connect(completion: completion)
    }

    /// 手动断开网络
    public func disconnect() {
        socketManager?.disconnect()
        socketManager = nil
    }

    /// 获取网络连接状态
    public var isConnected: Bool {
        return socketManager?.isConnected ?? false
    }

    // MARK: - Send Methods

    /// 发送请求并返回响应
    public func sendRequest(_ request: AENetReq, completion: ((AENetRsp) -> Void)?) {
        switch request.protocolType {
        case .socket:
            guard let socketManager = self.socketManager else {
                let response = AENetRsp(
                    requestId: request.requestId,
                    protocolType: request.protocolType,
                    error: NSError(domain: "AEAINetworkModule", code: -1, userInfo: [NSLocalizedDescriptionKey: "网络未初始化"])
                )
                completion?(response)
                return
            }

            guard socketManager.isConnected else {
                let response = AENetRsp(
                    requestId: request.requestId,
                    protocolType: request.protocolType,
                    error: NSError(domain: "AEAINetworkModule", code: -2, userInfo: [NSLocalizedDescriptionKey: "网络未连接"])
                )
                completion?(response)
                return
            }

            do {
                try socketManager.send(request)
            } catch {
                let response = AENetRsp(
                    requestId: request.requestId,
                    protocolType: request.protocolType,
                    error: error
                )
                completion?(response)
            }

        case .http:
            AENetHttpEngine.send(request: request) { [weak self] rsp in
                if let completion = completion {
                    completion(rsp)
                } else if let self = self {
                    self.listenerManager.notifyListeners(response: rsp)
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
}
