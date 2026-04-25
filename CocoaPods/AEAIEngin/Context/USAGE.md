# AEAIContext 使用指南

## 概述

AEAIContext 用于管理 AI 对话上下文，支持消息发送、历史记录管理等功能。

## 核心类

### 1. AEContextConfig - 上下文配置

用于配置 AI 上下文的初始化参数。

```swift
/// 初始化配置
let config = AEContextConfig(
    content: "项目开发助手",
    maxMessageCount: 100,  // 可选：最大消息数量
    metadata: ["version": "1.0"]  // 可选：元数据
)
```

**参数说明：**
- `content`: 上下文内容/描述
- `maxMessageCount`: （可选）最大消息数量限制
- `metadata`: （可选）自定义元数据

### 2. AEAIQuestion - 问题数据包装

用于包装用户的问题，支持不同类型的问题。

```swift
// 创建文本问题
let question1 = AEAIQuestion.text("如何实现登录功能？")

// 创建命令问题
let question2 = AEAIQuestion.command("/help")

// 创建搜索问题
let question3 = AEAIQuestion.search("React hooks")

// 完整初始化（带参数）
let question4 = AEAIQuestion(
    content: "生成代码",
    type: .command,
    parameters: ["language": "Swift", "framework": "UIKit"]
)
```

**问题类型：**
- `.text`: 纯文本问题（默认）
- `.command`: 命令类问题
- `.search`: 搜索类问题
- `.custom(String)`: 自定义类型

### 3. AEAIContext - AI 上下文

管理 AI 对话的核心类。

```swift
// 创建上下文
let config = AEContextConfig(content: "开发助手")
let context = AEAIContext(config: config)
```

### 4. AEAIContextManager - 上下文管理器（类方法）

统一管理多个上下文的工具类，所有方法都是类方法（static），无需实例化。

```swift
// 1. 创建上下文对象
let config = AEContextConfig(content: "项目助手")
let context = AEAIContext(config: config)

// 2. 通过 Manager 管理（自动检查重复）
let managedContext = AEAIContextManager.createContext(context)

// 3. 重复创建会返回现有上下文
let sameContext = AEAIContextManager.createContext(context)
// sameContext === managedContext

// 4. 添加上下文（覆盖已存在的）
AEAIContextManager.addContext(context)

// 5. 获取所有上下文
let allContexts = AEAIContextManager.getAllContexts()

// 6. 根据 ID 获取
if let found = AEAIContextManager.getContext(id: context.id) {
    print("找到上下文")
}

// 7. 删除上下文（使用上下文对象）
AEAIContextManager.removeContext(context)

// 8. 清空所有
AEAIContextManager.clearAllContexts()
```

**特点：**
- ✅ 所有方法都是类方法（static）
- ✅ 无需创建实例，直接使用 `AEAIContextManager.xxx()`
- ✅ 全局统一管理所有上下文
- ✅ **`createContext()` 接收 `AEContextConfig` 参数，内部自动创建 Context**
- ✅ **其他操作使用 `AEAIContext` 对象作为参数**
- ✅ **创建时自动检查是否已存在相同 ID 的上下文**

## 完整使用示例

### 示例 1：基本使用

```swift
import AEAIEngin

// 1. 创建配置
let config = AEContextConfig(content: "iOS 开发助手")

// 2. 创建上下文
let context = AEAIContext(config: config)

// 3. 发送问题
let question = AEAIQuestion.text("如何实现自定义 UITableViewCell？")
context.sendQuestion(question) { result in
    switch result {
    case .success(let response):
        print("AI 响应: \(response)")
    case .failure(let error):
        print("错误: \(error)")
    }
}
```

### 示例 2：使用 ContextManager（类方法）

