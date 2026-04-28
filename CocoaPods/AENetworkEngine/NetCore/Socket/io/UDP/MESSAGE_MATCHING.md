# UDP Socket 消息匹配机制说明

## 📌 核心设计

UDP Socket 客户端采用 **请求-响应匹配** 和 **推送消息处理** 两种模式，通过 `request_id` 实现自动匹配。

## 🔄 消息处理流程

```
┌─────────────────────────────────────────────────────────────┐
│                      客户端发送                               │
│                                                               │
│  1. 生成唯一 request_id                                       │
│  2. 添加到消息: { "type": "chat", "request_id": "req_..." }  │
│  3. 保存 completion 到字典: pendingRequests[request_id]      │
│  4. 发送消息                                                  │
│  5. 启动超时计时器                                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │       UDP 网络传输             │
        └───────────────────────────────┘
                        │
                        ▼
┌───────────────────────┴─────────────────────────────────────┐
│                   服务端处理                                  │
│                                                               │
│  1. 接收消息                                                  │
│  2. 处理业务逻辑                                              │
│  3. 返回响应（包含相同的 request_id）                         │
│     或推送消息（不包含 request_id）                           │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │       UDP 网络传输             │
        └───────────────────────────────┘
                        │
                        ▼
┌───────────────────────┴─────────────────────────────────────┐
│                客户端持续监听                                  │
│                                                               │
│  1. 收到消息                                                  │
│  2. 解析 JSON                                                │
│  3. 检查是否有 request_id                                     │
│                                                               │
│  ┌─── 有 request_id？                                       │
│  │                                                            │
│  ├─ YES → 响应消息                                           │
│  │   1. 从 pendingRequests 中查找对应的 completion          │
│  │   2. 调用 completion(response, nil)                      │
│  │   3. 从字典中移除                                          │
│  │                                                            │
│  └─ NO  → 推送消息                                           │
│      1. 调用 pushMessageHandler(message)                     │
│      2. 由上层业务处理                                         │
└─────────────────────────────────────────────────────────────┘
```

## 💡 两种消息模式

### 1. 请求-响应模式（Request-Response）

**特点：**
- 客户端发送请求，等待服务端响应
- 每个请求都有唯一的 `request_id`
- 响应自动匹配到对应的请求
- 支持超时处理

**示例：**

```swift
// 发送请求
manager.sendChatMessage(message: "你好") { response, error in
    // 自动匹配到对应的响应
    print("收到响应: \(response)")
}
```

**消息格式：**

请求：
```json
{
  "type": "chat",
  "message": "你好",
  "request_id": "req_1712345678_1",
  "timestamp": "2026-04-09T10:00:00Z"
}
```

响应：
```json
{
  "type": "chat_response",
  "message": "收到: 你好",
  "request_id": "req_1712345678_1",  // 匹配请求
  "status": "success",
  "timestamp": "2026-04-09T10:00:01Z"
}
```

### 2. 推送消息模式（Push Message）

**特点：**
- 服务器主动推送，客户端被动接收
- **没有 `request_id`**
- 通过 `pushMessageHandler` 回调处理
- 适合通知、确认等场景

**示例：**

```swift
// 注册推送消息回调
manager.registerPushMessageCallback(for: "notification") { message in
    print("收到通知: \(message)")
}

manager.registerPushMessageCallback(for: "confirmation") { message in
    print("收到确认: \(message)")
}

// 通用回调（所有推送消息）
manager.registerPushMessageCallback(for: "*") { message in
    print("收到推送: \(message["type"] ?? "unknown")")
}
```

**消息格式：**

```json
{
  "type": "notification",
  "message": "您有新消息",
  "timestamp": "2026-04-09T10:00:02Z"
  // 注意：没有 request_id
}
```

## 🔑 Request ID 生成规则

```swift
// 格式: req_{timestamp}_{counter}
// 示例: req_1712345678_1

private func generateRequestId() -> String {
    let counter = requestIdCounter.increment()  // 原子计数器
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)  // 毫秒时间戳
    return "req_\(timestamp)_\(counter)"
}
```

**特点：**
- 全局唯一
- 包含时间戳（便于调试）
- 线程安全（使用原子计数器）

## ⏱ 超时机制

每个请求都有超时机制，默认 5 秒：

```swift
// 配置超时时间
let config = AEUDPSocketConfig(
    serverHost: "localhost",
    serverPort: 9999,
    timeout: 5.0  // 5 秒超时
)
```

**超时处理流程：**

1. 发送请求时启动定时器
2. 超时后从 `pendingRequests` 中移除
3. 调用 completion 并传入超时错误

```swift
manager.sendChatMessage(message: "Hello") { response, error in
    if let error = error {
        // error.localizedDescription == "请求超时"
        print("请求超时")
    }
}
```

