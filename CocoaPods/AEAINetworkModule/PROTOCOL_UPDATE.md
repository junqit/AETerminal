# AEAINetworkProtocol 更新说明

## 概述

AEAINetworkProtocol 已更新，新增支持接收 AENetReq 数据并发送。

## 更新时间

2026年4月24日

## 主要变更

### 1. 新增方法

#### 发送 AENetReq（同步）

```swift
@discardableResult
func send(_ request: AENetReq) throws -> Bool
```

**说明**：
- 同步发送 AENetReq 请求
- 请求会自动组装为 map 格式
- 抛出异常时表示发送失败
- 返回 Bool 表示发送结果

#### 发送 AENetReq（异步）

```swift
func sendAsync(_ request: AENetReq, completion: ((Result<Bool, Error>) -> Void)?)
```

**说明**：
- 异步发送 AENetReq 请求
- 通过 Result 类型返回结果
- 回调在主线程执行

#### 连接管理方法

```swift
func connect(completion: ((Bool, Error?) -> Void)?)
func disconnect()
```

**说明**：
- 新增 connect 和 disconnect 方法到协议
- 支持手动管理连接

### 2. 方法签名变更

#### 发送字典数据

**修改前**：
```swift
func send(data: [String: Any]) -> AENetworkSendResult
func sendAsync(data: [String: Any], completion: ((AENetworkSendResult) -> Void)?)
```

**修改后**：
```swift
func send(data: [String: Any]) throws -> Bool
func sendAsync(data: [String: Any], completion: ((Result<Bool, Error>) -> Void)?)
```

**变更说明**：
- 返回值从 `AENetworkSendResult` 改为 `Bool` + throws
- 回调参数从 `AENetworkSendResult` 改为 `Result<Bool, Error>`
- 错误处理更标准化

## 完整协议定义

```swift
public protocol AEAINetworkProtocol: AEModuleProtocol {

    // MARK: - Send Methods - AENetReq

    /// 发送 AENetReq 请求（同步）
    @discardableResult
    func send(_ request: AENetReq) throws -> Bool

    /// 异步发送 AENetReq 请求
    func sendAsync(_ request: AENetReq, completion: ((Result<Bool, Error>) -> Void)?)

    // MARK: - Send Methods - Dictionary

    /// 发送字典数据（同步）
    @discardableResult
    func send(data: [String: Any]) throws -> Bool

    /// 异步发送字典数据
    func sendAsync(data: [String: Any], completion: ((Result<Bool, Error>) -> Void)?)

    // MARK: - Listener Management

    func addListener(_ listener: AENetworkMessageListener)
    func removeListener(_ listener: AENetworkMessageListener)
    func removeAllListeners()
    var listenerCount: Int { get }

    // MARK: - Connection Management

    func connect(completion: ((Bool, Error?) -> Void)?)
    func disconnect()
    var isConnected: Bool { get }
}
```

## 使用示例

### 1. 发送 AENetReq

```swift
// 创建请求
let request = AENetReq(
    post: "/api/query",
    parameters: ["query": "Hello"],
    headers: ["Content-Type": "application/json"]
)

// 同步发送
do {
    try networkModule.send(request)
    print("✅ 发送成功")
} catch {
    print("❌ 发送失败: \(error)")
}

// 异步发送
networkModule.sendAsync(request) { result in
    switch result {
    case .success:
        print("✅ 发送成功")
    case .failure(let error):
        print("❌ 发送失败: \(error)")
    }
}
```

### 2. 通过协议使用

```swift
class AIService {
    private let network: AEAINetworkProtocol
    
    init(network: AEAINetworkProtocol) {
        self.network = network
    }
    
    func sendQuery(_ query: String) {
        let request = AENetReq(
            post: "/api/query",
            parameters: ["query": query]
        )
        
        network.sendAsync(request) { result in
            // 处理结果
        }
    }
}

// 使用
let networkModule = AEAINetworkModule()
networkModule.configure(serverIP: "192.168.1.100", serverPort: 9999)

let service = AIService(network: networkModule)
service.sendQuery("Hello AI")
```

### 3. 依赖注入模式

