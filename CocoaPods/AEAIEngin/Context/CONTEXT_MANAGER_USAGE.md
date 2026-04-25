# AEAIContextManager Delegate 使用指南

## 概述

AEAIContextManager 现在支持状态变化的委托通知，当上下文列表发生变化时，会自动通知代理进行界面刷新。

## 核心特性

### 1. **代理协议**

`AEAIContextManagerDelegate` 提供三个回调方法：

```swift
public protocol AEAIContextManagerDelegate: AnyObject {
    
    /// Context 列表发生变化时调用（必须实现）
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext])
    
    /// 添加了新的 Context（可选实现）
    func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext)
    
    /// 删除了 Context（可选实现）
    func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext)
}
```

### 2. **自动触发时机**

- **创建新上下文**：`createContext(_:)` - 添加新上下文时触发
- **添加上下文**：`addContext(_:)` - 添加新上下文时触发（已存在则不触发 didAddContext）
- **删除上下文**：`removeContext(_:)` - 删除成功时触发
- **清空上下文**：`clearAllContexts()` - 清空后触发

## 使用示例

### 示例 1：在 NSView 中实现代理

```swift
import AppKit
import AEAIEngin

class AERightView: NSView {
    
    private var tableView: NSTableView!
    private var contexts: [AEAIContext] = []
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        registerAsDelegate()
        loadContexts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        registerAsDelegate()
        loadContexts()
    }
    
    /// 注册为代理
    private func registerAsDelegate() {
        AEAIContextManager.delegate = self
    }
    
    /// 加载上下文列表
    private func loadContexts() {
        contexts = AEAIContextManager.getAllContexts()
        tableView.reloadData()
    }
    
    private func setupUI() {
        // 设置 TableView...
    }
}

// MARK: - AEAIContextManagerDelegate

extension AERightView: AEAIContextManagerDelegate {
    
    /// Context 列表发生变化时调用（必须实现）
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
        // 在主线程刷新界面
        DispatchQueue.main.async { [weak self] in
            self?.contexts = contexts
            self?.tableView.reloadData()
        }
    }
    
    /// 添加了新的 Context（可选实现）
    func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext) {
        print("✅ 新增 Context: \(context.content)")
    }
    
    /// 删除了 Context（可选实现）
    func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext) {
        print("🗑️ 删除 Context: \(context.content)")
    }
}
```

### 示例 2：在 ViewController 中使用

```swift
import Cocoa
import AEAIEngin

class ViewController: NSViewController {
    
    @IBOutlet weak var rightView: AERightView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // rightView 已经注册为代理，会自动收到更新通知
        
        // 创建新上下文
        createNewContext()
    }
    
    private func createNewContext() {
        let config = AEContextConfig(content: "新的对话")
        
        // 创建上下文后，rightView 会自动收到通知并刷新
        AEAIContextManager.createContext(config)
    }
    
    private func removeContext(_ context: AEAIContext) {
        // 删除上下文后，rightView 会自动收到通知并刷新
        AEAIContextManager.removeContext(context)
    }
}
```

### 示例 3：只实现必需的回调

```swift
class SimpleContextView: NSView, AEAIContextManagerDelegate {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        AEAIContextManager.delegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        AEAIContextManager.delegate = self
    }
    
    /// 只实现主要的回调方法
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
        print("上下文数量: \(contexts.count)")
        // 刷新界面
    }
    
    // didAddContext 和 didRemoveContext 是可选的，不实现也可以
}
```

### 示例 4：完整的上下文列表显示

```swift
class ContextListView: NSView {
    
    private var tableView: NSTableView!
    private var contexts: [AEAIContext] = []
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTableView()
        AEAIContextManager.delegate = self
        reloadContexts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
        AEAIContextManager.delegate = self
        reloadContexts()
    }
    
    private func setupTableView() {
        // 创建并配置 TableView
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        // ... 其他配置
    }
    
    private func reloadContexts() {
        contexts = AEAIContextManager.getAllContexts()
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension ContextListView: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return contexts.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let context = contexts[row]
        
        let cell = NSTextField()
        cell.stringValue = context.content
        cell.isBordered = false
        cell.isEditable = false
        cell.backgroundColor = .clear
        
        return cell
    }
}

// MARK: - AEAIContextManagerDelegate

extension ContextListView: AEAIContextManagerDelegate {
    
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
        DispatchQueue.main.async { [weak self] in
            self?.contexts = contexts
            self?.tableView.reloadData()
        }
    }
}
```

