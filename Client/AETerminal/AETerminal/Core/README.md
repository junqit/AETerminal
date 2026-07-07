# AETerminal 核心架构

## 目录结构

```
AETerminal/
├── Core/                           # 核心层
│   ├── Models/                     # 数据模型
│   │   └── CommandHistoryItem.swift    # 命令历史记录项模型
│   ├── Services/                   # 服务层
│   │   ├── CommandHistoryManager.swift # 命令历史管理器（单例）
│   │   └── CommandHistoryStorage.swift # 历史记录存储服务
│   └── Utils/                      # 工具类
│
├── Modules/                        # 模块层
│   └── Terminal/                   # 终端模块
│       └── ViewController.swift    # 终端视图控制器
│
├── AppDelegate.swift               # 应用委托
└── Resources/                      # 资源文件
```

## 架构说明

### 1. 数据模型层 (Models)

**CommandHistoryItem**: 命令历史记录的数据模型
- `id`: 唯一标识符
- `command`: 命令内容
- `timestamp`: 执行时间
- 实现 `Codable` 协议，支持持久化
- 实现 `Equatable` 协议，支持比较

### 2. 服务层 (Services)

#### CommandHistoryStorage
负责历史记录的持久化存储，提供两种实现：

**FileCommandHistoryStorage** (推荐)
- 使用 JSON 文件存储到 Application Support 目录
- 支持大量历史记录
- 性能更好

**UserDefaultsCommandHistoryStorage** (备选)
- 使用 UserDefaults 存储
- 适合少量数据
- 更简单的实现

#### CommandHistoryManager
命令历史记录的核心管理器：

**主要功能:**
- ✅ 添加命令到历史记录
- ✅ 导航历史记录（上/下）
- ✅ 搜索历史记录
- ✅ 限制历史记录数量（默认100条）
- ✅ 自动持久化
- ✅ 单例模式，全局访问

**使用示例:**
```swift
// 获取管理器实例
let manager = CommandHistoryManager.shared

// 添加命令
manager.addCommand("ls -la")

// 导航历史
if let prevCommand = manager.navigateUp() {
    print(prevCommand)
}

if let nextCommand = manager.navigateDown() {
    print(nextCommand)
}

// 搜索历史
let results = manager.search(keyword: "git")

// 清除历史
manager.clearHistory()
```

### 3. 视图层 (Modules)

**ViewController**: 终端界面控制器
- 集成 `CommandHistoryManager`
- 处理键盘输入（回车、上下键）
- 自动保存和恢复历史记录

## 设计原则

### 单一职责原则 (SRP)
- `CommandHistoryItem`: 只负责数据结构定义
- `CommandHistoryStorage`: 只负责数据持久化
- `CommandHistoryManager`: 只负责业务逻辑
- `ViewController`: 只负责 UI 交互

### 依赖倒置原则 (DIP)
- 使用 `CommandHistoryStorageProtocol` 协议
- 可以轻松切换存储实现
- 便于单元测试（可注入 Mock）

### 开闭原则 (OCP)
- 扩展存储方式无需修改现有代码
- 可以添加新的历史记录功能（如搜索、过滤）

## 数据流

```
用户输入 → ViewController → CommandHistoryManager → CommandHistoryStorage → 文件系统
                ↑                                                              ↓
                └──────────────────── 持久化恢复 ───────────────────────────────┘
```

## 持久化位置

历史记录文件保存在:
```
~/Library/Application Support/[Bundle ID]/command_history.json
```

## 特性

✅ **持久化**: 应用关闭后历史记录不丢失
✅ **去重**: 连续相同的命令不会重复添加
✅ **容量限制**: 自动限制历史记录数量
✅ **时间戳**: 记录每条命令的执行时间
✅ **搜索**: 支持关键词搜索历史记录
✅ **线程安全**: 管理器操作安全
✅ **错误处理**: 完善的异常处理机制

## 未来扩展

可以考虑添加以下功能：
- [ ] 历史记录导出/导入
- [ ] 按时间范围过滤
- [ ] 收藏常用命令
- [ ] 命令别名系统
- [ ] 历史记录统计分析
- [ ] iCloud 同步
