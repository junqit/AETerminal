# AEAINetworkModule

AEAINetworkModule 是一个网络通信模块，集成了 AENetworkSocket 提供 UDP Socket 连接功能。

## 更新说明

### v1.1.0 - 2026/04/23

- ✅ 集成 AENetworkSocket 支持 UDP 连接
- ✅ 添加 AEAISocketManager 管理类
- ✅ 支持发送 AENetReq 请求（自动组装为 map 格式）
- ✅ 支持原始数据和字典数据发送
- ✅ 提供完整的状态监听和消息回调

## 功能特性

- ✅ 基于 AENetworkSocket 的 UDP 连接
- ✅ 自动将 AENetReq 组装成 map 格式发送
- ✅ 支持多种数据格式发送（AENetReq、字典、原始数据）
- ✅ 异步连接和状态监听
- ✅ 消息接收自动解析
- ✅ 便利方法支持快速集成

## 安装

在 Podfile 中添加：

```ruby
pod 'AEAINetworkModule'
```

## 核心组件

### AEAISocketManager

使用 AENetworkSocket 进行 UDP 连接的管理类。

## 使用示例

### 1. 基础 UDP 连接

```swift
import AEAINetworkModule

// 创建 Socket 管理器
let socketManager = AEAISocketManager(
    serverIP: "192.168.1.100",
    serverPort: 9999,
    path: ""
)

// 设置消息接收回调
socketManager.onMessageReceived = { message in
    print("收到服务器消息: \(message)")
}

// 连接到服务器
socketManager.connect { success, error in
    if success {
        print("UDP 连接成功")
        
        // 发送字典数据
        try? socketManager.send(data: [
            "type": "greeting",
            "message": "Hello Server",
            "timestamp": Date().timeIntervalSince1970
        ])
    } else {
        print("UDP 连接失败: \(error?.localizedDescription ?? "")")
    }
}
```

### 2. 发送 AENetReq（自动组装成 map）

```swift
// 创建 GET 请求
let getRequest = AENetReq(
    get: "/api/status",
    parameters: ["device_id": "12345"],
    headers: ["Authorization": "Bearer token123"]
)

// 发送请求（会自动组装成如下 map 格式）:
// {
//   "method": "GET",
//   "path": "/api/status",
//   "parameters": {"device_id": "12345"},
//   "headers": {"Authorization": "Bearer token123"},
//   "timeout": 30
// }
try socketManager.send(getRequest)

// 或使用便利方法
try socketManager.sendGet(
    path: "/api/status",
    parameters: ["device_id": "12345"]
)
```

### 3. 发送 POST 请求

```swift
// 准备 POST 数据
let userData = [
    "username": "testuser",
    "email": "test@example.com"
]
let bodyData = try JSONSerialization.data(withJSONObject: userData)

// 创建 POST 请求
let postRequest = AENetReq(
    post: "/api/users",
    headers: ["Content-Type": "application/json"],
    body: bodyData
)

// 发送请求（会自动组装成 map，body 会转换为 base64）
try socketManager.send(postRequest)

// 或使用便利方法
try socketManager.sendPost(
    path: "/api/users",
    body: bodyData
)
```

### 4. 状态监听

```swift
let socketManager = AEAISocketManager(
    serverIP: "192.168.1.100",
    serverPort: 9999
)

// 监听连接状态变化
socketManager.onConnectionStateChanged = { state in
    switch state {
    case .disconnected:
        print("状态: 已断开")
    case .connecting:
        print("状态: 连接中...")
    case .connected:
        print("状态: 已连接")
    case .failed(let error):
        print("状态: 连接失败 - \(error)")
    }
}

// 监听原始数据
socketManager.onDataReceived = { data in
    print("收到原始数据: \(data.count) 字节")
}

// 监听解析后的消息（自动解析为字典）
socketManager.onMessageReceived = { message in
    if let type = message["type"] as? String {
        switch type {
        case "notification":
            handleNotification(message)
        case "response":
            handleResponse(message)
        default:
            print("未知消息类型: \(type)")
        }
    }
}

socketManager.connect()
```

### 5. 集成到应用中

