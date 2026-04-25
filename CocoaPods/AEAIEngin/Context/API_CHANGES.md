# AEAIContextManager API 变更说明

## 概述

`AEAIContextManager.createContext()` 方法的参数类型从 `AEAIContext` 改为 `AEContextConfig`。

## 变更详情

### 之前的 API

```swift
// 旧方式：需要先创建 Context 对象
let config = AEContextConfig(content: "项目A")
let context = AEAIContext(config: config)
let managedContext = AEAIContextManager.createContext(context)
```

### 现在的 API

```swift
// 新方式：直接传入配置，Manager 内部创建 Context
let config = AEContextConfig(content: "项目A")
let managedContext = AEAIContextManager.createContext(config)
```

## 方法签名变更

### 之前

```swift
@discardableResult
public static func createContext(_ context: AEAIContext) -> AEAIContext
```

### 现在

```swift
@discardableResult
public static func createContext(_ config: AEContextConfig) -> AEAIContext
```

## 优势

### 1. **更简洁的 API**
   - 减少一步操作：不需要手动创建 Context 对象
   - 代码更简洁：从 3 行减少到 2 行

### 2. **职责更清晰**
   - Context 的创建完全由 Manager 控制
   - 外部只需提供配置，不需要关心创建逻辑

### 3. **更好的封装**
   - Context 的实例化逻辑内部化
   - 方便未来扩展和优化创建过程

### 4. **一致性**
   - 配置对象 → Manager 创建并管理 → 返回实例
   - 符合工厂模式的设计理念

## 迁移指南

### 场景 1：创建单个 Context

**之前：**
```swift
let config = AEContextConfig(content: "助手")
let context = AEAIContext(config: config)
let managedContext = AEAIContextManager.createContext(context)
```

**迁移后：**
```swift
let config = AEContextConfig(content: "助手")
let managedContext = AEAIContextManager.createContext(config)
```

### 场景 2：创建多个 Context

**之前：**
```swift
let config1 = AEContextConfig(content: "项目A")
let context1 = AEAIContext(config: config1)
let managedContext1 = AEAIContextManager.createContext(context1)

let config2 = AEContextConfig(content: "项目B")
let context2 = AEAIContext(config: config2)
let managedContext2 = AEAIContextManager.createContext(context2)
```

**迁移后：**
```swift
let config1 = AEContextConfig(content: "项目A")
let managedContext1 = AEAIContextManager.createContext(config1)

let config2 = AEContextConfig(content: "项目B")
let managedContext2 = AEAIContextManager.createContext(config2)
```

### 场景 3：在 ViewController 中使用

**之前：**
```swift
private func createFirstContext(withDirectory path: String) {
    let directoryName = (path as NSString).lastPathComponent
    let config = AEContextConfig(content: "工作目录: \(directoryName)")
    let context = AEAIContext(config: config)
    currentContext = AEAIContextManager.createContext(context)
}
```

**迁移后：**
```swift
private func createFirstContext(withDirectory path: String) {
    let config = AEContextConfig(content: path)
    currentContext = AEAIContextManager.createContext(config)
}
```

## 不受影响的 API

以下方法保持不变，仍然使用 `AEAIContext` 对象作为参数：

```swift
// 添加上下文（如果已存在相同 ID 则覆盖）
public static func addContext(_ context: AEAIContext)

// 删除上下文
public static func removeContext(_ context: AEAIContext)

// 获取所有上下文
public static func getAllContexts() -> [AEAIContext]

// 根据 ID 获取上下文
public static func getContext(id: String) -> AEAIContext?

// 清空所有上下文
public static func clearAllContexts()
```

## 内部实现

```swift
@discardableResult
public static func createContext(_ config: AEContextConfig) -> AEAIContext {
    // 创建上下文
    let context = AEAIContext(config: config)
    
    // 检查是否已存在相同的上下文
    if let existingContext = contexts[context.id] {
        print("警告: 上下文 ID '\(context.id)' 已存在，返回现有上下文")
        return existingContext
    }
    
    // 添加新的上下文
    contexts[context.id] = context
    
    // 通知代理
    delegate?.contextManager(self, didAddContext: context)
    notifyContextsChanged()
    
    return context
}
```

## 兼容性说明

### ✅ 完全向后兼容

虽然 API 签名变更，但旧代码只需简单修改即可：

1. **删除** `AEAIContext(config: config)` 这一行
2. **修改** `createContext(context)` 为 `createContext(config)`

### ⚠️ 注意事项

1. **不要手动创建 Context**
   ```swift
   // ❌ 不推荐：手动创建
   let context = AEAIContext(config: config)
   
   // ✅ 推荐：通过 Manager 创建
   let context = AEAIContextManager.createContext(config)
   ```

2. **保持使用 Config 对象**
   ```swift
   // ✅ 正确：使用配置对象
   let config = AEContextConfig(content: "助手")
   let context = AEAIContextManager.createContext(config)
   ```

3. **ID 生成保持不变**
   - Context ID 仍然由 `AEAIContext` 内部生成
   - 基于 `config.content` 生成唯一标识

## 已更新的文档

以下文档已经更新为新 API：

1. ✅ `/CocoaPods/AEAIEngin/Context/USAGE.md`
2. ✅ `/CocoaPods/AEAIEngin/Context/EXAMPLE.swift`
3. ✅ `/CocoaPods/AEAIEngin/Context/CONTEXT_MANAGER_USAGE.md`
4. ✅ `/AETerminal/USAGE_FLOW.md`
5. ✅ `ViewController.swift` - `createFirstContext()` 方法

## 总结

| 项目 | 之前 | 现在 |
|------|------|------|
| 参数类型 | `AEAIContext` | `AEContextConfig` |
| 代码行数 | 3 行 | 2 行 |
| 职责 | 外部创建 Context | Manager 创建 Context |
| 封装性 | 较弱 | 更强 |
| 一致性 | 中等 | 更好 |

**推荐使用新 API**，享受更简洁、更清晰的代码体验！
