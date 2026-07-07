# UDP Socket 客户端 - Swift

基于 Swift 和 Network.framework 的 UDP Socket 客户端库，用于与服务端进行双向 JSON 通信。

## 功能特性

- ✅ 基于 Apple Network.framework
- ✅ UDP Socket 通信
- ✅ JSON 数据格式支持
- ✅ 同步和异步两种模式
- ✅ 回调和 async/await 支持
- ✅ 业务层友好的 API
- ✅ 单例模式管理
- ✅ 线程安全
- ✅ 完整的示例代码

## 系统要求

- iOS 12.0+ / macOS 10.14+
- Swift 5.0+
- Xcode 13.0+

## 文件结构

```
Socket/UDP/
├── AEUDPSocketConfig.swift       # 配置和消息模型
├── AEUDPSocketClient.swift       # UDP 客户端核心类
├── AEUDPNetworkManager.swift     # 网络管理器（业务层 API）
├── Examples.swift              # 使用示例
└── README.md                   # 本文档
```

## 快速开始

### 1. 基本使用（回调方式）

```swift
import AENetworkEngine

// 1. 配置
let config = AEUDPSocketConfig(
    serverHost: "localhost",
    serverPort: 9999,
    timeout: 5.0
)

// 2. 配置管理器
let manager = AEUDPNetworkManager.shared
manager.configure(config: config)

// 3. 连接并发送消息
manager.connect { success, error in
    if success {
        // 发送聊天消息
        manager.sendChatMessage(message: "你好，服务器！") { response, error in
            if let response = response {
                print("收到响应: \(response)")
            }
            
            manager.disconnect()
        }
    }
}
```

### 2. 使用 Async/Await（推荐）

```swift
Task {
    let config = AEUDPSocketConfig(serverHost: "localhost", serverPort: 9999)
    let manager = AEUDPNetworkManager.shared
    manager.configure(config: config)
    
    do {
        // 连接
        try await manager.connect()
        
        // 测试连接
        let isAlive = try await manager.pingServer()
        print(isAlive ? "服务器在线" : "服务器离线")
        
        // 发送消息
        let response = try await manager.sendChatMessage(message: "Hello")
        print("响应: \(response)")
        
        // 断开
        manager.disconnect()
        
    } catch {
        print("错误: \(error)")
    }
}
```

### 3. 异步模式（持续接收消息）

```swift
let manager = AEUDPNetworkManager.shared
manager.configure(config: config)

manager.connect { success, _ in
    guard success else { return }
    
    // 注册消息回调
    manager.registerCallback(for: "chat_response") { response in
        print("收到聊天响应: \(response)")
    }
    
    manager.registerCallback(for: "*") { response in
        print("收到消息: \(response["type"] ?? "unknown")")
    }
    
    // 启用异步模式
    manager.enableAsyncMode()
    
    // 异步发送消息（不等待响应）
    manager.sendMessageAsync(type: "chat", data: ["message": "Hello"])
}
```

## API 文档

### AEUDPSocketConfig

配置类，用于初始化 UDP 客户端。

```swift
public struct AEUDPSocketConfig {
    var serverHost: String      // 服务器地址
    var serverPort: UInt16      // 服务器端口，默认 9999
    var timeout: TimeInterval   // 超时时间，默认 5.0 秒
    var bufferSize: Int         // 缓冲区大小，默认 4096 字节
    var enableLog: Bool         // 是否启用日志，默认 true
}
```

### AEUDPNetworkManager

业务层网络管理器（推荐使用）。

#### 配置和连接

```swift
// 配置管理器
func configure(config: AEUDPSocketConfig)

// 连接到服务器
func connect(completion: ((Bool, Error?) -> Void)?)

// 断开连接
func disconnect()

// 检查连接状态
var isConnected: Bool { get }
```

#### 同步方法（回调方式）

