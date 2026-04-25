# AENetworkSocket 数据发送格式变更说明

## 变更概述

AENetworkSocket 在接收 AENetReq 后的数据发送格式已从 HTTP 协议格式变更为 Map（字典）格式。

## 变更对比

### 修改前：HTTP 协议格式

之前，AENetworkSocket 会将 AENetReq 组装成标准的 HTTP 协议格式发送：

```http
GET /api/v1/users HTTP/1.1
Host: 192.168.1.100:8080
Content-Type: application/json
Authorization: Bearer token123

{"key": "value"}
```

**发送的数据示例**：
```
GET /api/v1/users HTTP/1.1\r\n
Host: 192.168.1.100:8080\r\n
Content-Type: application/json\r\n
Authorization: Bearer token123\r\n
\r\n
{"key": "value"}
```

### 修改后：Map（字典）格式

现在，AENetworkSocket 会将 AENetReq 的所有参数组装成一个字典（Map），然后序列化为 JSON 发送：

```json
{
  "method": "GET",
  "path": "/api/v1/users",
  "parameters": {},
  "headers": {
    "Content-Type": "application/json",
    "Authorization": "Bearer token123"
  },
  "body": "eyJrZXkiOiAidmFsdWUifQ==",
  "timeout": 30
}
```

## 详细变更说明

### 1. 不再拼接 path 参数

**修改前**：
- 初始化时的 `path` 参数会与 `request.path` 拼接
- 例如：`AENetworkSocket(path: "/api")` + `request.path = "/users"` = `"/api/users"`

**修改后**：
- 直接使用 `request.path`，忽略初始化时的 `path` 参数
- 只在 map 中包含 `request.path` 的值

### 2. Body 数据处理

**修改前**：
- Body 数据直接追加到 HTTP 消息末尾
- 二进制格式保持不变

**修改后**：
- Body 数据转换为 base64 字符串
- 存储在 map 的 `"body"` 字段中

### 3. 数据格式

**修改前**：
- 发送的是符合 HTTP/1.1 协议的文本格式
- 包含请求行、请求头、空行、请求体

**修改后**：
- 发送的是 JSON 格式的字典
- 所有信息都作为键值对存储

## 代码示例对比

### 发送相同的请求

```swift
let socket = AENetworkSocket(
    ip: "192.168.1.100",
    port: 8080,
    path: "/api",  // 注意：这个参数在新版本中不再拼接到 path
    protocolType: .udp
)

let request = AENetReq(
    get: "/users",
    parameters: ["page": 1, "limit": 10],
    headers: ["Authorization": "Bearer token123"]
)

try socket.send(request)
```

### 修改前发送的数据

```
GET /api/users HTTP/1.1\r\n
Host: 192.168.1.100:8080\r\n
Authorization: Bearer token123\r\n
\r\n
```

### 修改后发送的数据

```json
{
  "method": "GET",
  "path": "/users",
  "parameters": {
    "page": 1,
    "limit": 10
  },
  "headers": {
    "Authorization": "Bearer token123"
  },
  "timeout": 30
}
```

## Map 格式字段说明

| 字段名 | 类型 | 说明 | 必填 |
|--------|------|------|------|
| method | String | HTTP 方法（GET/POST/PUT/DELETE等） | ✅ |
| path | String | 请求路径，直接取自 request.path | ✅ |
| parameters | [String: Any] | 请求参数字典 | ❌ |
| headers | [String: String] | 请求头字典 | ❌ |
| body | String | 请求体，base64 编码字符串 | ❌ |
| timeout | Double | 超时时间（秒） | ✅ |

## 优势

### 新格式的优势

1. **结构化数据**：易于解析和处理
2. **类型安全**：字段类型明确，便于服务端验证
3. **易于扩展**：可以方便地添加新字段
4. **跨语言支持**：JSON 格式被广泛支持
5. **调试友好**：可读性更好，便于日志记录和调试

### 适用场景

- ✅ UDP Socket 通信
- ✅ 自定义协议通信
- ✅ 微服务间通信
- ✅ 需要结构化数据传输的场景

## 迁移指南

如果你的代码依赖旧版本的 HTTP 格式发送，需要注意以下几点：

### 服务端需要修改

服务端需要从解析 HTTP 协议改为解析 JSON 格式：

**修改前（解析 HTTP 格式）**：
```python
# 解析 HTTP 请求行
request_line = data.split(b'\r\n')[0]
method, path, protocol = request_line.decode().split(' ')
```

**修改后（解析 JSON 格式）**：
```python
# 解析 JSON
import json
message = json.loads(data.decode())
method = message['method']
path = message['path']
parameters = message.get('parameters', {})
headers = message.get('headers', {})
```

### 路径处理

**修改前**：
```swift
// path 会自动拼接
let socket = AENetworkSocket(path: "/api")
let request = AENetReq(get: "/users")
// 实际发送的路径: /api/users
```

**修改后**：
```swift
// path 不会拼接，需要手动处理
let socket = AENetworkSocket(path: "")  // 这个参数不再影响实际路径
let request = AENetReq(get: "/api/users")  // 完整路径
// 实际发送的路径: /api/users
```

### Body 数据处理

**修改前**：
- Body 是原始二进制数据

**修改后**：
- Body 是 base64 编码的字符串
- 服务端需要进行 base64 解码

```python
import base64

# 解码 body
if 'body' in message:
    body_data = base64.b64decode(message['body'])
```

## 兼容性说明

- ⚠️ **破坏性变更**：此变更不向后兼容
- ⚠️ **服务端必须更新**：使用旧版本服务端将无法正确解析新格式数据
- ✅ **客户端 API 不变**：客户端代码调用方式保持不变，只是底层发送格式改变

## 示例代码

完整的使用示例请参考：
- `AENetworkEngine/Socket/AENetworkSocket+Example.swift`
- `AEAINetworkModule/Examples/AEAISocketUsageExample.swift`

## 问题反馈

如有问题，请联系开发团队。
