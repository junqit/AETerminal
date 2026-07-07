# AEModuleCenter

一个线程安全的 iOS 模块管理中心，用于管理和分发 Application 生命周期事件。

## 特性

- ✅ **线程安全**：所有操作都是原子性的，使用 DispatchQueue + NSRecursiveLock 双重保护
- ✅ **自动内存管理**：使用 NSHashTable.weakObjects() 弱引用模块，避免循环引用
- ✅ **完整的生命周期支持**：支持所有主要的 UIApplication 生命周期事件
- ✅ **异常安全**：所有操作都有错误处理，不会因为单个模块异常而影响其他模块
- ✅ **易于使用**：简单的 API 设计，快速集成

## 安装

### CocoaPods

在你的 `Podfile` 中添加：

```ruby
# 使用 SSH
pod 'AEModuleCenter', :git => 'git@github.com:junqit/aemodulecenter.git', :tag => '1.0.0'

# 或使用 HTTPS
pod 'AEModuleCenter', :git => 'https://github.com/junqit/aemodulecenter.git', :tag => '1.0.0'
```

然后运行：

```bash
pod install
```

### Swift Package Manager

在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/junqit/aemodulecenter.git", from: "1.0.0")
]
```

## 使用方法

### 1. 创建模块

实现 `AEModuleProtocol` 协议：

```swift
import AEModuleCenter

class MyModule: NSObject, AEModuleProtocol {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("MyModule: Application did finish launching")
        // 初始化你的模块
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("MyModule: Application did become active")
        // 处理应用变为活跃状态
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("MyModule: Application did enter background")
        // 保存数据或清理资源
    }
}
```

### 2. 注册模块

在 `AppDelegate` 中注册模块：

```swift
import UIKit
import AEModuleCenter

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    // 保持模块的强引用（如果需要）
    private let myModule = MyModule()
    private let analyticsModule = AnalyticsModule()
    private let pushModule = PushNotificationModule()
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // 注册所有模块
        AEModuleCenter.shared.register(module: myModule)
        AEModuleCenter.shared.register(module: analyticsModule)
        AEModuleCenter.shared.register(module: pushModule)
        
        // 转发生命周期事件到所有模块
        AEModuleCenter.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        AEModuleCenter.shared.applicationDidBecomeActive(application)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        AEModuleCenter.shared.applicationDidEnterBackground(application)
    }
    
    // ... 其他生命周期方法
}
```

### 3. 移除模块

```swift
// 移除单个模块
AEModuleCenter.shared.unregister(module: myModule)

// 移除所有模块
AEModuleCenter.shared.unregisterAll()

// 查询模块数量
let count = AEModuleCenter.shared.moduleCount
print("已注册 \(count) 个模块")
```

## 支持的生命周期事件

### Application 生命周期
- ✅ `application(_:didFinishLaunchingWithOptions:)`
- ✅ `applicationWillEnterForeground(_:)`
- ✅ `applicationDidBecomeActive(_:)`
- ✅ `applicationWillResignActive(_:)`
- ✅ `applicationDidEnterBackground(_:)`
- ✅ `applicationWillTerminate(_:)`

### 内存警告
- ✅ `applicationDidReceiveMemoryWarning(_:)`

### 远程通知
- ✅ `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
- ✅ `application(_:didFailToRegisterForRemoteNotificationsWithError:)`
- ✅ `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`

### URL 处理
- ✅ `application(_:open:options:)`

### 用户活动
- ✅ `application(_:continue:restorationHandler:)`

## 线程安全机制

AEModuleCenter 使用了多重线程安全机制：

1. **串行队列 (Serial DispatchQueue)**
   - 所有注册/移除操作都在串行队列中执行
   - 保证操作的原子性

2. **递归锁 (NSRecursiveLock)**
   - 保护关键数据结构的访问
   - 支持同一线程的重入

3. **快照模式 (Snapshot Pattern)**
   - 在转发事件前先创建模块列表快照
   - 避免转发过程中模块列表被修改

4. **弱引用 (Weak References)**
   - 使用 `NSHashTable.weakObjects()` 存储模块
   - 模块被释放时自动清理

## 高级用法

### 示例：分析模块

```swift
class AnalyticsModule: NSObject, AEModuleProtocol {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 初始化分析 SDK
        Analytics.initialize(apiKey: "your-api-key")
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 记录应用激活事件
        Analytics.track(event: "app_active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // 记录应用后台事件
        Analytics.track(event: "app_background")
    }
}
```

### 示例：推送通知模块

```swift
class PushNotificationModule: NSObject, AEModuleProtocol {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 请求推送权限
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("Device Token: \(token)")
        // 上传 token 到服务器
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // 处理推送通知
        print("Received remote notification: \(userInfo)")
        completionHandler(.newData)
    }
}
```

## 注意事项

1. **模块生命周期**：如果使用弱引用存储模块，需要在 AppDelegate 或其他地方保持对模块的强引用
2. **异常处理**：单个模块的异常不会影响其他模块的执行
3. **执行顺序**：模块按注册顺序执行生命周期方法
4. **返回值处理**：
   - `didFinishLaunchingWithOptions`: 返回所有模块返回值的逻辑与 (AND)
   - `open URL`: 任一模块返回 true 则停止后续模块的处理
   - `continue userActivity`: 任一模块返回 true 则停止后续模块的处理

## 许可证

MIT License

## 作者

junqit - [GitHub](https://github.com/junqit)

## 链接

- 📦 [GitHub 仓库](https://github.com/junqit/aemodulecenter)
- 📖 [详细文档](./GUIDE.md)
- 🚀 [发布指南](./RELEASE.md)
- 💡 [示例代码](./Example)
- 🧪 [单元测试](./Tests)

## 贡献

欢迎提交 Issue 和 Pull Request！
