# AENetworkSocket

AENetworkSocket 是一个基于 Network.framework 的 Swift Socket 连接类，支持 TCP 和 UDP 协议通信。

## 功能特性

- ✅ 支持 TCP 和 UDP 协议
- ✅ 通过 IP、PORT、PATH 三个参数配置连接
- ✅ 可发送 AENetReq 消息
- ✅ 支持原始数据发送
- ✅ 异步状态监听
- ✅ 数据接收回调
- ✅ 自动重连机制

## 安装

在 Podfile 中添加：

```ruby
pod 'AENetworkEngine/Socket'
```

## 使用示例

### 1. TCP 连接

```swift
import AENetworkEngine

// 创建 TCP Socket
let tcpSocket = AENetworkSocket(
    ip: "192.168.1.100",
    port: 8080,
    path: "/api",
    protocolType: .tcp
)

// 监听连接状态
tcpSocket.onStateChanged = { state in
    switch state {
    case .connected:
        print("已连接")
    case .disconnected:
        print("已断开")
    case .connecting:
        print("连接中...")
    case .failed(let error):
        print("连接失败: \(error)")
    }
}

// 监听接收数据
tcpSocket.onDataReceived = { data in
    if let response = String(data: data, encoding: .utf8) {
        print("收到响应: \(response)")
    }
}

// 连接
try tcpSocket.connect()

// 创建并发送 HTTP 请求
let request = AENetReq(
    get: "/users",
    parameters: ["page": 1, "limit": 10],
    headers: ["Content-Type": "application/json"]
)
try tcpSocket.send(request)
```

### 2. UDP 连接

```swift
// 创建 UDP Socket
let udpSocket = AENetworkSocket(
    ip: "192.168.1.100",
    port: 9090,
    path: "/data",
    protocolType: .udp
)

// 连接并发送
try udpSocket.connect()

let jsonData = try? JSONSerialization.data(withJSONObject: ["message": "Hello UDP"])
let request = AENetReq(
    post: "/send",
    headers: ["Content-Type": "application/json"],
    body: jsonData
)
try udpSocket.send(request)
```

### 3. 便利方法：连接并发送

```swift
let socket = AENetworkSocket(
    ip: "api.example.com",
    port: 443,
    path: "/v1",
    protocolType: .tcp
)

let request = AENetReq(
    method: .POST,
    path: "/login",
    headers: ["Content-Type": "application/json"],
    body: loginData
)

// 自动连接并发送请求
try socket.connectAndSend(request)
```

### 4. 发送原始数据

```swift
let socket = AENetworkSocket(
    ip: "192.168.1.100",
    port: 8888,
    path: "",
    protocolType: .tcp
)

try socket.connect()

let rawData = "Hello, Socket!".data(using: .utf8)!
try socket.send(rawData)
```

## API 文档

### 初始化

```swift
init(ip: String, port: UInt16, path: String, protocolType: AESocketProtocol = .tcp)
```

**参数：**
- `ip`: IP 地址
- `port`: 端口号
- `path`: 请求路径前缀
- `protocolType`: 协议类型（.tcp 或 .udp），默认为 .tcp

### 方法

#### connect()

连接到指定的 Socket 服务器。

```swift
public func connect() throws
```

#### disconnect()

断开当前连接。

```swift
public func disconnect()
```

#### send(_:)

发送 AENetReq 请求。

```swift
public func send(_ request: AENetReq) throws
```

#### send(_:)

发送原始数据。

```swift
public func send(_ data: Data) throws
```

#### connectAndSend(_:)

便利方法：连接并发送请求。

```swift
public func connectAndSend(_ request: AENetReq) throws
```

### 属性

#### state

当前连接状态（只读）。

```swift
public private(set) var state: AESocketState
```

**状态类型：**
- `.disconnected`: 已断开
- `.connecting`: 连接中
- `.connected`: 已连接
- `.failed(Error)`: 连接失败

#### onStateChanged

状态变化回调。

```swift
public var onStateChanged: ((AESocketState) -> Void)?
```

#### onDataReceived

接收数据回调。

```swift
public var onDataReceived: ((Data) -> Void)?
```

## 错误处理

```swift
enum AESocketError: Error {
    case invalidAddress      // 无效地址
    case connectionFailed    // 连接失败
    case sendFailed         // 发送失败
    case notConnected       // 未连接
    case encodingFailed     // 编码失败
}
```

## 线程安全

所有网络操作都在内部的串行队列中执行，回调也在该队列中触发。如果需要更新 UI，请使用 `DispatchQueue.main.async`。

## 注意事项

1. 使用完毕后记得调用 `disconnect()` 断开连接
2. Socket 会在对象销毁时自动断开连接
3. UDP 是无连接协议，但仍需调用 `connect()` 来建立端点
4. 建议在生产环境中添加重连机制和超时处理

## 许可证

MIT License
