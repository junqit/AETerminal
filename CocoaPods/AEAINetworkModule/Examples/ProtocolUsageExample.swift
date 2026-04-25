//
//  ProtocolUsageExample.swift
//  使用协议访问网络模块示例
//
//  通过 AEAINetworkProtocol 协议来使用网络能力
//  解耦业务层和具体实现
//

import Foundation
import AEModuleCenter
import AEAINetworkModule

// MARK: - 示例 1: 在 ViewController 中使用

class ChatViewController {

    // 通过协议持有网络服务，不直接依赖具体实现
    private var networkService: AEAINetworkProtocol?
    private let listener = ChatMessageListener()

    init() {
        // 从 AEModuleCenter 获取网络能力
        networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self)

        // 注册监听者
        networkService?.addListener(listener)
    }

    deinit {
        // 移除监听者
        networkService?.removeListener(listener)
    }

    // MARK: - 发送消息

    func sendChatMessage(_ text: String) {
        guard let service = networkService else {
            print("❌ 网络服务不可用")
            return
        }

        let data: [String: Any] = [
            "type": "chat",
            "message": text
        ]

        // 异步发送
        service.sendAsync(data: data) { result in
            switch result {
            case .success:
                print("✓ 消息发送成功")
            case .failure(let error):
                print("✗ 消息发送失败: \(error)")
            }
        }
    }

    func checkConnectionStatus() {
        if let service = networkService, service.isConnected {
            print("✓ 网络已连接")
        } else {
            print("✗ 网络未连接")
        }
    }
}

// MARK: - 示例 2: 监听者实现

class ChatMessageListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "chat_response":
            if let text = message["message"] as? String {
                print("收到 AI 回复: \(text)")
                // 更新 UI...
            }
        default:
            break
        }
    }
}

// MARK: - 示例 3: 在 Service 层使用

class NetworkServiceManager {

    static let shared = NetworkServiceManager()

    private var networkService: AEAINetworkProtocol?

    private init() {
        // 延迟获取，确保模块已注册
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self)
        }
    }

    func sendRequest(_ data: [String: Any], completion: @escaping (AENetworkSendResult) -> Void) {
        networkService?.sendAsync(data: data, completion: completion)
    }

    func addMessageListener(_ listener: AENetworkMessageListener) {
        networkService?.addListener(listener)
    }

    func removeMessageListener(_ listener: AENetworkMessageListener) {
        networkService?.removeListener(listener)
    }
}

// MARK: - 示例 4: 在 AppDelegate 中配置（完整流程）

/*
import Cocoa
import AEModuleCenter
import AEAINetworkModule

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // 1. 持有网络模块实例（强引用）
    private let networkModule = AEAINetworkModule()

    // 2. 业务侧使用的协议引用
    private var networkService: AEAINetworkProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 3. 配置网络模块
        networkModule.configure(
            serverHost: "127.0.0.1",
            serverPort: 9000
        )

        // 4. 注册到 AEModuleCenter
        AEModuleCenter.register(module: networkModule)

        // 5. 转发生命周期
        AEModuleCenter.applicationDidFinishLaunching(notification)

        // 6. 通过协议获取网络能力
        networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self)

        // 7. 使用网络服务
        testNetworkService()
    }

    func testNetworkService() {
        guard let service = networkService else {
            print("网络服务未初始化")
            return
        }

        // 注册监听者
        let listener = TestListener()
        service.addListener(listener)

        // 发送测试消息
        let data = ["type": "ping"]
        service.sendAsync(data: data) { result in
            print("发送结果: \(result)")
        }
    }
}

class TestListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        print("收到消息: \(message)")
    }
}
*/

// MARK: - 使用优势说明

/*
 通过协议使用网络模块的优势：

 1. **解耦**: 业务层只依赖协议，不依赖具体实现
    - 可以轻松替换底层网络实现
    - 测试时可以使用 Mock 实现

 2. **统一管理**: 通过 AEModuleCenter 统一管理所有模块
    - 不需要传递模块实例
    - 任何地方都可以通过协议获取能力

 3. **清晰的能力定义**: 协议明确了网络模块提供的能力
    - 发送数据（同步/异步）
    - 监听管理
    - 连接状态查询

 4. **灵活性**: 可以注册多个实现不同协议的模块
    - 每个模块提供不同的能力
    - 通过不同协议获取不同能力

 使用流程：
 AppDelegate:
   1. 创建 AEAINetworkModule 实例（保持强引用）
   2. 配置并注册到 AEModuleCenter
   3. 通过 AEAINetworkProtocol 获取能力

 业务层:
   1. 通过 AEModuleCenter.module(for: AEAINetworkProtocol.self) 获取
   2. 使用协议方法发送数据、注册监听
   3. 不需要关心具体实现

 */
