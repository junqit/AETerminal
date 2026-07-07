# UDP 消息接收机制说明

## 为什么 receiveMessage 需要每次调用？

### NWConnection 的设计

Apple 的 `NWConnection.receiveMessage` 方法设计为**一次性接收**：
- 每次调用只接收一条消息
- 接收完成后必须再次调用才能接收下一条
- 这不是 bug，而是有意的设计选择

### 设计原因

1. **流控制**：给开发者完全的控制权，可以决定何时接收下一条消息
2. **背压处理**：避免接收速度过快导致内存溢出
3. **错误处理**：每次接收都可以单独处理错误
4. **灵活性**：可以在接收之间执行其他逻辑

## 我们的解决方案

### 方案对比

#### ❌ 旧实现：递归调用
```swift
private func listenForNextMessage() {
    connection?.receiveMessage { [weak self] data, _, _, error in
        // 处理消息...
        
        // 递归调用继续监听
        self?.listenForNextMessage()
    }
}
```

**问题**：
- 长时间运行可能导致栈溢出
- 调用栈深度随消息数量增长
- 理论上有性能风险

#### ✅ 新实现：循环 + 信号量
```swift
private func receiveLoop() {
    while isListening && isConnected {
        let semaphore = DispatchSemaphore(value: 0)
        
        connection?.receiveMessage { data, _, _, error in
            // 处理消息...
            semaphore.signal()
        }
        
        semaphore.wait()  // 等待本次接收完成
    }
}
```

**优点**：
- ✅ 避免栈溢出
- ✅ 调用栈深度固定
- ✅ 更清晰的控制流
- ✅ 易于理解和维护

## 性能考虑

### 信号量的开销
- 信号量操作非常轻量
- 只用于同步，不涉及大量计算
- 对比递归调用，开销更小

### 队列使用
```swift
receiveQueue.async { [weak self] in
    self?.receiveLoop()
}
```
- 在专用接收队列上运行
- 不阻塞主线程
- 保证线程安全

## 总结

虽然 `receiveMessage` 必须每次调用，但我们通过：
1. **循环结构**替代递归
2. **信号量同步**确保顺序执行
3. **专用队列**保证线程安全

实现了高效、稳定的持续消息接收机制。

## 扩展阅读

如果需要更高级的功能，可以考虑：
- 使用 `receive(minimumIncompleteLength:maximumLength:completion:)` 流式接收
- 实现消息队列和批处理
- 添加流量限制和背压机制
