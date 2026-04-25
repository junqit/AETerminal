# UDP Socket 更新日志

## v2.0.0 - 2026-04-09

### 🎉 重大更新：请求-响应匹配机制

#### 核心改进

**1. 自动请求-响应匹配**
- ✅ 每个请求自动添加唯一的 `request_id`
- ✅ 响应自动匹配到对应的请求
- ✅ 支持并发请求，互不干扰

**2. 持续监听机制**
- ✅ Socket 连接成功后自动启动持续监听
- ✅ 递归接收消息，不会漏掉任何数据
- ✅ 断开连接时自动停止

**3. 推送消息支持**
- ✅ 区分响应消息和推送消息
- ✅ 推送消息通过 `pushMessageHandler` 回调
- ✅ 支持注册不同类型的推送消息回调

**4. 线程安全**
- ✅ NSLock 保护共享状态
- ✅ 原子计数器生成 request_id
- ✅ 队列隔离接收和发送

**5. 超时机制**
- ✅ 每个请求都有超时保护
- ✅ 超时后自动清理并回调错误
- ✅ 可配置超时时间

### 📦 新增文件

#### Swift 源文件
- `AEUDPSocketConfig.swift` - 配置类
- `AEUDPSocketClient.swift` - UDP 客户端核心（重写）
- `AEUDPNetworkManager.swift` - 网络管理器（重写）
- `AEUDPExamples.swift` - 示例代码（重写）

#### 文档文件
- `MESSAGE_MATCHING.md` - 消息匹配机制详解 ⭐ 新增
- `ARCHITECTURE.md` - 架构设计文档 ⭐ 新增
- `CHANGELOG.md` - 更新日志（本文件）⭐ 新增
- `MIGRATION.md` - 迁移指南（v1.0 -> v2.0）
- `QUICK_START.md` - 快速开始指南（更新）
- `README.md` - API 文档（更新）

### 🔄 API 变更

#### 新增 API

**AEUDPSocketClient:**
```swift
// 推送消息处理器
var pushMessageHandler: (([String: Any]) -> Void)?
```

**AEUDPNetworkManager:**
```swift
// 注册推送消息回调
func registerPushMessageCallback(for messageType: String, callback: @escaping ([String: Any]) -> Void)

// 取消注册
func unregisterPushMessageCallbacks(for messageType: String)

// 清除所有回调
func clearAllPushMessageCallbacks()
```

#### 废弃 API

以下 API 已废弃（v1.0）：
- ~~`enableAsyncMode()`~~ - 不再需要，自动持续监听
- ~~`disableAsyncMode()`~~ - 不再需要
- ~~`sendMessageAsync()`~~ - 使用 `send()` 代替
- ~~`startListening()`~~ - 连接成功后自动启动
- ~~`stopListening()`~~ - 断开连接时自动停止

### 🎯 使用示例

#### v2.0 新特性示例

**1. 自动请求-响应匹配**
```swift
// 发送请求（自动添加 request_id）
manager.sendChatMessage(message: "Hello") { response, error in
    // 自动匹配到对应的响应
    print("响应: \(response)")
}

// 并发请求，自动匹配各自的响应
for i in 1...10 {
    manager.sendChatMessage(message: "消息 \(i)") { response, _ in
        print("消息 \(i) 的响应: \(response)")
    }
}
```

