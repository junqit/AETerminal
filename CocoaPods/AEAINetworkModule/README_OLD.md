# AEAINetworkModule

AEAI 网络初始化模块，用于管理 UDP Socket 连接。

## 功能特性

- 🚀 自动化网络初始化：集成 AEModuleProtocol，在应用启动时自动初始化网络
- 🔌 UDP Socket 管理：基于 AENetworkEngine 的 UDP 实现
- 🔄 生命周期管理：通过 AEModuleCenter 管理网络连接的生命周期
- ⚙️ 灵活配置：支持自定义服务器地址、端口
- 🔒 线程安全：内部使用锁机制确保线程安全
- 📤 发送队列：消息按顺序一条条发送
- 📥 监听者模式：支持多个监听者注册和注销
- 🔄 JSON 自动反序列化：接收到的数据自动解析为字典

## 安装

在 Podfile 中添加：

```ruby
pod 'AEAINetworkModule', :path => '../CocoaPods/AEAINetworkModule'
```

然后运行：

```bash
pod install
```

## 使用方法

### 1. 导入模块

```swift
import AEModuleCenter
import AEAINetworkModule
```

### 2. 配置网络参数

在 AppDelegate 中创建实例并配置网络参数：

```swift
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 保持对网络模块的强引用
    private let networkModule = AEAINetworkModule()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置网络模块
        networkModule.configure(
            serverHost: "127.0.0.1",  // 服务器地址
            serverPort: 9999           // 服务器端口
        )
        
        // 注册模块到 AEModuleCenter
        AEModuleCenter.shared.register(module: networkModule)
        
        // 转发生命周期事件
        AEModuleCenter.shared.applicationDidFinishLaunching(notification)
    }
}
```

### 3. 注册监听者并发送消息

```swift
import AEAINetworkModule

// 1. 创建监听者
class MyMessageListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        print("收到消息: \(message)")
        
        let type = message["type"] as? String ?? "unknown"
        switch type {
        case "chat_response":
            if let msg = message["message"] as? String {
                print("AI 回复: \(msg)")
            }
        case "notification":
            print("收到推送通知")
        default:
            print("其他消息: \(type)")
        }
    }
}

// 2. 注册监听者
let listener = MyMessageListener()
networkModule.addListener(listener)

// 3. 发送消息（同步）
let data: [String: Any] = [
    "type": "chat",
    "message": "你好"
]

let result = networkModule.send(data: data)
switch result {
case .success:
    print("发送成功")
case .failure(let error):
    print("发送失败: \(error)")
}

// 4. 异步发送
networkModule.sendAsync(data: data) { result in
    // 处理结果
}

// 5. 移除监听者
networkModule.removeListener(listener)
```

## API 说明

### 发送接口

```swift
// 同步发送（等待发送完成再返回）
@discardableResult
func send(data: [String: Any]) -> AENetworkSendResult

// 异步发送（不阻塞）
func sendAsync(data: [String: Any], completion: ((AENetworkSendResult) -> Void)?)
```

### 监听者管理

```swift
// 注册监听者
func addListener(_ listener: AENetworkMessageListener)

// 移除监听者
func removeListener(_ listener: AENetworkMessageListener)

// 移除所有监听者
func removeAllListeners()

// 获取监听者数量
var listenerCount: Int { get }
```

### 监听者协议

```swift
public protocol AENetworkMessageListener: AnyObject {
    /// 接收到消息
    func didReceiveMessage(_ message: [String: Any])
}
```

## 工作原理

### 发送队列

- 消息在内部队列中按顺序发送
- 每条消息发送完成后才发送下一条
- 支持同步和异步两种发送方式

```
消息1 → 队列 → 发送 → 完成 → 消息2 → 发送 → 完成 → 消息3 ...
```

### 监听者模式

- 支持注册多个监听者
- 使用弱引用，监听者释放时自动移除
- 接收到消息后通知所有监听者
- 在主线程回调监听者

```
服务器消息 → JSON解析 → 通知监听者1
                      → 通知监听者2
                      → 通知监听者3
```

## 使用场景

### 场景 1: 聊天界面

```swift
class ChatViewController: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        if message["type"] as? String == "chat_response",
           let text = message["message"] as? String {
            // 更新 UI 显示 AI 回复
            self.displayMessage(text)
        }
    }
    
    func sendMessage(_ text: String) {
        let data = ["type": "chat", "message": text]
        networkModule.sendAsync(data: data)
    }
}
```

### 场景 2: 多个监听者

```swift
// 聊天监听者
class ChatListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        if message["type"] as? String == "chat_response" {
            // 处理聊天消息
        }
    }
}

// 通知监听者
class NotificationListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        if message["type"] as? String == "notification" {
            // 显示通知
        }
    }
}

// 分析监听者
class AnalyticsListener: AENetworkMessageListener {
    func didReceiveMessage(_ message: [String : Any]) {
        // 记录所有消息用于分析
        analytics.log(message)
    }
}

// 注册所有监听者
networkModule.addListener(chatListener)
networkModule.addListener(notificationListener)
networkModule.addListener(analyticsListener)
```

## 平台支持

- iOS 12.0+
- macOS 10.13+

## 依赖

- AEModuleCenter: 模块化生命周期管理
- AENetworkEngine: UDP Socket 网络引擎

## 注意事项

1. **配置顺序**：必须在注册模块之前调用 `configure()` 方法
2. **服务器地址**：确保配置正确的服务器地址和端口
3. **网络权限**：macOS 应用需要在 Signing & Capabilities 中添加 Network 权限
4. **后台连接**：iOS 应用在后台时连接可能会断开，需要在前台时重连
5. **日志和超时**：日志默认开启，超时时间固定为 5 秒

## License

MIT
