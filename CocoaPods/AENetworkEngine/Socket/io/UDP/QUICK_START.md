# UDP Socket 快速开始指南

完整的 UDP Socket 双向通信解决方案 - Swift 客户端与 Python 服务端。

## 📦 文件清单

### Swift 客户端文件
- ✅ `AEUDPSocketConfig.swift` - 配置和消息模型
- ✅ `UDPSocketClient.swift` - UDP 客户端核心类
- ✅ `AEUDPNetworkManager.swift` - 业务层管理器（推荐使用）
- ✅ `UDPSocket.swift` - 模块主文件
- ✅ `Examples.swift` - 完整示例代码
- ✅ `README.md` - 详细文档

### Python 服务端文件
位于 `/Service/agent_one/Network/`:
- ✅ `udp_server.py` - UDP 服务器
- ✅ `message_handler.py` - 消息处理器
- ✅ `start_udp_server.py` - 启动脚本

## 🚀 30 秒快速开始

### 第 1 步：启动服务端

```bash
cd /Users/tianjunqi/Project/Self/Agents/Service/agent_one/Network
python start_udp_server.py
```

看到这个输出表示成功：
```
UDP 服务器启动成功: 0.0.0.0:9999
```

### 第 2 步：在 Swift 中使用

```swift
import AENetworkEngine

// 配置
let config = AEUDPSocketConfig(
    serverHost: "localhost",
    serverPort: 9999
)

let manager = AEUDPNetworkManager.shared
manager.configure(config: config)

// 连接并发送
manager.connect { success, _ in
    guard success else { return }
    
    manager.sendChatMessage(message: "你好！") { response, error in
        print("响应: \(response ?? [:])")
        manager.disconnect()
    }
}
```

### 第 3 步：使用 Async/Await（更简洁）

```swift
Task {
    let config = AEUDPSocketConfig(serverHost: "localhost", serverPort: 9999)
    let manager = AEUDPNetworkManager.shared
    manager.configure(config: config)
    
    try await manager.connect()
    let response = try await manager.sendChatMessage(message: "你好！")
    print("响应: \(response)")
    manager.disconnect()
}
```

## 💡 三种使用模式

### 模式 1：同步模式（回调）

适合简单的请求-响应场景。

```swift
manager.sendChatMessage(message: "Hello") { response, error in
    if let response = response {
        print("成功: \(response)")
    }
}
```

### 模式 2：异步模式（持续监听）

适合需要持续接收服务器消息的场景。

```swift
// 注册回调
manager.registerCallback(for: "chat_response") { response in
    print("收到聊天: \(response)")
}

manager.registerCallback(for: "*") { response in
    print("收到任意消息: \(response)")
}

// 启用异步模式
manager.enableAsyncMode()

// 异步发送（不等待响应）
manager.sendMessageAsync(type: "chat", data: ["message": "Hello"])
```

### 模式 3：Async/Await（推荐）

最简洁的现代 Swift 方式。

```swift
Task {
    try await manager.connect()
    
    // 单个请求
    let response = try await manager.sendChatMessage(message: "Hello")
    
    // 多个请求
    for i in 1...5 {
        let resp = try await manager.sendChatMessage(message: "消息 \(i)")
        print(resp)
    }
    
    manager.disconnect()
}
```

## 🎯 常用功能

### 1. Ping 测试

```swift
// 回调方式
manager.pingServer { isAlive in
    print(isAlive ? "在线" : "离线")
}

// Async/Await
let isAlive = try await manager.pingServer()
```

### 2. 发送聊天消息

```swift
// 基本消息
manager.sendChatMessage(message: "Hello") { response, _ in
    print(response)
}

// 带上下文 ID
manager.sendChatMessage(message: "Hello", contextId: "user_123") { response, _ in
    print(response)
}
```

### 3. 发送自定义数据

```swift
let customData: [String: Any] = [
    "action": "query",
    "params": ["key": "value"]
]

manager.sendCustomMessage(data: customData) { response, _ in
    print(response)
}
```

### 4. 批量发送

```swift
let messages: [(String, [String: Any])] = [
    ("chat", ["message": "消息1"]),
    ("chat", ["message": "消息2"]),
    ("ping", [:])
]

manager.batchSend(messages: messages) { responses, errors in
    print("成功: \(responses.compactMap { $0 }.count)")
}
```

## 📝 消息格式

所有消息都是 JSON 格式的字典。

### 请求格式

```swift
[String: Any] = [
    "type": "消息类型",
    "其他字段": "值",
    ...
]
```

### 支持的消息类型

| 类型 | 用途 | 示例 |
|------|------|------|
| `ping` | 测试连接 | `manager.pingServer()` |
| `chat` | 聊天消息 | `manager.sendChatMessage()` |
| `context` | 上下文操作 | `manager.request(endpoint: "context", ...)` |
| `custom` | 自定义 | `manager.sendCustomMessage()` |

### 响应格式

```swift
[String: Any] = [
    "status": "success" or "error",
    "type": "响应类型",
    "message": "消息内容",
    "timestamp": "时间戳",
    ...
]
```

## 🏗️ 业务层封装示例

