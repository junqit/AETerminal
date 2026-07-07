# Markdown 显示问题 - 快速排查

## 立即检查

运行应用后，在控制台搜索这些关键日志：

### 1. chatView 是否连接？
```
✅ chatView 已连接
```
如果看到 `❌ chatView 未连接`，请在 Storyboard 中连接 chatView outlet。

### 2. chatView 是否初始化？
```
🎨 AEChatView setupUI 开始, bounds: (x, y, width, height)
🎨 AEChatView setupUI 完成
   textStorage: ✅
```

### 3. 欢迎消息是否添加？
```
🎯 添加欢迎消息到 chatView
👋 AEChatView.addWelcomeMessage
⚙️ AEChatView.addSystemMessage: 欢迎使用 AI Terminal！开始你的对话吧。
📝 appendMessage 开始
✅ appendMessage 完成 - 新文本总长度: XX
```

### 4. Markdown 是否渲染？
```
🤖 AEChatView.addAssistantMessage: # 测试 Markdown 渲染... (markdown: true)
   🎨 开始 Markdown 渲染...
   🎨 Markdown 渲染完成，长度: XX
   ✅ 添加 Markdown 内容
```

## 如果日志正常但看不到内容

### 方案 1: 检查 chatView 位置和大小

在 ViewController.viewDidAppear 中添加（在 chatView.addWelcomeMessage() 之前）：

```swift
print("🔍 chatView 诊断:")
print("   frame: \(chatView.frame)")
print("   bounds: \(chatView.bounds)")
print("   isHidden: \(chatView.isHidden)")
print("   alphaValue: \(chatView.alphaValue)")
print("   superview: \(chatView.superview != nil ? "✅" : "❌")")
```

**如果 frame 为零或很小**:
- chatView 的 Auto Layout 约束有问题
- 在 Storyboard 中检查约束

### 方案 2: 强制设置明显的背景色

临时修改 `AEChatView.setupUI`:

```swift
// 在 setupUI 末尾添加
scrollView.backgroundColor = .red      // 临时红色
textView.backgroundColor = .yellow     // 临时黄色
print("🎨 设置了测试背景色：scrollView=红色, textView=黄色")
```

运行应用，如果：
- **看到红色/黄色**: chatView 正常显示，问题是文本颜色
- **看不到任何颜色**: chatView 被遮挡或 frame 为零

### 方案 3: 测试简单文本

在 `AEChatView.addWelcomeMessage` 中简化为最简单的测试：

```swift
func addWelcomeMessage() {
    print("👋 添加超级简单的测试")
    
    // 最简单的文本
    DispatchQueue.main.async { [weak self] in
        guard let storage = self?.textView.textStorage else {
            print("❌ storage 为 nil")
            return
        }
        
        // 直接添加纯文本
        let text = NSAttributedString(string: "测试文本", attributes: [
            .font: NSFont.systemFont(ofSize: 30),
            .foregroundColor: NSColor.red
        ])
        
        storage.append(text)
        
        print("✅ 添加了文本，长度: \(storage.length)")
        print("   textView.string: \(self?.textView.string ?? "nil")")
    }
}
```

如果这个简单测试都看不到红色的"测试文本"，那问题不在 Markdown 渲染，而在基础的 textView 显示。

## 最可能的问题

根据经验，90% 的情况是以下之一：

1. **chatView frame 为零** - Auto Layout 约束问题
2. **chatView 被遮挡** - z-order 问题
3. **textView 未正确添加到 scrollView** - 初始化问题

## 快速修复尝试

在 `AEChatView.swift` 的 `setupUI` 方法末尾添加：

```swift
// 强制刷新布局
DispatchQueue.main.async { [weak self] in
    guard let self = self else { return }
    
    self.needsLayout = true
    self.layout()
    
    print("🔄 强制布局后:")
    print("   scrollView.frame: \(self.scrollView.frame)")
    print("   textView.frame: \(self.textView.frame)")
    
    // 如果 frame 还是零，手动设置
    if self.scrollView.frame.size.width == 0 {
        print("⚠️ scrollView frame 为零，手动设置")
        self.scrollView.frame = self.bounds
    }
}
```

## 联系我

请运行应用并复制控制台的完整输出，特别是：
1. 从 `✅ chatView 已连接` 开始的日志
2. 所有包含 `🎨`、`👋`、`📝`、`🎯` 的日志
3. chatView 的 frame 信息

这样我可以准确定位问题！