## 🧵 线程安全

**保护机制：**

1. **NSLock 保护共享状态**
   ```swift
   private let pendingRequestsLock = NSLock()
   ```

2. **原子计数器**
   ```swift
   private let requestIdCounter = AtomicCounter()
   ```

3. **队列隔离**
   ```swift
   private let receiveQueue = DispatchQueue(label: "com.aenetwork.udp.receive")
   private let sendQueue = DispatchQueue(label: "com.aenetwork.udp.send")
   ```

## 📡 持续监听机制

Socket 在连接成功后自动启动持续监听：

```swift
private func startContinuousListening() {
    isListening = true
    listenForNextMessage()
}

private func listenForNextMessage() {
    guard isListening, isConnected else { return }
    
    connection?.receiveMessage { [weak self] data, _, _, error in
        // 处理消息
        self?.handleReceivedData(data)
        
        // 继续监听下一条消息（递归）
        self?.listenForNextMessage()
    }
}
```

**特点：**
- 连接成功后自动启动
- 递归调用实现持续监听
- 断开连接后自动停止

## 🎯 使用场景

### 场景 1：纯请求-响应

```swift
// 发送请求并等待响应
manager.sendChatMessage(message: "Hello") { response, error in
    if let response = response {
        print("响应: \(response)")
    }
}
```

### 场景 2：纯推送消息

```swift
// 注册推送消息回调
manager.registerPushMessageCallback(for: "notification") { message in
    showNotification(message["message"] as? String ?? "")
}
```

### 场景 3：混合模式

```swift
// 既处理请求-响应，也处理推送消息
manager.connect { success, _ in
    guard success else { return }
    
    // 注册推送消息回调
    manager.registerPushMessageCallback(for: "*") { message in
        print("推送: \(message)")
    }
    
    // 发送请求并等待响应
    manager.sendChatMessage(message: "Hello") { response, _ in
        print("响应: \(response)")
    }
}
```

### 场景 4：并发请求

```swift
// 多个请求并发发送，自动匹配各自的响应
for i in 1...10 {
    manager.sendChatMessage(message: "消息 \(i)") { response, _ in
        // 每个响应会自动匹配到对应的请求
        print("消息 \(i) 的响应: \(response)")
    }
}
```

## 🔍 调试技巧

### 1. 启用日志

```swift
let config = AEUDPSocketConfig(
    serverHost: "localhost",
    serverPort: 9999,
    enableLog: true  // 启用详细日志
)
```

**日志输出示例：**
```
[AEUDPSocketClient] ✓ 已连接到服务器: localhost:9999
[AEUDPSocketClient] ✓ 开始持续监听消息
[AEUDPSocketClient] ✓ 已发送数据 [request_id: req_1712345678_1]
[AEUDPSocketClient] ✓ 收到消息: {...}
[AEUDPSocketClient] ✓ 匹配到请求 [request_id: req_1712345678_1]
```

### 2. 检查待处理请求

```swift
// 在断开连接前检查是否有未完成的请求
// 日志会显示所有被清理的请求
manager.disconnect()
```

### 3. 推送消息调试

```swift
// 注册通用回调查看所有推送消息
manager.registerPushMessageCallback(for: "*") { message in
    print("DEBUG 推送: \(message)")
}
```

## ⚠️ 注意事项

1. **服务端必须返回 request_id**
   - 响应消息必须包含与请求相同的 `request_id`
   - 否则无法匹配响应

2. **推送消息不能有 request_id**
   - 推送消息不应包含 `request_id`
   - 包含 `request_id` 会被当作响应消息处理

3. **超时时间设置**
   - 根据网络情况合理设置超时时间
   - 过短可能导致正常请求超时
   - 过长影响用户体验

4. **并发请求限制**
   - UDP 本身不保证可靠传输
   - 大量并发请求可能导致丢包
   - 建议控制并发数量

5. **断开连接处理**
   - 断开连接会清理所有待处理请求
   - 所有未完成的请求会收到"连接已断开"错误

## 📚 完整示例

查看 `AEUDPExamples.swift` 中的完整示例：

- `example1_basicRequestResponse()` - 基本请求-响应
- `example2_pushMessages()` - 推送消息处理
- `example3_asyncAwait()` - Async/Await 模式
- `example4_concurrentRequests()` - 并发请求
- `example5_timeoutHandling()` - 超时处理
- `example6_businessService()` - 业务层封装

## 🔗 相关文档

- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [README.md](README.md) - 完整 API 文档
- [AEUDPExamples.swift](AEUDPExamples.swift) - 示例代码

---

**核心优势：**
- ✅ 自动匹配请求和响应
- ✅ 支持服务器推送消息
- ✅ 线程安全
- ✅ 超时保护
- ✅ 持续监听
- ✅ 简单易用
