# AEAIMessageManager 使用指南

## 概述

AEAIMessageManager 管理单个上下文的消息历史，支持消息的添加、查询、导航和删除。

## 核心特性

### 1. **消息唯一性保证**

添加消息时会自动检查消息内容的唯一性：
- 如果存在相同内容的消息，会先删除旧消息
- 然后将新消息添加到消息列表的最后
- 这确保了消息列表中不会有重复内容的消息

## 使用示例

### 示例 1：基本添加消息

```swift
let manager = AEAIMessageManager(contextID: "context-1")

// 添加消息
let message1 = manager.addMessage("如何实现登录？")
print("消息数: \(manager.messageCount)") // 输出: 1

// 添加第二条消息
let message2 = manager.addMessage("如何实现注册？")
print("消息数: \(manager.messageCount)") // 输出: 2

// 获取所有消息
let allMessages = manager.getAllMessages()
print("共有 \(allMessages.count) 条消息")
```

### 示例 2：消息唯一性保证

```swift
let manager = AEAIMessageManager(contextID: "context-1")

// 添加第一条消息
manager.addMessage("如何实现登录？")
print("消息数: \(manager.messageCount)") // 输出: 1

// 添加第二条消息
manager.addMessage("如何实现注册？")
print("消息数: \(manager.messageCount)") // 输出: 2

// 再次添加第一条消息（内容相同）
manager.addMessage("如何实现登录？")
print("消息数: \(manager.messageCount)") // 输出: 2（仍然是2条）

// 获取所有消息
let messages = manager.getAllMessages()
print("消息1: \(messages[0].content)") // 输出: 如何实现注册？
print("消息2: \(messages[1].content)") // 输出: 如何实现登录？（最新的）

// 说明：
// 1. 旧的"如何实现登录？"被删除
// 2. 新的"如何实现登录？"被添加到最后
// 3. 消息列表中只保留一个"如何实现登录？"
```

### 示例 3：消息导航

```swift
let manager = AEAIMessageManager(contextID: "context-1")

// 添加多条消息
manager.addMessage("问题1")
manager.addMessage("问题2")
manager.addMessage("问题3")

// 获取当前消息（最新添加的）
if let current = manager.getCurrentMessage() {
    print("当前消息: \(current.content)") // 输出: 问题3
}

// 获取上一条消息
if let previous = manager.getPreviousMessage() {
    print("上一条: \(previous.content)") // 输出: 问题2
}

// 继续往上
if let previous = manager.getPreviousMessage() {
    print("再上一条: \(previous.content)") // 输出: 问题1
}

// 获取下一条消息
if let next = manager.getNextMessage() {
    print("下一条: \(next.content)") // 输出: 问题2
}

// 检查是否还有上一条/下一条
print("有上一条: \(manager.hasPrevious)") // 输出: true
print("有下一条: \(manager.hasNext)") // 输出: true
```

### 示例 4：重复消息的处理流程

```swift
let manager = AEAIMessageManager(contextID: "context-1")

// 添加消息A、B、C
manager.addMessage("消息A")
manager.addMessage("消息B")
manager.addMessage("消息C")

print("初始消息顺序:")
manager.getAllMessages().forEach { print($0.content) }
// 输出:
// 消息A
// 消息B
// 消息C

// 再次添加消息B（重复）
manager.addMessage("消息B")

print("\n添加重复消息B后:")
manager.getAllMessages().forEach { print($0.content) }
// 输出:
// 消息A
// 消息C
// 消息B (新的消息B移到最后)

// 说明：
// 1. 旧的消息B被从中间删除
// 2. 新的消息B被添加到最后
// 3. 保持消息唯一性的同时更新了顺序
```

### 示例 5：删除消息

```swift
let manager = AEAIMessageManager(contextID: "context-1")

// 添加消息
let message1 = manager.addMessage("消息1")
let message2 = manager.addMessage("消息2")

print("消息数: \(manager.messageCount)") // 输出: 2

// 删除指定消息
let success = manager.removeMessage(id: message1.id)
print("删除成功: \(success)") // 输出: true
print("消息数: \(manager.messageCount)") // 输出: 1

// 清空所有消息
manager.clearAllMessages()
print("消息数: \(manager.messageCount)") // 输出: 0
```

