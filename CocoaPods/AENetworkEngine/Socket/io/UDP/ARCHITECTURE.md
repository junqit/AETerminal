# UDP Socket 架构设计文档

## 🏗️ 架构概览

```
┌─────────────────────────────────────────────────────────┐
│                     业务层                                │
│  (UIViewController / SwiftUI View / Service)            │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│           AEUDPNetworkManager (管理层)                   │
│  • 单例模式                                              │
│  • 配置管理                                              │
│  • 业务层 API                                            │
│  • 推送消息回调管理                                       │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│           AEUDPSocketClient (传输层)                     │
│  • Network.framework 封装                                │
│  • 请求-响应匹配                                         │
│  • 持续监听                                              │
│  • request_id 生成和管理                                 │
│  • 超时处理                                              │
│  • 线程安全                                              │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│              Network.framework                           │
│  • NWConnection (UDP)                                    │
│  • 底层网络 I/O                                          │
└─────────────────────────────────────────────────────────┘
```

## 📦 核心组件

### 1. AEUDPSocketConfig
**职责：** 配置管理

```swift
public struct AEUDPSocketConfig {
    var serverHost: String      // 服务器地址
    var serverPort: UInt16      // 服务器端口
    var timeout: TimeInterval   // 超时时间
    var bufferSize: Int         // 缓冲区大小
    var enableLog: Bool         // 日志开关
}
```

### 2. AEUDPSocketClient
**职责：** UDP 传输层核心逻辑

**核心功能：**
- ✅ 连接管理（NWConnection）
- ✅ 请求 ID 生成（`req_{timestamp}_{counter}`）
- ✅ 请求-响应匹配（`pendingRequests` 字典）
- ✅ 持续监听（递归 `receiveMessage`）
- ✅ 超时处理（定时器）
- ✅ 推送消息处理（`pushMessageHandler`）
- ✅ 线程安全（NSLock + 原子计数器）

**关键方法：**
```swift
// 连接
func connect(completion: ((Bool, Error?) -> Void)?)

// 发送（自动添加 request_id）
func send(data: [String: Any], completion: (([String: Any]?, Error?) -> Void)?)

// 持续监听
private func startContinuousListening()
private func listenForNextMessage()

// 消息处理
private func handleReceivedData(_ data: Data)
private func handleResponseMessage(requestId: String, response: [String: Any])
private func handlePushMessage(_ message: [String: Any])
```

### 3. AEUDPNetworkManager
**职责：** 业务层 API 管理器

**核心功能：**
- ✅ 单例模式（`shared`）
- ✅ 配置管理
- ✅ 业务友好的 API
- ✅ 推送消息回调管理
- ✅ 批量操作支持

**关键方法：**
```swift
// 配置
func configure(config: AEUDPSocketConfig)

// 连接管理
func connect(completion: ((Bool, Error?) -> Void)?)
func disconnect()

// 请求-响应
func sendMessage(type: String, data: [String: Any], completion: ...)
func sendChatMessage(message: String, contextId: String?, completion: ...)
func pingServer(completion: (Bool) -> Void)

// 推送消息
func registerPushMessageCallback(for messageType: String, callback: ...)
func unregisterPushMessageCallbacks(for messageType: String)
```

## 🔄 消息流程

### 请求-响应流程

```
[业务层]
   │
   ├─ sendChatMessage("Hello")
   │
   ▼
[AEUDPNetworkManager]
   │
   ├─ 添加 type: "chat"
   │
   ▼
[AEUDPSocketClient]
   │
   ├─ 生成 request_id: "req_1712345678_1"
   ├─ 添加 timestamp
   ├─ 保存 completion 到 pendingRequests[request_id]
   ├─ 启动超时定时器
   │
   ▼
[Network.framework]
   │
   └─ NWConnection.send(data) ─────► [服务器]
                                        │
   ┌────────────────────────────────────┘
   │
   ▼
[Network.framework]
   │
   └─ NWConnection.receiveMessage()
       │
       ▼
[AEUDPSocketClient]
   │
   ├─ 解析 JSON
   ├─ 检查 request_id
   ├─ 从 pendingRequests 中查找 completion
   ├─ 调用 completion(response, nil)
   ├─ 从 pendingRequests 中移除
   │
   ▼
[业务层]
   │
   └─ 处理响应
```

### 推送消息流程

```
[服务器]
   │
   └─ 推送消息（无 request_id）
       │
       ▼
[Network.framework]
   │
   └─ NWConnection.receiveMessage()
       │
       ▼
[AEUDPSocketClient]
   │
   ├─ 解析 JSON
   ├─ 检查 request_id: 无
   ├─ 调用 pushMessageHandler(message)
   │
   ▼
[AEUDPNetworkManager]
   │
   ├─ 获取消息类型
   ├─ 查找注册的回调
   ├─ 调用所有匹配的回调
   │
   ▼
[业务层]
   │
   └─ 处理推送消息
```

