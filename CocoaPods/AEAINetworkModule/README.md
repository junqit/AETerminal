# AEAINetworkModule

基于 AENetworkSocket 的 AI 网络通信模块，提供 UDP/TCP Socket 连接和数据发送功能。

## 版本更新

### v2.0.0 - 2026/04/24

**重大更新：使用 AENetworkSocket 重构**

- ✅ 使用 AENetworkSocket 替代 AEUDPNetworkManager
- ✅ 支持 UDP 和 TCP 两种协议
- ✅ 支持发送 AENetReq 请求（自动组装为 map 格式）
- ✅ 支持字典数据直接发送
- ✅ 异步和同步发送方式
- ✅ 完整的连接状态管理
- ✅ 消息监听机制

## 功能特性

- ✅ 基于 AENetworkSocket 的 Socket 连接
- ✅ 支持 UDP 和 TCP 协议切换
- ✅ 自动将 AENetReq 组装成 map 格式发送
- ✅ 支持字典数据直接发送（自动转 JSON）
- ✅ 同步和异步发送方式
- ✅ 连接状态实时监控
- ✅ 消息接收自动解析（JSON）
- ✅ 监听者模式支持多个消息处理器
- ✅ 集成 AEModuleCenter，支持自动初始化

## 安装

在 Podfile 中添加：

```ruby
pod 'AEAINetworkModule'
```

## 快速开始

### 1. 基础使用

```swift
import AEAINetworkModule

// 创建网络模块
let networkModule = AEAINetworkModule()

// 配置网络参数
networkModule.configure(
    serverIP: "192.168.1.100",
    serverPort: 9999,
    protocolType: .udp  // 或 .tcp
)

// 连接
networkModule.connect { success, error in
    if success {
        print("✅ 连接成功")

        // 发送字典数据
        try? networkModule.send(data: [
            "type": "greeting",
            "message": "Hello Server"
        ])
    }
}
```

### 2. 发送 AENetReq 请求

```swift
// GET 请求
let getRequest = AENetReq(
    get: "/api/status",
    parameters: ["device_id": "12345"],
    headers: ["Authorization": "Bearer token"]
)

// 同步发送
try networkModule.send(getRequest)

// POST 请求
let userData = ["username": "test", "email": "test@example.com"]
let bodyData = try JSONSerialization.data(withJSONObject: userData)

let postRequest = AENetReq(
    post: "/api/users",
    headers: ["Content-Type": "application/json"],
    body: bodyData
)

try networkModule.send(postRequest)
```

### 3. 异步发送

```swift
// 异步发送字典
networkModule.sendAsync(data: [
    "type": "query",
    "content": "Hello AI"
]) { result in
    switch result {
    case .success:
        print("✅ 发送成功")
    case .failure(let error):
        print("❌ 发送失败: \(error)")
    }
}

// 异步发送请求
let request = AENetReq(post: "/api/message")
networkModule.sendAsync(request) { result in
    // 处理结果
}
```

### 4. 消息监听

```swift
// 创建监听者
class MyMessageListener: AENetworkMessageListener {
    func onMessageReceived(_ message: [String: Any]) {
        print("收到消息: \(message)")

        // 处理不同类型的消息
        if let type = message["type"] as? String {
            switch type {
            case "notification":
                handleNotification(message)
            case "response":
                handleResponse(message)
            default:
                break
            }
        }
    }
}

// 添加监听者
let listener = MyMessageListener()
networkModule.addListener(listener)

// 移除监听者
// networkModule.removeListener(listener)
```

## API 文档

### 配置方法

#### configure(serverIP:serverPort:protocolType:)

配置网络参数。

```swift
func configure(
    serverIP: String,
    serverPort: UInt16,
    protocolType: AESocketProtocol = .udp
) -> Self
```

### 连接管理

#### connect(completion:)

连接到服务器。

```swift
func connect(completion: ((Bool, Error?) -> Void)? = nil)
```

#### disconnect()

断开连接。

#### isConnected

获取当前连接状态。

```swift
var isConnected: Bool { get }
```

### 数据发送

#### send(_:) - AENetReq

同步发送 AENetReq 请求。

```swift
func send(_ request: AENetReq) throws -> Bool
```

#### send(data:)

同步发送字典数据。

```swift
func send(data: [String: Any]) throws -> Bool
```

#### sendAsync(_:completion:) - AENetReq

异步发送 AENetReq 请求。

```swift
func sendAsync(
    _ request: AENetReq,
    completion: ((Result<Bool, Error>) -> Void)? = nil
)
```

#### sendAsync(data:completion:)

异步发送字典数据。

```swift
func sendAsync(
    data: [String: Any],
    completion: ((Result<Bool, Error>) -> Void)? = nil
)
```

### 监听者管理

#### addListener(_:)

添加消息监听者。

#### removeListener(_:)

移除消息监听者。

#### removeAllListeners()

移除所有监听者。

## 数据格式说明

### 发送 AENetReq 时的数据格式

当发送 AENetReq 时，会被自动组装成以下 map 格式：

```json
{
  "method": "GET/POST/PUT...",
  "path": "/api/path",
  "parameters": {
    "key": "value"
  },
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "base64EncodedString",
  "timeout": 30
}
```

## 完整示例

查看 `Examples/AEAINetworkModuleUsageExample.swift` 获取完整使用示例。

## 依赖

- **AENetworkEngine**: 提供 Socket 连接功能
- **AEModuleCenter**: 模块管理

## 许可证

MIT License