```swift
class AEChatService {
    private let manager = AEUDPNetworkManager.shared
    private var userId: String?
    
    init(serverHost: String = "localhost", serverPort: UInt16 = 9999) {
        let config = AEUDPSocketConfig(
            serverHost: serverHost,
            serverPort: serverPort
        )
        manager.configure(config: config)
    }
    
    // 登录
    func login(userId: String, completion: @escaping (Bool) -> Void) {
        self.userId = userId
        
        manager.connect { success, _ in
            if success {
                self.manager.pingServer { isAlive in
                    completion(isAlive)
                }
            } else {
                completion(false)
            }
        }
    }
    
    // 发送消息
    func sendMessage(_ message: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        manager.sendChatMessage(message: message, contextId: userId) { response, error in
            completion(error == nil && response != nil)
        }
    }
    
    // 登出
    func logout() {
        manager.disconnect()
        userId = nil
    }
}

// 使用
let chat = AEChatService()
chat.login(userId: "user_001") { success in
    if success {
        chat.sendMessage("Hello") { sent in
            print(sent ? "发送成功" : "发送失败")
            chat.logout()
        }
    }
}
```

## 🔧 配置选项

```swift
let config = AEUDPSocketConfig(
    serverHost: "192.168.1.100",  // 服务器 IP
    serverPort: 9999,              // 端口
    timeout: 5.0,                  // 超时时间（秒）
    bufferSize: 4096,              // 缓冲区大小（字节）
    enableLog: true                // 是否启用日志
)
```

## 🎨 在 UIViewController 中使用

```swift
class ChatViewController: UIViewController {
    let manager = AEUDPNetworkManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUDP()
    }
    
    func setupUDP() {
        let config = AEUDPSocketConfig(serverHost: "localhost", serverPort: 9999)
        manager.configure(config: config)
        
        manager.connect { [weak self] success, _ in
            if success {
                self?.sendButton.isEnabled = true
            }
        }
    }
    
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        guard let message = textField.text else { return }
        
        manager.sendChatMessage(message: message) { [weak self] response, error in
            DispatchQueue.main.async {
                if let response = response,
                   let message = response["message"] as? String {
                    self?.messageLabel.text = message
                }
            }
        }
    }
    
    deinit {
        manager.disconnect()
    }
}
```

## 🎯 在 SwiftUI 中使用

```swift
import SwiftUI

class AEUDPViewModel: ObservableObject {
    private let manager = AEUDPNetworkManager.shared
    @Published var messages: [String] = []
    @Published var isConnected = false
    
    init() {
        let config = AEUDPSocketConfig(serverHost: "localhost", serverPort: 9999)
        manager.configure(config: config)
    }
    
    func connect() {
        manager.connect { [weak self] success, _ in
            DispatchQueue.main.async {
                self?.isConnected = success
            }
        }
    }
    
    func sendMessage(_ message: String) {
        manager.sendChatMessage(message: message) { [weak self] response, _ in
            if let response = response,
               let msg = response["message"] as? String {
                DispatchQueue.main.async {
                    self?.messages.append(msg)
                }
            }
        }
    }
    
    func disconnect() {
        manager.disconnect()
        isConnected = false
    }
}

struct ChatView: View {
    @StateObject private var viewModel = AEUDPViewModel()
    @State private var inputText = ""
    
    var body: some View {
        VStack {
            // 连接状态
            Text(viewModel.isConnected ? "已连接" : "未连接")
                .foregroundColor(viewModel.isConnected ? .green : .red)
            
            // 消息列表
            List(viewModel.messages, id: \.self) { message in
                Text(message)
            }
            
            // 输入框
            HStack {
                TextField("输入消息", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("发送") {
                    viewModel.sendMessage(inputText)
                    inputText = ""
                }
                .disabled(!viewModel.isConnected)
            }
            .padding()
        }
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }
}
```

## 🐛 常见问题

### Q1: 如何处理连接失败？

```swift
manager.connect { success, error in
    if !success {
        print("连接失败: \(error?.localizedDescription ?? "未知错误")")
        // 重试逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.retryConnect()
        }
    }
}
```

### Q2: 如何实现心跳检测？

```swift
class AEHeartbeatManager {
    private let manager = AEUDPNetworkManager.shared
    private var timer: Timer?
    
    func startHeartbeat() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.manager.pingServer { isAlive in
                if !isAlive {
                    print("服务器离线，尝试重连...")
                }
            }
        }
    }
    
    func stopHeartbeat() {
        timer?.invalidate()
        timer = nil
    }
}
```

### Q3: 如何处理超时？

```swift
// 设置超时时间
let config = AEUDPSocketConfig(
    serverHost: "localhost",
    serverPort: 9999,
    timeout: 3.0  // 3秒超时
)

// 发送时会自动应用超时
manager.sendChatMessage(message: "Hello") { response, error in
    if error != nil {
        print("请求超时或失败")
    }
}
```

## 📚 完整示例

查看 `Examples.swift` 文件，包含 6 个完整示例：
1. 基本使用
2. Async/Await
3. 异步模式
4. 业务层封装
5. 错误处理
6. 批量发送

运行示例：
```swift
// 运行单个示例
AEUDPSocketExamples.example1_basicUsage()

// 运行所有示例
runAllExamples()
```

## 🔗 相关链接

- [详细 API 文档](README.md)
- [服务端文档](../../../../../Service/agent_one/Network/README.md)
- [完整系统指南](../../../../../UDP_SOCKET_GUIDE.md)

## 💡 最佳实践

1. **使用单例**：`AEUDPNetworkManager.shared` 管理全局连接
2. **资源管理**：在 `deinit` 或视图消失时调用 `disconnect()`
3. **主线程更新 UI**：回调中使用 `DispatchQueue.main.async`
4. **错误处理**：总是检查 `error` 和 `response`
5. **日志控制**：生产环境关闭日志 `config.enableLog = false`

## 🎉 开始使用

1. 启动服务器
2. 在项目中导入模块
3. 配置并连接
4. 发送消息
5. 处理响应

就这么简单！ 🚀
