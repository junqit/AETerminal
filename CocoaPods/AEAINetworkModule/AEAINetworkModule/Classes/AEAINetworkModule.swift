//
//  AEAINetworkModule.swift
//  AEAINetworkModule
//
//  Created on 2026/04/15.
//

import Foundation
import AEModuleCenter
import AENetworkEngine
import AEUserAccountModule
import AELogProxy

/// AEAI 网络模块 - 负责管理网络连接
public class AEAINetworkModule: NSObject, AEModuleProtocol, AEAINetworkProtocol, AENetCoreDelegate {

    // MARK: - Properties

    /// 监听者管理器
    private let listenerManager: AENetworkListenerManager

    /// 网络配置集合（用于记录配置）
    private var configs: Set<AENetConfig> = []

    /// 网络配置与核心映射表（用于存储已创建的核心）
    private var netCores: [AENetConfig: AENetCoreProtocol] = [:]

    /// Socket 引擎
    private var socketEngine: AENetSocketEngine?

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
        AELog("✅ 配置已记录: \(config.type), \(config.host):\(config.port)")
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
        for config in configs {
            switch config.type {
            case .http:
                let core = AENetHttpEngine(config: config)
                core.delegate = self
                netCores[config] = core
                AELog("✅ HTTP 网络核心创建成功: \(config.host):\(config.port)")

            case .socket:
                let engine = AENetSocketEngine(ip: config.host, port: config.port, protocolType: config.socketType)
                engine.onStateChanged = { [weak self] state in
                    self?.handleStateChange(state)
                }
                engine.onResponseReceived = { [weak self] response in
                    self?.listenerManager.notifyListeners(response: response)
                }
                do {
                    try engine.connect()
                    AELog("✅ Socket 网络核心创建成功: \(config.host):\(config.port)")
                } catch {
                    AELog("❌ Socket 连接失败: \(error.localizedDescription)")
                }
                socketEngine = engine
            }
        }
    }

    /// 关闭网络
    private func shutdownNetwork() {
        AELog("🛑 关闭 AEAI 网络连接...")
        socketEngine?.disconnect()
        AELog("✅ AEAI 网络已关闭")
    }

    /// 重新连接（如果需要）
    private func reconnectIfNeeded() {
        guard let engine = socketEngine else { return }
        if case .connected = engine.state { return }
        AELog("🔄 重新连接 Socket 网络...")
        do {
            try engine.connect()
        } catch {
            AELog("❌ Socket 重连失败: \(error.localizedDescription)")
        }
    }

    /// 处理连接状态变化
    private func handleStateChange(_ state: AESocketState) {
        switch state {
        case .disconnected:
            AELog("📡 Socket 已断开")
        case .connecting:
            AELog("📡 Socket 连接中...")
        case .connected:
            AELog("✅ Socket 已连接")
        case .failed(let error):
            AELog("❌ Socket 连接失败: \(error.localizedDescription)")
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
        guard let engine = socketEngine else {
            let error = NSError(
                domain: "AEAINetworkModule",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未配置 Socket 参数"]
            )
            completion?(false, error)
            return
        }
        do {
            try engine.connect()
            completion?(true, nil)
        } catch {
            completion?(false, error)
        }
    }

    /// 手动断开网络
    public func disconnect() {
        socketEngine?.disconnect()
    }

    /// 获取网络连接状态
    public var isConnected: Bool {
        guard let engine = socketEngine else { return false }
        if case .connected = engine.state { return true }
        return false
    }

    // MARK: - Send Methods

    /// 发送请求，响应通过 request.onStreamReceived / request.onCompleted 回调
    public func sendRequest(_ request: AENetReq) {
        switch request.protocolType {
        case .socket:
            guard let engine = socketEngine else {
                let response = AENetRsp(
                    requestId: request.requestId,
                    protocolType: request.protocolType,
                    code: .serviceUnavailable
                )
                request.onCompleted?(response)
                return
            }
            do {
                try engine.send(request)
            } catch {
                let response = AENetRsp(
                    requestId: request.requestId,
                    protocolType: request.protocolType,
                    code: .serverError
                )
                request.onCompleted?(response)
            }

        case .http:
            guard let core = findCore(for: .http) else {
                let response = AENetRsp(
                    requestId: request.requestId,
                    protocolType: request.protocolType,
                    code: .serviceUnavailable
                )
                request.onCompleted?(response)
                return
            }
            core.send(request: request)
        }
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