### 示例 6：索引导航控制

```swift
let manager = AEAIMessageManager(contextID: "context-1")

// 添加多条消息
manager.addMessage("消息1")
manager.addMessage("消息2")
manager.addMessage("消息3")

// 重置到第一条
manager.resetToFirst()
if let message = manager.getCurrentMessage() {
    print("第一条: \(message.content)") // 输出: 消息1
}

// 重置到最新一条
manager.resetToLatest()
if let message = manager.getCurrentMessage() {
    print("最新一条: \(message.content)") // 输出: 消息3
}

// 设置到指定索引
manager.setCurrentIndex(1)
if let message = manager.getCurrentMessage() {
    print("第2条: \(message.content)") // 输出: 消息2
}
```

## API 说明

### 添加消息

```swift
@discardableResult
public func addMessage(_ content: String) -> AEAIMessage
```

- 参数：`content` - 消息内容
- 返回：创建的消息对象
- 特性：自动去重，相同内容的旧消息会被删除，新消息添加到最后

### 获取消息

```swift
// 获取所有消息
public func getAllMessages() -> [AEAIMessage]

// 获取当前消息
public func getCurrentMessage() -> AEAIMessage?

// 获取上一条消息
public func getPreviousMessage() -> AEAIMessage?

// 获取下一条消息
public func getNextMessage() -> AEAIMessage?

// 根据 ID 获取消息
public func getMessage(id: String) -> AEAIMessage?

// 获取指定索引的消息
public func getMessage(at index: Int) -> AEAIMessage?
```

### 导航控制

```swift
// 重置到最新消息
public func resetToLatest()

// 重置到第一条消息
public func resetToFirst()

// 设置当前索引
@discardableResult
public func setCurrentIndex(_ index: Int) -> Bool
```

### 删除消息

```swift
// 清除所有消息
public func clearAllMessages()

// 删除指定消息
@discardableResult
public func removeMessage(id: String) -> Bool
```

### 属性

```swift
// 消息总数
public var messageCount: Int { get }

// 是否有上一条消息
public var hasPrevious: Bool { get }

// 是否有下一条消息
public var hasNext: Bool { get }

// 所属的上下文 ID
public let contextID: String
```

## 消息唯一性机制

### 判断标准

- **唯一性判断**：基于消息的 `content` 内容
- **比较方式**：字符串完全匹配（区分大小写）

### 处理流程

1. 调用 `addMessage(content)` 时
2. 检查是否已存在 `content` 相同的消息
3. 如果存在：
   - 删除旧消息
   - 调整当前索引（如果需要）
4. 创建新消息并添加到列表最后
5. 更新当前索引指向新消息

### 使用场景

这个机制特别适合以下场景：

1. **命令历史记录**：用户重复输入相同命令时，保持唯一性并更新顺序
2. **搜索历史**：重复搜索相同关键词时，将其提升到最新位置
3. **问答记录**：避免重复的问题，同时保持最近使用顺序

## 注意事项

1. **大小写敏感**：消息内容比较是区分大小写的
   ```swift
   manager.addMessage("Hello")
   manager.addMessage("hello") // 视为不同消息
   ```

2. **空格敏感**：前后空格会影响唯一性判断
   ```swift
   manager.addMessage("Hello")
   manager.addMessage("Hello ") // 视为不同消息（有尾随空格）
   ```

3. **索引自动调整**：删除旧消息时会自动调整当前索引，确保索引有效

4. **时间戳更新**：新消息的时间戳是新创建时的时间，不是旧消息的时间

## 最佳实践

1. **内容标准化**：添加消息前先 trim 掉前后空格
   ```swift
   let content = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
   manager.addMessage(content)
   ```

2. **检查空内容**：避免添加空消息
   ```swift
   let content = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
   if !content.isEmpty {
       manager.addMessage(content)
   }
   ```

3. **合理使用导航**：在 UI 中使用上下键浏览历史记录
   ```swift
   // 上箭头
   if let previous = manager.getPreviousMessage() {
       textView.text = previous.content
   }
   
   // 下箭头
   if let next = manager.getNextMessage() {
       textView.text = next.content
   }
   ```
