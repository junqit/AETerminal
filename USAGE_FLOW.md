# AETerminal 工作流程说明

## 概述

本文档说明 AETerminal 的完整工作流程，包括目录加载、Context 创建和问题提问。

## 完整流程

### 1. 应用启动

当应用启动时，在 `ViewController.viewDidLoad()` 中：

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    // 设置 AETextView 的 delegate
    inputTextView.delegate = self
    
    // 设置左侧视图
    setupLeftView()
    
    // 监听键盘事件
    setupKeyboardMonitor()
}
```

### 2. 左侧目录视图加载

`setupLeftView()` 方法加载用户的主目录：

```swift
private func setupLeftView() {
    leftView.delegate = self
    
    // 加载用户主目录
    let homePath = AEDirectory.homeDirectory()
    leftView.loadDirectories(atPath: homePath)
}
```

### 3. 用户确认目录选择

用户点击"确认选择"按钮后，`AELeftView` 通过 delegate 回调：

```swift
// AELeftView.swift
@objc private func confirmButtonClicked() {
    // 通过 delegate 返回当前选中的目录路径
    // 如果有选中项，返回选中项的路径；否则返回根目录
    let pathToConfirm = selectedItem?.fullPath ?? rootPath
    delegate?.leftView(self, didConfirmDirectory: pathToConfirm)
    
    print("确认选择目录: \(pathToConfirm)")
}
```

### 4. 创建第一个 AI Context

`ViewController` 接收到 `didConfirmDirectory` 回调后，创建第一个 Context：

```swift
// ViewController.swift
func leftView(_ leftView: AELeftView, didConfirmDirectory path: String) {
    print("✅ 确认选择目录: \(path)")
    
    // 检查是否为目录
    guard AEDirectory.isDirectory(atPath: path) else {
        print("❌ 不是有效的目录: \(path)")
        return
    }
    
    // 创建第一个 AI Context（如果还没有）
    if currentContext == nil {
        createFirstContext(withDirectory: path)
    }
}

private func createFirstContext(withDirectory path: String) {
    // 创建配置
    let config = AEContextConfig(content: path)
    
    // 通过 Manager 创建并管理 Context
    currentContext = AEAIContextManager.createContext(config)
    
    print("✅ 创建第一个 Context: \(currentContext?.content ?? "")")
    print("   Context ID: \(currentContext?.id ?? "")")
}
```

### 5. 用户输入问题

用户在 `AETextView` 中输入文本，按下回车键后：

```swift
// AETextViewDelegate
func aeTextView(_ textView: AETextView, didInputText text: String) {
    print("✅ 提交内容: \(text)")
    handleSubmittedText(text)
}

private func handleSubmittedText(_ text: String) {
    // 添加到历史记录
    historyManager.addCommand(text)
    
    // 处理输入的文本
    handleInputText(text)
}
```

### 6. 通过 Context 发送 AI 问题

`handleInputText()` 将用户输入包装成 `AEAIQuestion`，通过当前 Context 发送：

```swift
private func handleInputText(_ text: String) {
    // 检查是否有当前的 Context
    guard let context = currentContext else {
        print("⚠️ 没有活动的 Context，请先加载目录")
        return
    }
    
    // 创建 AI 问题
    let question = AEAIQuestion.text(text)
    
    print("📤 发送问题到 Context [\(context.id)]")
    print("   问题内容: \(text)")
    
    // 通过 Context 发送问题
    context.sendQuestion(question) { [weak self] result in
        switch result {
        case .success(let response):
            print("✅ AI 响应成功")
            self?.handleAIResponse(response)
        case .failure(let error):
            print("❌ AI 响应失败: \(error.localizedDescription)")
            self?.handleAIError(error)
        }
    }
}
```

### 7. 处理 AI 响应

AI 响应通过回调返回：

```swift
private func handleAIResponse(_ response: AnyObject) {
    // TODO: 在这里处理 AI 的响应
    // 例如：显示在聊天界面、更新UI等
    print("AI 响应内容: \(response)")
}

private func handleAIError(_ error: Error) {
    // TODO: 在这里处理错误
    // 例如：显示错误提示等
    print("错误: \(error.localizedDescription)")
}
```

## 类图关系

```
┌─────────────────┐
│ ViewController  │
├─────────────────┤
│ - leftView      │───delegates to──┐
│ - rightView     │                 │
│ - inputTextView │                 │
│ - currentContext│                 │
└─────────────────┘                 │
        │                           │
        │ creates                   │
        ▼                           │
