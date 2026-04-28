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
public class AEAINetworkModule: NSObject, AEModuleProtocol, AEAINetworkProtocol, AENetCoreDelegate {

    // MARK: - Properties

    /// 监听者管理器
    private let listenerManager: AENetworkListenerManager

    /// 网络配置集合（用于记录配置）
    private var configs: Set<AENetConfig> = []

    /// 网络配置与核心映射表（用于存储已创建的核心）
    private var netCores: [AENetConfig: AENetCoreProtocol] = [:]

    // MARK: - Initialization

    public override init() {
        self.listenerManager = AENetworkListenerManager()
        super.init()
    }

    // MARK: - Configuration

    /// 配置网络参数（仅记录配置，不创建核心）
    /// - Parameter config: 网络配置
    public func configure(with config: AENetConfig) {
        // 添加到配置集合
        configs.insert(config)
        print("✅ 配置已记录: \(config.type), \(config.host):\(config.port)")
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

    /// 初始化网络（统一创建所有网络核心）
    private func initializeNetwork() {
        // 遍历所有配置，创建对应的网络核心
        for config in configs {
            // 创建对应类型的网络核心
            let core: AENetCoreProtocol

            switch config.type {
            case .http:
                core = AENetHttpEngine(config: config)
                print("✅ HTTP 网络核心创建成功: \(config.host):\(config.port)")

            case .socket:
                core = AENetSocketCore(config: config)
                print("✅ Socket 网络核心创建成功: \(config.host):\(config.port), type=\(config.socketType)")

                // Socket 需要连接
                if let socketCore = core as? AENetSocketCore {
                    socketCore.onConnectionStateChanged = { [weak self] state in
                        self?.handleStateChange(state)
                    }

                    socketCore.connect { success, error in
                        if success {
                            print("✅ Socket 网络初始化成功")
                        } else {
                            print("❌ Socket 连接失败: \(error?.localizedDescription ?? "未知错误")")
                        }
                    }
                }
            }

            // 设置代理
            core.delegate = self

            // 保存核心到映射表
            netCores[config] = core
        }
    }

    /// 关闭网络
    private func shutdownNetwork() {
        print("🛑 关闭 AEAI 网络连接...")

        // 通过类型查找 Socket 核心并断开
        if let core = findCore(for: .socket),
           let socketCore = core as? AENetSocketCore {
            socketCore.disconnect()
        }

        print("✅ AEAI 网络已关闭")
    }

    /// 重新连接（如果需要）
    private func reconnectIfNeeded() {
        // 通过类型查找 Socket 核心
        guard let core = findCore(for: .socket),
              let socketCore = core as? AENetSocketCore else {
            return
        }

        if !socketCore.isConnected {
            print("🔄 重新连接 Socket 网络...")
            socketCore.connect { success, error in
                if !success {
                    print("❌ Socket 重连失败: \(error?.localizedDescription ?? "未知错误")")
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

    // MARK: - Public Methods

    /// 根据网络类型查找核心
    /// - Parameter type: 网络类型
    /// - Returns: 对应的网络核心（如果存在）
    private func findCore(for type: AENetworkType) -> AENetCoreProtocol? {
        for (config, core) in netCores {
            if config.type == type {
                return core
            }
        }
        return nil
    }

    /// 手动连接网络（用于需要延迟连接的场景）
    public func connect(completion: ((Bool, Error?) -> Void)? = nil) {
        // 通过类型查找 Socket 核心
        guard let core = findCore(for: .socket),
              let socketCore = core as? AENetSocketCore else {
            let error = NSError(
                domain: "AEAINetworkModule",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未配置 Socket 参数"]
            )
            completion?(false, error)
            return
        }

        socketCore.connect(completion: completion)
    }

    /// 手动断开网络
    public func disconnect() {
        // 通过类型查找 Socket 核心
        guard let core = findCore(for: .socket),
              let socketCore = core as? AENetSocketCore else {
            return
        }

        socketCore.disconnect()
    }

    /// 获取网络连接状态
    public var isConnected: Bool {
        // 通过类型查找 Socket 核心
        guard let core = findCore(for: .socket),
              let socketCore = core as? AENetSocketCore else {
            return false
        }

        return socketCore.isConnected
    }

    // MARK: - Send Methods

    /// 发送请求并返回响应
    public func sendRequest(_ request: AENetReq, completion: ((AENetRsp) -> Void)?) {
        // 根据请求的协议类型查找对应的网络核心
        let targetType: AENetworkType = (request.protocolType == .socket) ? .socket : .http

        guard let core = findCore(for: targetType) else {
            let error = NSError(
                domain: "AEAINetworkModule",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未配置 \(request.protocolType) 类型的网络核心"]
            )
            let response = AENetRsp(
                requestId: request.requestId,
                protocolType: request.protocolType,
                error: error
            )
            completion?(response)
            return
        }

        core.send(request: request, completion: completion)
    }

    // MARK: - AENetCoreDelegate

    /// 接收到网络核心主动推送的响应
    /// - Parameter response: 响应对象
    public func netCore(didReceive response: AENetRsp) {
        // 通过监听者管理器分发响应
        listenerManager.notifyListeners(response: response)
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
