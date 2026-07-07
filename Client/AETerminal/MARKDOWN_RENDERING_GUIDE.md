# Markdown 渲染和 AI 响应显示功能

## 概述

AETerminal 现在支持在 chatView 中显示 Markdown 格式的 AI 响应和普通字符串。

## 功能特性

### 1. Markdown 渲染支持

`MarkdownRenderer` 类提供了以下 Markdown 功能：

#### 支持的语法

- **标题** (`# H1`, `## H2`, `### H3` 等)
  - 自动根据级别调整字体大小
  - 使用粗体显示

- **代码块** (`` ```language ... ``` ``)
  - 支持语言标签显示
  - 专用的等宽字体
  - 深色/浅色模式自适应背景色
  - 代码内容带缩进

- **列表**
  - 无序列表 (`-`, `*`, `+`)
  - 有序列表 (`1.`, `2.`, `3.` 等)

- **引用** (`> text`)
  - 带有特殊的缩进和颜色
  - 左侧有竖线装饰

- **段落**
  - 自动换行
  - 支持普通文本

#### 行内格式（TODO）

以下功能已预留接口，待后续实现：
- 粗体 (`**text**` 或 `__text__`)
- 斜体 (`*text*` 或 `_text_`)
- 行内代码 (`` `code` ``)
- 链接 (`[text](url)`)

### 2. AI 响应解析

`ViewController.handleAIResponse` 方法支持多种响应数据格式：

#### 支持的数据结构

```json
// 格式 1: llm_responses 数组（优先）
{
  "llm_responses": [
    {
      "response": "# Hello\n\nThis is **markdown**",
      // 或 "markdown": "...",
      // 或 "content": "...",
      // 或 "text": "...",
      // 或 "message": "...",
      // 或 "answer": "...",
      // 或 "result": "..."
    },
    {
      "response": "第二个响应（会被忽略）"
    }
  ]
}

// 格式 2: data.markdown
{
  "data": {
    "markdown": "# Hello\n\nThis is **markdown**"
  }
}

// 格式 3: data.text
{
  "data": {
    "text": "Plain text response"
  }
}

// 格式 4: data.content
{
  "data": {
    "content": "Content text"
  }
}

// 格式 5: data.message
{
  "data": {
    "message": "Message text"
  }
}

// 格式 6: 根级别字段
{
  "content": "Direct content",
  "text": "Direct text",
  "message": "Direct message"
}

// 格式 7: 纯字符串
"Simple string response"

// 格式 8: Data 类型
Data(utf8: "String from data")

// 格式 9: response 字段支持多种类型
{
  "llm_responses": [
    {
      "response": "字符串类型"
    }
  ]
}

{
  "llm_responses": [
    {
      "response": {
        "content": "嵌套字典"
      }
    }
  ]
}

{
  "llm_responses": [
    {
      "response": [
        {"text": "数组的第一个元素"}
      ]
    }
  ]
}

{
  "llm_responses": [
    {
      "response": ["字符串1", "字符串2"]  // 取第一个
    }
  ]
}
```

#### 解析优先级

1. **llm_responses 数组** - 优先查找，取第一个元素
2. **data 对象** - 如果没有 llm_responses
3. **根级别字段** - 如果没有 data

**字段名优先级**（按顺序尝试）：
1. `response` - 通用字段，默认为 Markdown
2. `markdown` - 明确的 Markdown 字段
3. `content` - 内容字段，默认为 Markdown
4. `text` - 普通文本
5. `message` - 消息字段
6. `answer` - 答案字段
7. `result` - 结果字段

#### response 字段类型支持

`response` 字段可以是任何类型：

- **String**: 直接使用
- **Dictionary**: 递归解析
- **Array of Dictionary**: 解析第一个元素
- **Array of String**: 取第一个字符串
- **其他类型**: 转换为字符串

#### 自动 Markdown 检测

