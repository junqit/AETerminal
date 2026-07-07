# UDP Socket 类名重命名说明

所有 UDP Socket 相关的类已添加 `AE` 前缀，以符合 AENetworkEngine 项目的命名规范。

## 重命名列表

### 配置类（UDPSocketConfig.swift）

| 旧名称 | 新名称 |
|--------|--------|
| `UDPSocketConfig` | `AEUDPSocketConfig` |
| `UDPMessageType` | `AEUDPMessageType` |
| `UDPMessageStatus` | `AEUDPMessageStatus` |
| `UDPMessage` (协议) | `AEUDPMessage` |
| `UDPRequest` | `AEUDPRequest` |
| `UDPResponse` | `AEUDPResponse` |

### 核心类（UDPSocketClient.swift）

| 旧名称 | 新名称 |
|--------|--------|
| `UDPSocketClient` | `AEUDPSocketClient` |

### 管理器类（UDPNetworkManager.swift）

| 旧名称 | 新名称 |
|--------|--------|
| `UDPNetworkManager` | `AEUDPNetworkManager` |

### 模块类（UDPSocket.swift）

| 旧名称 | 新名称 |
|--------|--------|
| `UDPSocketVersion` | `AEUDPSocketVersion` |
| `UDPSocketModule` | `AEUDPSocketModule` |

### 示例类（Examples.swift）

| 旧名称 | 新名称 |
|--------|--------|
| `UDPSocketExamples` | `AEUDPSocketExamples` |
| `ChatService` | `AEChatService` |

## 迁移指南

如果您的代码使用了旧的类名，请按以下方式更新：

### 基本使用

**旧代码：**
```swift
let config = UDPSocketConfig(serverHost: "localhost", serverPort: 9999)
let manager = UDPNetworkManager.shared
manager.configure(config: config)
```

**新代码：**
```swift
let config = AEUDPSocketConfig(serverHost: "localhost", serverPort: 9999)
let manager = AEUDPNetworkManager.shared
manager.configure(config: config)
```

### 直接使用客户端

**旧代码：**
```swift
let client = UDPSocketClient(config: config)
```

**新代码：**
```swift
let client = AEUDPSocketClient(config: config)
```

### 使用示例类

**旧代码：**
```swift
UDPSocketExamples.example1_basicUsage()
```

**新代码：**
```swift
AEUDPSocketExamples.example1_basicUsage()
```

### 业务层封装

**旧代码：**
```swift
class ChatService {
    private let manager = UDPNetworkManager.shared
}
```

**新代码：**
```swift
class MyChatService {
    private let manager = AEUDPNetworkManager.shared
}
```

## 自动迁移

可以使用以下 sed 命令批量替换（在 macOS 上）：

```bash
# 进入项目目录
cd YourProject

# 备份
git add . && git commit -m "Before UDP rename"

# 批量替换
find . -name "*.swift" -type f -exec sed -i '' 's/UDPSocketConfig/AEUDPSocketConfig/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPSocketClient/AEUDPSocketClient/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPNetworkManager/AEUDPNetworkManager/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPMessageType/AEUDPMessageType/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPMessageStatus/AEUDPMessageStatus/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPMessage/AEUDPMessage/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPRequest/AEUDPRequest/g' {} +
find . -name "*.swift" -type f -exec sed -i '' 's/UDPResponse/AEUDPResponse/g' {} +

# 验证
git diff
```

## 影响范围

这次重命名影响以下文件：

### 源代码文件
- ✅ `UDPSocketConfig.swift` - 配置和消息模型
- ✅ `UDPSocketClient.swift` - UDP 客户端核心
- ✅ `UDPNetworkManager.swift` - 网络管理器
- ✅ `UDPSocket.swift` - 模块主文件
- ✅ `Examples.swift` - 示例代码

### 文档文件
- ✅ `README.md` - API 文档
- ✅ `QUICK_START.md` - 快速开始指南

## 兼容性说明

- **向后兼容性**：此次重命名**不保持向后兼容**
- **必须操作**：所有使用旧类名的代码都需要更新
- **建议**：在更新前创建 git 提交或备份

## 验证

重命名完成后，请验证：

1. **编译通过**：确保项目可以成功编译
   ```bash
   xcodebuild clean build -scheme YourScheme
   ```

2. **测试通过**：运行所有相关测试
   ```bash
   xcodebuild test -scheme YourScheme
   ```

3. **功能正常**：测试 UDP 连接和消息发送
   ```swift
   Task {
       let config = AEUDPSocketConfig(serverHost: "localhost", serverPort: 9999)
       let manager = AEUDPNetworkManager.shared
       manager.configure(config: config)
       try await manager.connect()
       let isAlive = try await manager.pingServer()
       print("服务器状态: \(isAlive)")
   }
   ```

## 支持

如有问题，请参考：
- [README.md](README.md) - 完整 API 文档
- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [Examples.swift](Examples.swift) - 示例代码

## 更新日期

- 重命名日期：2026-04-09
- 版本：1.0.0

---

**注意**：此次重命名是为了保持 AENetworkEngine 库的命名一致性，所有公共 API 都使用 `AE` 前缀。