## 🔐 线程安全设计

### 1. 共享状态保护

```swift
// 待处理请求字典
private var pendingRequests: [String: Completion] = [:]
private let pendingRequestsLock = NSLock()

// 使用
pendingRequestsLock.lock()
pendingRequests[requestId] = completion
pendingRequestsLock.unlock()
```

### 2. 原子计数器

```swift
private class AtomicCounter {
    private var value: Int = 0
    private let lock = NSLock()
    
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
```

### 3. 队列隔离

```swift
private let receiveQueue = DispatchQueue(label: "com.aenetwork.udp.receive")
private let sendQueue = DispatchQueue(label: "com.aenetwork.udp.send")
```

## ⏱ 超时机制

```swift
private func setupTimeout(for requestId: String) {
    receiveQueue.asyncAfter(deadline: .now() + config.timeout) { [weak self] in
        guard let self = self else { return }
        
        // 从待处理字典中移除
        self.pendingRequestsLock.lock()
        let completion = self.pendingRequests.removeValue(forKey: requestId)
        self.pendingRequestsLock.unlock()
        
        // 如果还存在（未被响应），则超时
        if let completion = completion {
            let error = NSError(domain: "AEUDPSocketClient", code: -3,
                               userInfo: [NSLocalizedDescriptionKey: "请求超时"])
            completion(nil, error)
        }
    }
}
```

## 🎯 设计原则

### 1. 关注点分离
- **AEUDPSocketClient**：负责传输层逻辑
- **AEUDPNetworkManager**：负责业务层 API
- **业务层**：只关心业务逻辑

### 2. 单一职责
- 每个类只负责一个职责
- Client 负责 UDP 通信
- Manager 负责 API 封装

### 3. 依赖倒置
- 业务层依赖抽象（Manager API）
- 不直接依赖 Client

### 4. 开闭原则
- 对扩展开放（可以添加新的消息类型）
- 对修改封闭（不需要修改核心逻辑）

## 🔄 状态管理

### 连接状态

```
[未连接] ──connect()──► [连接中] ──成功──► [已连接]
                           │                    │
                           │                    │
                         失败                disconnect()
                           │                    │
                           ▼                    ▼
                        [未连接] ◄───────── [未连接]
```

### 请求状态

```
[发送] ──► [等待响应] ──收到响应──► [完成]
              │
              ├──超时──► [超时]
              │
              └──断开连接──► [取消]
```

## 📊 性能考虑

### 1. 内存管理
- 使用 `weak self` 避免循环引用
- 及时清理 `pendingRequests`
- 断开连接时清理所有状态

### 2. 并发性能
- 使用 NWConnection（系统优化）
- 队列隔离避免阻塞
- 锁的粒度最小化

### 3. 网络性能
- UDP 协议天然高性能
- 避免不必要的序列化
- 合理的超时设置

## 🛡️ 错误处理

### 错误类型

| 错误码 | 说明 | 处理方式 |
|-------|------|---------|
| -1 | 未连接到服务器 | 先调用 connect() |
| -2 | JSON 序列化失败 | 检查数据格式 |
| -3 | 请求超时 | 增加 timeout 或重试 |
| -999 | 连接已断开 | 重新连接 |

### 错误传播

```
[底层错误]
   │
   ▼
[AEUDPSocketClient]
   │
   ├─ 包装为 NSError
   │
   ▼
[AEUDPNetworkManager]
   │
   ├─ 传递给业务层
   │
   ▼
[业务层]
   │
   └─ 用户提示或重试
```

## 📈 扩展性

### 1. 添加新的消息类型

```swift
// 1. 在 AEUDPMessageType 中添加
public enum AEUDPMessageType: String, Codable {
    case myNewType = "my_new_type"
}

// 2. 在 Manager 中添加便捷方法
extension AEUDPNetworkManager {
    func sendMyNewType(data: [String: Any], completion: ...) {
        sendMessage(type: "my_new_type", data: data, completion: completion)
    }
}
```

### 2. 添加新的推送消息处理

```swift
// 注册新的推送消息回调
manager.registerPushMessageCallback(for: "my_push_type") { message in
    // 处理推送消息
}
```

## 🔗 相关文档

- [MESSAGE_MATCHING.md](MESSAGE_MATCHING.md) - 消息匹配机制详解
- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [README.md](README.md) - API 文档

---

**设计目标达成：**
- ✅ 持续监听状态
- ✅ 请求-响应自动匹配
- ✅ 推送消息独立处理
- ✅ 线程安全
- ✅ 易于使用
- ✅ 可扩展