┌─────────────────┐                 │
│  AEAIContext    │                 │
├─────────────────┤                 │
│ - id            │                 │
│ - content       │                 │
│ - messageManager│                 │
│ + sendQuestion()│                 │
└─────────────────┘                 │
        │                           │
        │ uses                      │
        ▼                           │
┌─────────────────┐                 │
│ AEAIQuestion    │                 │
├─────────────────┤                 │
│ - content       │                 │
│ - type          │                 │
│ - parameters    │                 │
└─────────────────┘                 │
                                    │
                                    ▼
                            ┌─────────────────┐
                            │   AELeftView    │
                            ├─────────────────┤
                            │ - rootPath      │
                            │ - currentPath   │
                            │ - displayItems  │
                            │ + loadDirectories()│
                            └─────────────────┘
                                    │
                                    │ notifies
                                    ▼
                            ┌─────────────────┐
                            │AELeftViewDelegate│
                            ├─────────────────┤
                            │+ didLoadDirectory│
                            │+ didConfirmDir   │
                            └─────────────────┘
```

## 数据流向

```
1. 启动应用
   └─> ViewController.viewDidLoad()
       └─> setupLeftView()
           └─> leftView.loadDirectories(homePath)
               └─> 显示目录列表

2. 用户确认目录选择
   └─> 用户点击"确认选择"按钮
       └─> AELeftView.confirmButtonClicked()
           └─> delegate?.leftView(self, didConfirmDirectory: path)
               └─> ViewController.didConfirmDirectory()
                   └─> createFirstContext(withDirectory:)
                       └─> AEAIContextManager.createContext()
                           └─> currentContext = context

3. 用户输入文本
   └─> AETextView (用户按回车)
       └─> delegate?.aeTextView(self, didInputText: text)
           └─> ViewController.handleSubmittedText()
               └─> handleInputText(text)
                   └─> currentContext.sendQuestion(question)

4. AI 响应
   └─> AEAIContext.sendQuestion()
       └─> completion callback
           └─> handleAIResponse() or handleAIError()
```

## 关键点说明

### 1. Context 创建时机

- **时机**：用户点击"确认选择"按钮后
- **触发**：通过 `didConfirmDirectory` delegate 回调
- **内容**：使用确认的目录路径创建 Context
- **优势**：用户主动确认，避免自动创建不必要的 Context

### 2. 第一个 Context 的锚点作用

- 所有用户输入的问题都通过 `currentContext` 发送
- 确保只有在 Context 存在时才能发送问题
- 如果 `currentContext` 为 `nil`，会给出警告

### 3. Context 管理

- 通过 `AEAIContextManager` 统一管理
- `currentContext` 指向当前活动的 Context
- 支持创建多个 Context（右侧列表显示）

### 4. 问题发送流程

```swift
用户输入 → AEAIQuestion.text(content)
         → currentContext.sendQuestion(question)
         → AEAIService (内部处理)
         → 回调返回结果
```

## 最佳实践

1. **用户主动确认创建 Context**
   - 在用户点击"确认选择"后再创建 Context
   - 避免自动创建不必要的 Context

2. **检查 Context 状态**
   - 发送问题前检查 `currentContext` 是否存在
   - 提供友好的错误提示

3. **使用数据包装类**
   - 使用 `AEAIQuestion` 包装用户输入
   - 使用 `AEContextConfig` 配置 Context

4. **统一管理**
   - 所有 Context 通过 `AEAIContextManager` 管理
   - 便于追踪和调试

## 调试日志示例

```
确认选择目录: /Users/username
✅ 确认选择目录: /Users/username
✅ 创建第一个 Context: 工作目录: username
   Context ID: context-username

📤 发送问题到 Context [context-username]
   问题内容: 如何实现登录功能？

✅ AI 响应成功
AI 响应内容: ...
```

## 注意事项

1. **用户主动触发**
   - Context 创建必须等待用户点击"确认选择"
   - 通过 delegate 回调确保流程正确

2. **Context 生命周期**
   - `currentContext` 在 ViewController 的整个生命周期内保持
   - 如果需要切换 Context，更新 `currentContext` 即可

3. **错误处理**
   - 检查 Context 是否存在
   - 处理 sendQuestion 的失败情况
   - 提供用户友好的错误提示

4. **历史记录管理**
   - 用户输入会添加到 `CommandHistoryManager`
   - 支持上下键浏览历史记录