```swift
// 定义依赖协议
protocol DataSyncService {
    func syncData(_ data: [String: Any])
}

// 实现服务
class DataSyncManager: DataSyncService {
    private let network: AEAINetworkProtocol
    
    init(network: AEAINetworkProtocol) {
        self.network = network
    }
    
    func syncData(_ data: [String: Any]) {
        let request = AENetReq(
            post: "/api/sync",
            parameters: data
        )
        
        try? network.send(request)
    }
}

// 注入使用
let networkModule = AEAINetworkModule()
let syncManager = DataSyncManager(network: networkModule)
```

## 优势

### 1. 类型安全
- 使用 AENetReq 强类型请求对象
- 编译时检查参数类型

### 2. 统一接口
- 协议定义统一的发送接口
- 支持多种数据类型（AENetReq、字典）

### 3. 易于测试
- 基于协议的设计便于 Mock
- 可以轻松创建测试替身

### 4. 解耦设计
- 依赖协议而非具体实现
- 提高代码可维护性

## Mock 测试示例

```swift
class MockNetworkModule: AEAINetworkProtocol {
    var sendCalled = false
    var lastSentRequest: AENetReq?
    
    func send(_ request: AENetReq) throws -> Bool {
        sendCalled = true
        lastSentRequest = request
        return true
    }
    
    func sendAsync(_ request: AENetReq, completion: ((Result<Bool, Error>) -> Void)?) {
        sendCalled = true
        lastSentRequest = request
        completion?(.success(true))
    }
    
    // ... 实现其他协议方法
}

// 测试
func testSendQuery() {
    let mockNetwork = MockNetworkModule()
    let service = AIService(network: mockNetwork)
    
    service.sendQuery("test")
    
    XCTAssertTrue(mockNetwork.sendCalled)
    XCTAssertNotNil(mockNetwork.lastSentRequest)
}
```

## 迁移指南

### Step 1: 更新方法调用

**修改前**：
```swift
let result = networkModule.send(data: ["key": "value"])
if case .success = result {
    print("成功")
}
```

**修改后**：
```swift
do {
    try networkModule.send(data: ["key": "value"])
    print("成功")
} catch {
    print("失败: \(error)")
}
```

### Step 2: 更新回调处理

**修改前**：
```swift
networkModule.sendAsync(data: data) { result in
    if case .success = result {
        print("成功")
    }
}
```

**修改后**：
```swift
networkModule.sendAsync(data: data) { result in
    switch result {
    case .success:
        print("成功")
    case .failure(let error):
        print("失败: \(error)")
    }
}
```

### Step 3: 添加 AENetReq 支持

```swift
// 新增：发送 AENetReq
let request = AENetReq(
    get: "/api/status",
    parameters: ["device_id": "123"]
)

try networkModule.send(request)
```

## 兼容性说明

⚠️ **破坏性变更**

- 方法签名已变更，不向后兼容
- 需要更新所有实现 AEAINetworkProtocol 的类
- 需要更新所有调用这些方法的代码

✅ **已实现**

AEAINetworkModule 已完全实现新协议。

## 完整示例代码

查看以下文件获取完整示例：
- `Examples/AEAINetworkProtocolUsageExample.swift`

## 协议方法对比表

| 功能 | 修改前 | 修改后 | 状态 |
|------|--------|--------|------|
| 发送 AENetReq（同步） | ❌ 不支持 | ✅ `send(_ request: AENetReq) throws` | 新增 |
| 发送 AENetReq（异步） | ❌ 不支持 | ✅ `sendAsync(_ request:completion:)` | 新增 |
| 发送字典（同步） | `send(data:) -> Result` | `send(data:) throws -> Bool` | 变更 |
| 发送字典（异步） | `sendAsync(data:) -> Result` | `sendAsync(data:) -> Result<Bool, Error>` | 变更 |
| 连接 | ❌ 不在协议中 | ✅ `connect(completion:)` | 新增 |
| 断开 | ❌ 不在协议中 | ✅ `disconnect()` | 新增 |
| 监听管理 | ✅ 支持 | ✅ 支持 | 不变 |
| 连接状态 | ✅ 支持 | ✅ 支持 | 不变 |

## 总结

协议更新后，AEAINetworkProtocol 现在：

1. ✅ 支持接收和发送 AENetReq
2. ✅ 提供统一的错误处理机制（throws + Result）
3. ✅ 包含完整的连接管理方法
4. ✅ 便于依赖注入和单元测试
5. ✅ 类型安全，编译时检查

---

**版本：v2.0.0**  
**更新日期：2026年4月24日**
