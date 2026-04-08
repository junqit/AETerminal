# 组合键管理器集成说明

## 概述

已成功集成组合键管理器 `AECombinationKeyManager`，实现了基于焦点状态的组合键事件自动分发机制。

## 架构

```
┌─────────────────────────────────────────┐
│         ViewController                   │
│  监听键盘事件 → 分发给管理器              │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   AECombinationKeyManager (单例)        │
│  - 注册/注销处理器                       │
│  - 根据焦点状态分发事件                  │
│  - 维护处理器列表（弱引用）              │
└──────────────┬──────────────────────────┘
               │
     ┌─────────┴─────────┬─────────┬──────┐
     ▼                   ▼         ▼      ▼
┌──────────┐     ┌──────────┐  ┌────┐  ┌────┐
│AELeftView│     │AERightView│ │Chat│  │Text│
│(目录列表)│     │(Context)  │ │View│  │View│
└──────────┘     └──────────┘  └────┘  └────┘
     │                │           │       │
     └────────────────┴───────────┴───────┘
           实现 AECombinationKeyHandler
```

## 已实现的视图

### 1. AELeftView - 目录列表

**支持的组合键：**
- `⌘L` - 刷新目录列表
- `⌃N` / `⌃↓` - 向下导航
- `⌃P` / `⌃↑` - 向上导航

**焦点状态：**
- TableView 是第一响应者时激活

### 2. AERightView - Context 列表

**支持的组合键：**
- `⌘N` - 创建新 Context
- `⌘R` - 刷新列表
- `⌃N` / `⌃↓` - 向下选择
- `⌃P` / `⌃↑` - 向上选择

**焦点状态：**
- TableView 是第一响应者时激活

### 3. AEChatView - 聊天视图

**支持的组合键：**
- `⌘C` - 复制聊天内容
- `⌘K` - 清空聊天记录

**焦点状态：**
- 视图本身是第一响应者时激活

### 4. AETextView - 文本输入

**行为：**
- 不拦截组合键，使用系统默认行为
- 保留 `⌘A`（全选）、`⌘C`（复制）、`⌘V`（粘贴）等编辑快捷键

**焦点状态：**
- 内部 textView 是第一响应者时激活

## 工作流程

### 1. 事件分发

```swift
用户按下组合键
    ↓
AECombinationKeyManager 内部监听器接收
    ↓
遍历已注册的处理器
    ↓
检查 canHandleCombinationKey（由实现者控制）
    ↓
调用 handleCombinationKey(event, modifiers, key)
    ↓
返回 true → 已处理，停止传递
返回 false → 继续检查下一个处理器
    ↓
所有处理器都返回 false
    ↓
调用 DefaultCombinationKeyHandler（如果已注册）
    ↓
返回 true → 已处理
返回 false → 事件继续传递
```

### 2. 焦点管理

```swift
用户点击/切换视图
    ↓
新视图: becomeFirstResponder()
    ↓
isFocused = true
    ↓
canHandleCombinationKey 返回 true
    ↓
管理器将事件路由到该视图
```

## 代码示例

### ViewController 集成

```swift
// 默认处理器类（实现相同的协议）
class DefaultCombinationKeyHandler: AECombinationKeyHandler {
    weak var viewController: ViewController?
    
    init(viewController: ViewController) {
        self.viewController = viewController
    }
    
    var combinationKeyHandlerID: String {
        return "DefaultCombinationKeyHandler"
    }
    
    var canHandleCombinationKey: Bool {
        return true // 默认处理器始终可以处理
    }
    
    func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        guard let vc = viewController else { return false }
        
        if modifiers.contains(.command) {
            vc.handleCommandKey(key: key, event: event)
            return true
        }
        // ... 其他处理
        
        return false
    }
}

// ViewController
private func setupCombinationKeyManager() {
    // 创建并注册默认处理器
    defaultKeyHandler = DefaultCombinationKeyHandler(viewController: self)
    AECombinationKeyManager.shared.registerDefaultHandler(defaultKeyHandler!)
    
    // 启动监听
    AECombinationKeyManager.shared.startMonitoring()
}

deinit {
    // 清理
    AECombinationKeyManager.shared.unregisterDefaultHandler()
    AECombinationKeyManager.shared.stopMonitoring()
}
```

### 视图实现

```swift
// 1. 注册
override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    AECombinationKeyManager.shared.register(self)
}

deinit {
    AECombinationKeyManager.shared.unregister(self)
}

// 2. 实现协议
extension MyView: AECombinationKeyHandler {
    
    var combinationKeyHandlerID: String {
        return "MyView"
    }
    
    var canHandleCombinationKey: Bool {
        return window?.firstResponder == someView || isFocused
    }
    
    func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        if modifiers.contains(.command) {
            switch key.uppercased() {
            case "N":
                // 处理 ⌘N
                return true
            default:
                break
            }
        }
        return false
    }
}

// 3. 追踪焦点
override func becomeFirstResponder() -> Bool {
    isFocused = true
    return super.becomeFirstResponder()
}

override func resignFirstResponder() -> Bool {
    isFocused = false
    return super.resignFirstResponder()
}
```