**2. 推送消息处理**
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
    print("推送: \(message["type"] ?? "unknown")")
}
```

**3. 持续监听（自动）**
```swift
// 连接成功后自动启动持续监听
manager.connect { success, _ in
    guard success else { return }
    // Socket 已经在持续监听
    // 可以接收响应消息和推送消息
}
```

### 📋 消息格式变更

#### v2.0 消息格式

**请求消息（自动添加）：**
```json
{
  "type": "chat",
  "message": "Hello",
  "request_id": "req_1712345678_1",  // ⭐ 自动添加
  "timestamp": "2026-04-09T10:00:00Z"  // ⭐ 自动添加
}
```

**响应消息（必须包含 request_id）：**
```json
{
  "type": "chat_response",
  "message": "收到",
  "request_id": "req_1712345678_1",  // ⭐ 必须返回相同的 request_id
  "status": "success"
}
```

**推送消息（不能有 request_id）：**
```json
{
  "type": "notification",
  "message": "您有新消息",
  "timestamp": "2026-04-09T10:00:02Z"
  // ⭐ 注意：没有 request_id
}
```

### 🔧 服务端适配

服务端需要做以下调整：

**1. 返回 request_id**
```python
# Python 服务端示例
def handle_message(data, addr):
    # 获取 request_id
    request_id = data.get("request_id")
    
    # 处理业务逻辑
    response = {
        "type": "chat_response",
        "message": "收到",
        "status": "success",
        "request_id": request_id,  # ⭐ 必须返回
        "timestamp": datetime.now().isoformat()
    }
    
    return response
```

**2. 推送消息（不包含 request_id）**
```python
# 推送消息
def push_notification(message):
    notification = {
        "type": "notification",
        "message": message,
        "timestamp": datetime.now().isoformat()
        # ⭐ 不包含 request_id
    }
    
    return notification
```

### ⚠️ 破坏性变更

#### 1. 消息格式
- 所有请求自动添加 `request_id` 和 `timestamp`
- 服务端必须在响应中返回相同的 `request_id`

#### 2. API 变更
- 废弃 `enableAsyncMode()`、`disableAsyncMode()`
- 废弃 `sendMessageAsync()`
- 推送消息使用新的回调机制

#### 3. 行为变更
- 连接成功后自动启动持续监听
- 不再需要手动启动/停止监听

### 📚 迁移指南

#### 从 v1.0 迁移到 v2.0

**步骤 1：更新客户端代码**
```swift
// v1.0 (旧)
manager.enableAsyncMode()
manager.sendMessageAsync(type: "chat", data: ["message": "Hello"])

// v2.0 (新)
// 直接发送，自动持续监听
manager.sendChatMessage(message: "Hello") { response, error in
    // 自动匹配响应
}
```

**步骤 2：更新推送消息处理**
```swift
// v1.0 (旧)
manager.registerCallback(for: "notification") { response in
    // ...
}

// v2.0 (新)
manager.registerPushMessageCallback(for: "notification") { message in
    // ...
}
```

**步骤 3：更新服务端**
```python
# 确保响应包含 request_id
def handle_message(data, addr):
    request_id = data.get("request_id")  # 获取
    
    response = {
        "request_id": request_id,  # 返回
        # ...
    }
    
    return response
```

### 🐛 Bug 修复

- 修复了多个请求同时发送时响应混淆的问题
- 修复了推送消息无法正确处理的问题
- 修复了断开连接时待处理请求未清理的问题
- 修复了超时后仍可能收到响应的问题

### 🎨 性能优化

- 使用原子计数器提升 request_id 生成性能
- 优化锁的使用，减少锁竞争
- 改进队列隔离，提升并发性能

### 📖 文档改进

- 新增 `MESSAGE_MATCHING.md` - 详细说明消息匹配机制
- 新增 `ARCHITECTURE.md` - 架构设计文档
- 更新所有示例代码
- 改进 API 文档

### 🙏 致谢

感谢用户提出的宝贵建议，促成了这次重大更新。

---

## v1.0.0 - 2026-04-09

### 初始版本

- ✅ 基于 Network.framework 的 UDP Socket 客户端
- ✅ JSON 数据格式支持
- ✅ 同步和异步模式
- ✅ 回调和 async/await 支持
- ✅ 业务层 NetworkManager
- ✅ 完整的示例代码
- ✅ 详细的文档

---

## 版本规划

### v2.1.0（计划中）
- [ ] 消息加密支持
- [ ] 消息压缩支持
- [ ] 重连机制
- [ ] 消息队列（离线消息）

### v2.2.0（计划中）
- [ ] 消息持久化
- [ ] 消息去重
- [ ] 消息优先级

### v3.0.0（远期）
- [ ] TCP 支持
- [ ] WebSocket 支持
- [ ] 多协议统一 API