```swift
// 发送消息并等待响应
func sendMessage(type: String, 
                data: [String: Any],
                completion: @escaping ([String: Any]?, Error?) -> Void)

// Ping 服务器
func pingServer(completion: @escaping (Bool) -> Void)

// 发送聊天消息
func sendChatMessage(message: String,
                    contextId: String?,
                    completion: @escaping ([String: Any]?, Error?) -> Void)

// 发送自定义消息
func sendCustomMessage(data: [String: Any],
                      completion: @escaping ([String: Any]?, Error?) -> Void)

// 通用请求接口
func request(endpoint: String,
            data: [String: Any],
            timeout: TimeInterval?,
            completion: @escaping ([String: Any]?, Error?) -> Void)
```

#### 异步方法

```swift
// 启用异步模式（持续接收消息）
func enableAsyncMode()

// 禁用异步模式
func disableAsyncMode()

// 异步发送消息（不等待响应）
func sendMessageAsync(type: String,
                     data: [String: Any],
                     completion: ((Bool, Error?) -> Void)?)

// 注册回调（"*" 表示所有类型）
func registerCallback(for messageType: String, 
                     callback: @escaping ([String: Any]) -> Void)

// 取消注册回调
func unregisterCallbacks(for messageType: String)

// 清除所有回调
func clearAllCallbacks()
```

#### Async/Await 方法

```swift
@available(iOS 13.0, macOS 10.15, *)
func connect() async throws

@available(iOS 13.0, macOS 10.15, *)
func sendMessage(type: String, data: [String: Any]) async throws -> [String: Any]

@available(iOS 13.0, macOS 10.15, *)
func pingServer() async throws -> Bool

@available(iOS 13.0, macOS 10.15, *)
func sendChatMessage(message: String, contextId: String?) async throws -> [String: Any]
```

### AEUDPSocketClient

底层 UDP 客户端（高级用户使用）。

```swift
// 创建客户端
let client = AEUDPSocketClient(config: config)

// 连接
client.connect { success, error in }

// 发送数据
client.send(data: jsonDict) { success, error in }

// 接收数据
client.receive { response, error in }

// 发送并接收
client.sendAndReceive(data: jsonDict) { response, error in }

// Ping
client.ping { success, error in }

// 发送聊天
client.sendChat(message: "Hello", contextId: "user_001") { response, error in }

// 断开
client.disconnect()
```

## 消息格式

所有消息都是 JSON 格式的字典。

### 1. Ping/Pong

```swift
// 发送 Ping
manager.pingServer { isAlive in
    print(isAlive)
}

// 等价于
let pingData: [String: Any] = [
    "type": "ping",
    "timestamp": ISO8601DateFormatter().string(from: Date())
]
```

### 2. 聊天消息

```swift
// 发送聊天消息
manager.sendChatMessage(message: "你好", contextId: "user_123") { response, error in
    // 响应格式:
    // {
    //   "status": "success",
    //   "type": "chat_response",
    //   "message": "...",
    //   "context_id": "user_123"
    // }
}
```

### 3. 自定义消息

```swift
// 发送自定义数据
let customData: [String: Any] = [
    "action": "query",
    "params": ["key": "value"]
]

manager.sendCustomMessage(data: customData) { response, error in
    // 处理响应
}
```

## 使用场景

### 场景 1: 简单的请求-响应

```swift
Task {
    try await manager.connect()
    
    let response = try await manager.sendMessage(
        type: "calculate",
        data: ["operation": "add", "a": 10, "b": 20]
    )
    
    print("结果: \(response)")
    manager.disconnect()
}
```

### 场景 2: 实时消息推送

```swift
// 启用异步模式接收推送
manager.registerCallback(for: "notification") { response in
    let message = response["message"] as? String
    // 显示通知
    showNotification(message)
}

manager.enableAsyncMode()
```

### 场景 3: 心跳检测

```swift
class HeartbeatService {
    private let manager = AEUDPNetworkManager.shared
    private var timer: Timer?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.manager.pingServer { isAlive in
                if !isAlive {
                    print("服务器离线")
                    self.handleServerOffline()
                }
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
    }
}
```

### 场景 4: 业务层封装