## 调试

### 启用调试日志

```swift
// 在 AppDelegate 或 ViewController 中
AECombinationKeyManager.shared.enableDebugLog = true
```

### 查询状态

```swift
// 所有已注册的处理器
let allIDs = AECombinationKeyManager.shared.getAllHandlerIDs()
print("所有处理器: \(allIDs)")
// 输出: ["AELeftView", "AERightView", "AEChatView", "AETextView"]

// 当前激活的处理器
let activeIDs = AECombinationKeyManager.shared.getActiveHandlerIDs()
print("活动处理器: \(activeIDs)")
// 输出: ["AERightView"] （假设 RightView 当前有焦点）
```

## 特性

### ✅ 内置键盘监听
- 管理器内部监听键盘事件（`NSEvent.addLocalMonitorForEvents`）
- ViewController 无需手动监听

### ✅ 焦点状态由业务决定
- `canHandleCombinationKey` 完全由实现者控制
- 管理器不做额外判断，只调用处理器

### ✅ 统一的注册机制
- 普通处理器和默认处理器都使用相同的协议
- 默认处理器也通过 `registerDefaultHandler` 注册

### ✅ 弱引用避免内存泄漏
- 处理器使用弱引用包装
- 自动清理已释放的处理器

### ✅ 优先级处理
- 按注册顺序处理
- 先注册的优先处理
- 所有处理器都不处理时才调用默认处理器

### ✅ 灵活的事件处理
- 返回 true 表示已处理，停止传递
- 返回 false 表示未处理，继续传递

### ✅ 系统快捷键保留
- AETextView 不拦截编辑快捷键
- 保持系统标准行为

## 已集成的文件

### CocoaPods/AEAIEngin/Keyboard/Combination/
- ✅ `AECombinationKeyHandler.swift` - 协议定义
- ✅ `AECombinationKeyManager.swift` - 管理器实现
- ✅ `COMBINATION_KEY_USAGE.md` - 详细使用文档

### AETerminal/Modules/Terminal/
- ✅ `ViewController.swift` - 集成管理器
- ✅ `AELeftView.swift` - 实现协议
- ✅ `AERightView.swift` - 实现协议
- ✅ `AEChatView.swift` - 实现协议

### CocoaPods/AEAIEngin/Keyboard/NSTextView/
- ✅ `AETextView.swift` - 实现协议

## 扩展指南

### 添加新的快捷键

```swift
func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
    if modifiers.contains(.command) {
        switch key.uppercased() {
        case "新快捷键":
            // 实现功能
            return true
        }
    }
    return false
}
```

### 添加新的处理器

```swift
// 1. 实现协议
extension MyNewView: AECombinationKeyHandler {
    // ...
}

// 2. 注册
override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    AECombinationKeyManager.shared.register(self)
}

// 3. 注销
deinit {
    AECombinationKeyManager.shared.unregister(self)
}
```

## 常见组合键

| 组合键 | 功能 | 视图 |
|--------|------|------|
| ⌘N | 创建新 Context | AERightView |
| ⌘R | 刷新列表 | AERightView |
| ⌘L | 刷新目录 | AELeftView |
| ⌘K | 清空聊天 | AEChatView |
| ⌘C | 复制内容 | AEChatView |
| ⌃N / ⌃↓ | 向下导航/选择 | AELeftView, AERightView |
| ⌃P / ⌃↑ | 向上导航/选择 | AELeftView, AERightView |
| ⌘A, ⌘C, ⌘V | 系统编辑快捷键 | AETextView（不拦截） |

## 注意事项

1. **及时注销** - 在 `deinit` 中调用 `unregister`
2. **检查焦点** - `canHandleCombinationKey` 必须准确反映焦点状态
3. **返回值明确** - 处理了返回 `true`，未处理返回 `false`
4. **不拦截系统快捷键** - 保留编辑类快捷键给系统处理
5. **弱引用** - 管理器使用弱引用，不会造成循环引用

## 构建状态

✅ 编译成功  
✅ 所有视图已集成  
✅ 调试功能可用

## 下一步

可以在各个视图中添加更多快捷键功能，例如：
- AELeftView: 添加目录操作快捷键
- AERightView: 添加 Context 管理快捷键
- AEChatView: 添加聊天操作快捷键

所有快捷键都会自动根据焦点状态正确分发，无需修改核心逻辑。