对于字符串类型的响应，会自动检测是否包含 Markdown 标记：
- 代码块标记 (`` ``` ``)
- 标题标记 (`#`)
- 粗体标记 (`**`)

如果检测到这些标记，会自动使用 Markdown 渲染器。

### 3. 显示效果

#### 消息类型

每条消息都有类型标识和时间戳：

- 👤 **User** (蓝色) - 用户输入
- 🤖 **Assistant** (绿色) - AI 响应
- ⚙️ **System** (橙色) - 系统消息
- ❌ **Error** (红色) - 错误消息

#### 颜色主题

自动适配系统外观：

**深色模式：**
- 文本：白色
- 代码背景：深灰色 (rgb: 0.15, 0.15, 0.15)
- 代码文本：浅灰色 (rgb: 0.9, 0.9, 0.9)

**浅色模式：**
- 文本：黑色
- 代码背景：浅灰色 (rgb: 0.95, 0.95, 0.95)
- 代码文本：深灰色 (rgb: 0.2, 0.2, 0.2)

## 使用方法

### 在代码中使用

```swift
// 添加用户消息
chatView.addUserMessage("你好，AI")

// 添加 Markdown 格式的 AI 响应
let markdown = """
# 标题

这是一段**重要**的文本。

```swift
let code = "Hello, World!"
print(code)
\```

- 列表项 1
- 列表项 2
"""
chatView.addAssistantMessage(markdown, isMarkdown: true)

// 添加普通文本响应
chatView.addAssistantMessage("这是普通文本", isMarkdown: false)

// 添加系统消息
chatView.addSystemMessage("切换到新的 Context")

// 添加错误消息
chatView.addErrorMessage("网络连接失败")
```

### AI 响应处理流程

1. **发送问题**
   ```swift
   context.sendQuestion(question) { result in
       switch result {
       case .success(let response):
           handleAIResponse(response)
       case .failure(let error):
           handleAIError(error)
       }
   }
   ```

2. **自动解析和显示**
   - `handleAIResponse` 自动解析响应数据
   - 提取文本内容
   - 判断是否为 Markdown 格式
   - 调用 `chatView.addAssistantMessage` 显示

## 调试

### 控制台日志

响应处理时会输出详细的调试信息：

```
🔍 响应是字典类型，键: ["data", "status"]
✅ 找到 markdown 字段
🤖 AEChatView.addAssistantMessage: # Hello... (markdown: true)
📝 appendMessage - 当前文本长度: 123, 新消息类型: assistant, markdown: true
✅ appendMessage 完成 - 新文本长度: 456
📜 滚动到底部, 文本长度: 456
```

### 响应格式检查

如果响应没有正确显示，检查：

1. **响应数据格式**
   - 查看 `🔍 响应是字典类型` 日志
   - 确认键名是否匹配

2. **内容提取**
   - 查看 `✅ 找到 XXX 字段` 日志
   - 如果显示 `⚠️ 未找到标准字段`，需要调整解析逻辑

3. **Markdown 渲染**
   - 查看 `markdown: true/false` 标志
   - 检查是否包含 Markdown 标记

## 后续优化建议

### 1. 增强 Markdown 支持

- 实现行内格式（粗体、斜体、行内代码）
- 支持表格
- 支持图片
- 支持 HTML 标签

### 2. 代码高亮

集成语法高亮库，为不同语言提供颜色高亮：
```swift
// 可以考虑集成 Highlight.js 或 Pygments
```

### 3. 交互功能

- 点击链接跳转
- 代码块复制按钮
- 引用块展开/折叠
- 图片预览

### 4. 性能优化

- 大文本分批渲染
- 虚拟滚动
- 懒加载图片

### 5. 导出功能

- 导出为 Markdown 文件
- 导出为 HTML
- 导出为 PDF

## 示例

### 完整的对话示例

```
[14:30:15] 👤 User
什么是 Swift？

────────────────────────────────────────────────────────────
[14:30:16] 🤖 Assistant

# Swift 编程语言

Swift 是 Apple 开发的**现代化**编程语言。

## 主要特性

- 安全性高
- 性能优秀  
- 语法简洁

## 代码示例

```swift
let greeting = "Hello, World!"
print(greeting)
\```

> Swift 是 iOS、macOS 开发的首选语言。

────────────────────────────────────────────────────────────
```

## 注意事项

1. **线程安全**: 所有 UI 更新都在主线程执行
2. **内存管理**: 使用 `weak self` 避免循环引用
3. **错误处理**: 解析失败时会显示错误消息或格式化的 JSON
4. **性能**: 大量消息可能影响滚动性能，建议限制显示数量

## 相关文件

- `AEChatView.swift` - 聊天视图主类
- `MarkdownRenderer.swift` - Markdown 渲染器
- `ViewController.swift` - 响应处理逻辑
- `CHATVIEW_DEBUG_GUIDE.md` - 调试指南