## 回调方法说明

### 1. didUpdateContexts（必须实现）

```swift
func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext])
```

- **触发时机**：任何导致上下文列表变化的操作
- **参数**：当前所有的上下文列表
- **用途**：刷新界面显示
- **注意**：需要在主线程更新 UI

### 2. didAddContext（可选实现）

```swift
func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext)
```

- **触发时机**：成功添加新上下文时
- **参数**：新添加的上下文对象
- **用途**：记录日志、显示通知、特殊处理新增项
- **默认行为**：空实现（不做任何处理）

### 3. didRemoveContext（可选实现）

```swift
func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext)
```

- **触发时机**：成功删除上下文时
- **参数**：被删除的上下文对象
- **用途**：记录日志、显示通知、清理相关资源
- **默认行为**：空实现（不做任何处理）

## 注意事项

### 1. 弱引用

代理使用 `weak` 修饰，防止循环引用：

```swift
public static weak var delegate: AEAIContextManagerDelegate?
```

### 2. 主线程更新

UI 更新必须在主线程进行：

```swift
func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
    DispatchQueue.main.async { [weak self] in
        self?.tableView.reloadData()
    }
}
```

### 3. 类方法参数

代理方法的第一个参数是 `AEAIContextManager.Type`（类型），不是实例。

### 4. 代理设置

只能有一个代理（静态属性），后设置的会覆盖前面的：

```swift
AEAIContextManager.delegate = self  // 设置代理
```

### 5. 可选实现

`didAddContext` 和 `didRemoveContext` 通过协议扩展提供了默认实现，可以不实现这两个方法。

## 最佳实践

1. **在初始化时注册代理**
   ```swift
   override init(frame frameRect: NSRect) {
       super.init(frame: frameRect)
       AEAIContextManager.delegate = self
   }
   ```

2. **始终在主线程更新 UI**
   ```swift
   DispatchQueue.main.async { [weak self] in
       self?.tableView.reloadData()
   }
   ```

3. **使用 weak self 避免循环引用**
   ```swift
   DispatchQueue.main.async { [weak self] in
       // ...
   }
   ```

4. **只实现需要的回调方法**
   - 必须实现：`didUpdateContexts`
   - 可选实现：`didAddContext`、`didRemoveContext`

5. **在 deinit 时清理（可选）**
   ```swift
   deinit {
       if AEAIContextManager.delegate === self {
           AEAIContextManager.delegate = nil
       }
   }
   ```

## 完整流程示例

```swift
// 1. 创建界面类并实现代理
class ContextListView: NSView, AEAIContextManagerDelegate {
    
    private var contexts: [AEAIContext] = []
    
    // 2. 注册为代理
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        AEAIContextManager.delegate = self
        loadContexts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        AEAIContextManager.delegate = self
        loadContexts()
    }
    
    // 3. 加载初始数据
    private func loadContexts() {
        contexts = AEAIContextManager.getAllContexts()
    }
    
    // 4. 实现代理方法
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
        DispatchQueue.main.async { [weak self] in
            self?.contexts = contexts
            // 刷新界面
        }
    }
}

// 5. 在其他地方操作上下文
class OtherController {
    func createContext() {
        let config = AEContextConfig(content: "新对话")
        
        // 自动触发代理回调，ContextListView 会自动刷新
        AEAIContextManager.createContext(config)
    }
}
```

## 总结

- ✅ 设置代理：`AEAIContextManager.delegate = self`
- ✅ 实现必需的回调：`didUpdateContexts`
- ✅ 可选实现：`didAddContext`、`didRemoveContext`
- ✅ 主线程更新 UI：`DispatchQueue.main.async`
- ✅ 使用 weak self 避免循环引用
- ✅ 所有上下文操作（创建、添加、删除、清空）会自动触发回调