```swift
class MyNetworkModule {
    private var socketManager: AEAISocketManager?
    
    func configure(serverIP: String, serverPort: UInt16) {
        socketManager = AEAISocketManager(
            serverIP: serverIP,
            serverPort: serverPort
        )
        
        socketManager?.onMessageReceived = { [weak self] message in
            self?.handleIncomingMessage(message)
        }
        
        socketManager?.connect { success, error in
            if success {
                print("✅ Socket 连接成功")
            } else {
                print("❌ Socket 连接失败: \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    func sendData(_ data: [String: Any]) {
        try? socketManager?.send(data: data)
    }
    
    private func handleIncomingMessage(_ message: [String: Any]) {
        // 处理接收到的消息
    }
    
    func disconnect() {
        socketManager?.disconnect()
    }
}
```

### 6. 便利方法使用

```swift
// 一行代码创建并连接
let socketManager = AEAISocketManager.createAndConnect(
    serverIP: "192.168.1.100",
    serverPort: 9999
) { success, error in
    if success {
        print("连接成功")
    }
}
```

## AENetReq 组装格式说明

当你发送 AENetReq 时，它会被自动组装成以下 map 格式：

```json
{
  "method": "GET/POST/PUT/DELETE...",
  "path": "/api/path",
  "parameters": {
    "key1": "value1",
    "key2": "value2"
  },
  "headers": {
    "Content-Type": "application/json",
    "Authorization": "Bearer token"
  },
  "body": "base64EncodedString",
  "timeout": 30
}
```

**注意**：
- `path` 直接使用 `request.path`，不会拼接初始化时的 path 参数
- `body` 如果存在，会被转换为 base64 字符串
- 整个 map 会被序列化为 JSON 数据后通过 UDP 发送

## API 文档

### AEAISocketManager

#### 初始化

```swift
init(serverIP: String, serverPort: UInt16, path: String = "")
```

#### 属性

- `isConnected: Bool` - 是否已连接
- `onConnectionStateChanged: ((AESocketState) -> Void)?` - 连接状态变化回调
- `onDataReceived: ((Data) -> Void)?` - 原始数据接收回调
- `onMessageReceived: (([String: Any]) -> Void)?` - 解析后的消息接收回调

#### 方法

##### connect

```swift
func connect(completion: ((Bool, Error?) -> Void)? = nil)
```

连接到服务器。

##### disconnect

```swift
func disconnect()
```

断开连接。

##### send(_:)

```swift
func send(_ request: AENetReq) throws
```

发送 AENetReq 请求（自动组装成 map）。

##### send(data:)

```swift
func send(data: [String: Any]) throws
```

发送字典数据。

##### send(rawData:)

```swift
func send(rawData data: Data) throws
```

发送原始数据。

##### sendGet

```swift
func sendGet(path: String, parameters: [String: Any]? = nil) throws
```

便利方法：发送 GET 请求。

##### sendPost

```swift
func sendPost(path: String, parameters: [String: Any]? = nil, body: Data? = nil) throws
```

便利方法：发送 POST 请求。

##### createAndConnect

```swift
static func createAndConnect(
    serverIP: String,
    serverPort: UInt16,
    path: String = "",
    completion: ((Bool, Error?) -> Void)? = nil
) -> AEAISocketManager
```

静态便利方法：创建并连接。

## 依赖

- AENetworkEngine - 提供 Socket 连接功能
- AEModuleCenter - 模块管理

## 线程安全

所有网络操作都在内部的串行队列中执行，回调也在该队列中触发。如果需要更新 UI，请使用 `DispatchQueue.main.async`。

## 注意事项

1. 使用完毕后记得调用 `disconnect()` 断开连接
2. Socket 会在对象销毁时自动断开连接
3. UDP 是无连接协议，但仍需调用 `connect()` 来建立端点
4. 发送 AENetReq 时，会自动组装成 map 格式，不会拼接 HTTP 协议头
5. 建议在生产环境中添加重连机制和超时处理

## 示例项目

查看 `Examples/AEAISocketUsageExample.swift` 获取更多使用示例。

## 许可证

MIT License