```swift
class ChatService {
    private let manager = AEUDPNetworkManager.shared
    private var userId: String?
    
    init(serverHost: String, serverPort: UInt16) {
        let config = AEUDPSocketConfig(
            serverHost: serverHost,
            serverPort: serverPort
        )
        manager.configure(config: config)
    }
    
    func login(userId: String, completion: @escaping (Bool) -> Void) {
        self.userId = userId
        
        manager.connect { success, _ in
            completion(success)
        }
    }
    
    func sendMessage(_ message: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        manager.sendChatMessage(message: message, contextId: userId) { response, error in
            completion(error == nil)
        }
    }
    
    func logout() {
        manager.disconnect()
        userId = nil
    }
}

// 使用
let chatService = ChatService(serverHost: "localhost", serverPort: 9999)
chatService.login(userId: "user_001") { success in
    if success {
        chatService.sendMessage("Hello") { _ in
            chatService.logout()
        }
    }
}
```

## 错误处理

```swift
// 方式 1: 回调方式
manager.sendChatMessage(message: "Hello") { response, error in
    if let error = error {
        print("错误: \(error.localizedDescription)")
        return
    }
    
    guard let response = response else {
        print("响应为空")
        return
    }
    
    // 检查服务器状态
    if let status = response["status"] as? String {
        if status == "error" {
            let message = response["message"] as? String ?? "未知错误"
            print("服务器错误: \(message)")
        } else {
            // 成功
            print("成功: \(response)")
        }
    }
}

// 方式 2: Async/Await
Task {
    do {
        let response = try await manager.sendChatMessage(message: "Hello")
        
        if let status = response["status"] as? String, status == "success" {
            print("成功")
        }
    } catch {
        print("错误: \(error)")
    }
}
```

## 线程安全

- `AEUDPNetworkManager` 使用单例模式，线程安全
- 所有回调都在内部队列执行，可以安全访问
- 如需更新 UI，请切换到主线程：

```swift
manager.sendChatMessage(message: "Hello") { response, error in
    DispatchQueue.main.async {
        // 更新 UI
        self.updateUI(with: response)
    }
}
```

## 运行示例

查看 `Examples.swift` 文件中的完整示例代码：

```swift
// 运行基本示例
AEUDPSocketExamples.example1_basicUsage()

// 运行 Async/Await 示例
Task {
    await AEUDPSocketExamples.example2_asyncAwait()
}

// 运行异步模式示例
AEUDPSocketExamples.example3_asyncMode()

// 运行业务层示例
AEUDPSocketExamples.example4_businessLayer()

// 运行所有示例
runAllExamples()
```

## 故障排查

### 问题 1: 连接超时

**检查：**
- 服务器是否启动
- 服务器地址和端口是否正确
- 防火墙是否阻止连接

### 问题 2: 消息丢失

UDP 不保证可靠传输。可以：
- 在应用层实现确认机制
- 使用消息序列号
- 添加重传逻辑

### 问题 3: 编译错误

确保：
- Xcode 版本 >= 13.0
- 部署目标 >= iOS 12.0 / macOS 10.14
- 导入了 `Network` framework

## 性能优化

1. **连接复用**：尽量复用 `AEUDPNetworkManager.shared`
2. **异步模式**：高频通信场景使用异步模式
3. **超时设置**：根据网络情况调整 timeout
4. **缓冲区大小**：大消息场景增加 bufferSize

## CocoaPods 集成

如果这是 CocoaPods 库的一部分，在 Podfile 中添加：

```ruby
pod 'AENetworkEngine'
```

或指定子模块：

```ruby
pod 'AENetworkEngine/Socket/UDP'
```

## 相关文档

- [服务端文档](../../../../../Service/agent_one/Network/README.md)
- [UDP Socket 快速入门](../../../../../UDP_SOCKET_GUIDE.md)

## 注意事项

1. **生产环境**：不要使用 `localhost`，使用实际的服务器 IP
2. **安全性**：UDP 是明文传输，敏感数据需要加密
3. **可靠性**：UDP 不保证可靠传输，关键数据需要应用层确认
4. **日志**：生产环境可以关闭日志：`config.enableLog = false`

## 许可证

根据项目主许可证

---

## 快速测试

```bash
# 1. 启动服务器
cd Service/agent_one/Network
python start_udp_server.py

# 2. 在 Xcode 中运行客户端代码
```

祝您使用愉快！ 🎉