```swift
// 1. 创建配置
let config1 = AEContextConfig(content: "项目A")

// 2. 通过 Manager 创建并管理（自动检查是否已存在）
let managedContext1 = AEAIContextManager.createContext(config1)

// 3. 创建另一个上下文
let config2 = AEContextConfig(
    content: "项目B",
    maxMessageCount: 50
)
let managedContext2 = AEAIContextManager.createContext(config2)

// 4. 重复创建相同 ID 的上下文会返回现有的
let sameContext = AEAIContextManager.createContext(config1) // 返回 managedContext1

// 5. 发送问题
let question = AEAIQuestion.command("/analyze code")
managedContext2.sendQuestion(question) { result in
    // 处理响应
}

// 6. 获取所有上下文
let allContexts = AEAIContextManager.getAllContexts()
print("共有 \(allContexts.count) 个上下文")

// 7. 根据 ID 获取上下文
if let context = AEAIContextManager.getContext(id: managedContext1.id) {
    print("找到上下文: \(context.content)")
}

// 8. 删除上下文（使用上下文对象）
AEAIContextManager.removeContext(managedContext1)

// 9. 清空所有上下文
AEAIContextManager.clearAllContexts()
```

### 示例 3：在 ViewController 中使用

```swift
import Cocoa
import AEAIEngin

class ViewController: NSViewController {
    private var context: AEAIContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 初始化上下文
        setupAIContext()
    }
    
    private func setupAIContext() {
        let config = AEContextConfig(content: "聊天助手")
        context = AEAIContext(config: config)
    }
    
    // 处理用户提交的文本
    func aeTextView(_ textView: AETextView, didInputText text: String) {
        // 创建问题
        let question = AEAIQuestion.text(text)
        
        // 发送问题
        context.sendQuestion(question) { [weak self] result in
            switch result {
            case .success(let response):
                // 处理 AI 响应
                self?.handleAIResponse(response)
            case .failure(let error):
                // 处理错误
                self?.handleError(error)
            }
        }
    }
    
    private func handleAIResponse(_ response: AnyObject) {
        // 显示 AI 响应
        print("AI 响应: \(response)")
    }
    
    private func handleError(_ error: Error) {
        print("错误: \(error.localizedDescription)")
    }
}
```

### 示例 4：消息历史管理

```swift
// 获取当前问题
if let current = context.getCurrentQuestion() {
    print("当前: \(current.content)")
}

// 获取上一条问题
if let previous = context.getPreviousQuestion() {
    print("上一条: \(previous.content)")
}

// 获取下一条问题
if let next = context.getNextQuestion() {
    print("下一条: \(next.content)")
}

// 获取所有问题
let allQuestions = context.getAllQuestions()
print("共有 \(allQuestions.count) 条消息")
```

## 迁移指南

### 从旧版本迁移

**旧版本：**
```swift
// 旧方式（直接传 String）
let context = AEAIContext(content: "助手", aiService: aiService)
context.sendQuestion("如何实现？") { result in
    // ...
}
```

**新版本：**
```swift
// 新方式（使用配置，Context 由 Manager 创建）
let config = AEContextConfig(content: "助手")
let context = AEAIContextManager.createContext(config)

let question = AEAIQuestion.text("如何实现？")
context.sendQuestion(question) { result in
    // ...
}
```

## 最佳实践

1. **使用配置对象**：通过 `AEContextConfig` 创建上下文，便于管理和扩展
2. **封装问题对象**：使用 `AEAIQuestion` 包装问题，支持类型和参数
3. **使用 ContextManager 类方法**：
   - 创建时传入 `AEContextConfig`，由 Manager 内部创建 Context
   - 通过 `AEAIContextManager.createContext(config)` 统一管理
   - 自动检查重复，避免创建相同 ID 的上下文
4. **问题类型选择**：根据业务场景选择合适的问题类型
5. **错误处理**：始终处理 `sendQuestion` 的错误情况

## 注意事项

- ✅ 必须使用 `AEContextConfig` 创建上下文
- ✅ 通过 `AEAIContextManager.createContext(config)` 创建，不要直接 `new AEAIContext()`
- ✅ 发送问题时必须使用 `AEAIQuestion` 对象
- ✅ 不要直接传递 String，使用数据包装类
- ✅ `AEAIService` 是内部实现，自动创建和管理
- ✅ 无需手动创建或传递 `AEAIService` 实例
