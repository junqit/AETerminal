# AI 响应解析测试示例

## 数据结构解析优先级

### 1. llm_responses 数组（最高优先级）

```json
{
  "status": "success",
  "llm_responses": [
    {
      "response": "这是第一个响应，会被显示"
    },
    {
      "response": "这是第二个响应，会被忽略"
    }
  ]
}
```

**解析结果**: ✅ 显示 "这是第一个响应，会被显示"

---

### 2. response 字段类型测试

#### 2.1 String 类型

```json
{
  "llm_responses": [
    {
      "response": "# Markdown 标题\n\n这是**粗体**文本"
    }
  ]
}
```

**解析结果**: ✅ 使用 Markdown 渲染

#### 2.2 Dictionary 类型（递归解析）

```json
{
  "llm_responses": [
    {
      "response": {
        "content": "嵌套的内容",
        "metadata": "其他信息"
      }
    }
  ]
}
```

**解析结果**: ✅ 递归解析，找到 "content" 字段

#### 2.3 Array of Dictionary 类型

```json
{
  "llm_responses": [
    {
      "response": [
        {
          "text": "数组中的第一个元素"
        },
        {
          "text": "数组中的第二个元素（忽略）"
        }
      ]
    }
  ]
}
```

**解析结果**: ✅ 解析数组的第一个元素

#### 2.4 Array of String 类型

```json
{
  "llm_responses": [
    {
      "response": [
        "第一个字符串",
        "第二个字符串（忽略）"
      ]
    }
  ]
}
```

**解析结果**: ✅ 取第一个字符串

#### 2.5 其他类型

```json
{
  "llm_responses": [
    {
      "response": 12345
    }
  ]
}
```

**解析结果**: ✅ 转换为字符串 "12345"

---

### 3. 字段名优先级测试

```json
{
  "llm_responses": [
    {
      "text": "普通文本字段",
      "response": "优先级更高的字段",
      "content": "会被忽略"
    }
  ]
}
```

**解析结果**: ✅ 使用 "response" 字段（优先级最高）

**字段优先级顺序**:
1. `response` (默认 Markdown)
2. `markdown` (Markdown)
3. `content` (默认 Markdown)
4. `text` (普通文本)
5. `message` (普通文本)
6. `answer` (默认 Markdown)
7. `result` (默认 Markdown)

---

### 4. 兼容其他数据格式

#### 4.1 data 字段

```json
{
  "data": {
    "markdown": "## 标题\n\n内容"
  }
}
```

**解析结果**: ✅ 解析 data.markdown

#### 4.2 根级别字段

```json
{
  "content": "直接在根级别的内容"
}
```

**解析结果**: ✅ 解析根级别的 content

#### 4.3 纯字符串

```json
"直接返回的字符串"
```

**解析结果**: ✅ 直接使用

---

### 5. Markdown 检测

#### 5.1 明确的 Markdown 标记

```json
{
  "llm_responses": [
    {
      "response": "# 这是标题\n\n```python\nprint('hello')\n```"
    }
  ]
}
```

**检测到**: ✅ `#` 和 ` ``` ` 标记
**渲染方式**: Markdown

#### 5.2 无 Markdown 标记

```json
{
  "llm_responses": [
    {
      "text": "这是普通文本，没有任何 Markdown 标记"
    }
  ]
}
```

**检测到**: ❌ 无标记
**渲染方式**: 普通文本（根据字段名 "text" 的默认值）

---

### 6. 错误处理

#### 6.1 空响应

```json
{
  "llm_responses": [
    {
      "response": ""
    }
  ]
}
```

**显示**: ❌ "AI 响应为空"（错误消息）

#### 6.2 无法解析的格式

```json
{
  "unknown_field": "未知字段",
  "other_data": 123
}
```

**解析结果**: ⚠️ 格式化为 JSON 并以代码块显示

```json
{
  "other_data": 123,
  "unknown_field": "未知字段"
}
```

---

## 调试输出示例

运行时会输出完整的调试信息：

```
🔍 AI 响应原始数据: {...}
📦 响应是字典类型，键: ["llm_responses", "status"]
📊 完整数据结构：
llm_responses: [Array of Dictionary] (count: 1)
  response: String = 这是第一个响应，会被显示...
status: String = success...
✅ 找到 llm_responses 数组，共 1 项
📝 解析第一个响应: ["response"]
✅ 找到字段 'response' (String)
🤖 AEChatView.addAssistantMessage: 这是第一个响应，会被显示... (markdown: true)
📝 appendMessage - 当前文本长度: 0, 新消息类型: assistant, markdown: true
✅ appendMessage 完成 - 新文本长度: 234
📜 滚动到底部, 文本长度: 234
```

---

## 实际测试步骤

1. **准备测试数据**
   - 修改服务器返回不同格式的数据

2. **启动应用**
   ```bash
   cd /Users/tianjunqi/Project/Self/Agents/Client/AETerminal
   open AETerminal.xcworkspace
   ```

3. **发送测试问题**
   - 选择一个目录
   - 输入问题并发送
   - 观察控制台日志

4. **验证显示效果**
   - 检查 chatView 中的内容
   - 验证 Markdown 是否正确渲染
   - 检查颜色和格式

---

## 常见问题排查

### Q1: 响应没有显示

**检查日志**:
```
📊 完整数据结构：
  llm_responses: [Array of Dictionary] (count: 1)
    response: String = ...
```

- 确认 `llm_responses` 存在
- 确认第一个元素中有 `response` 字段

### Q2: 显示的是 JSON 格式而不是内容

**原因**: 未找到任何已知字段

**解决**: 
- 检查字段名是否在支持列表中
- 查看调试输出 `⚠️ 未找到标准字段`

### Q3: Markdown 没有渲染

**检查日志**:
```
🤖 AEChatView.addAssistantMessage: ... (markdown: false)
```

- 如果 `markdown: false`，说明被判定为普通文本
- 检查 `text` 字段是否误用（text 默认为普通文本）
- 应该使用 `response` 或 `content` 字段

---

## 扩展支持

如果需要支持新的字段名，修改 `parseResponseContent` 方法中的 `fieldNames` 数组：

```swift
let fieldNames = [
    ("response", true),
    ("markdown", true),
    ("content", true),
    ("text", false),
    ("message", false),
    ("answer", true),
    ("result", true),
    // 添加新的字段名
    ("new_field_name", true),  // true = 默认 Markdown
]
```
