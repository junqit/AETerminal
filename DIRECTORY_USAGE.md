# AEDirectory 目录浏览功能使用说明

## 功能概述

实现了一个目录浏览工具类和左侧目录视图，支持递归浏览文件系统的目录结构。

## 文件说明

### 1. AEDirectory.swift
位置: `AETerminal/Core/Utils/AEDirectory.swift`

提供以下静态方法：

#### 方法列表
- `homeDirectory() -> String` - 返回当前用户的主目录
- `subdirectories(atPath:) -> [String]` - 获取指定目录下的子目录名称（不包含文件和隐藏文件夹）
- `subdirectoriesFullPath(atPath:) -> [String]` - 获取子目录的完整路径
- `createDirectory(atPath:) -> Bool` - 创建文件夹（支持递归创建）
- `deleteDirectory(atPath:) -> Bool` - 删除文件夹
- `exists(atPath:) -> Bool` - 检查路径是否存在
- `isDirectory(atPath:) -> Bool` - 检查路径是否为目录

#### 使用示例
```swift
// 获取主目录
let home = AEDirectory.homeDirectory()

// 获取子目录
let subdirs = AEDirectory.subdirectories(atPath: "/Users/username")

// 创建目录
AEDirectory.createDirectory(atPath: "/path/to/new/folder")

// 删除目录
AEDirectory.deleteDirectory(atPath: "/path/to/folder")
```

### 2. AELeftView.swift
位置: `AETerminal/Modules/Terminal/AELeftView.swift`

左侧目录列表视图，支持显示和点击目录。

#### 主要功能
- 使用 NSTableView 显示目录列表
- 支持点击目录进行导航
- 通过 delegate 模式通知父控制器
- 每个目录前显示文件夹图标 📁

#### 使用方法
```swift
// 1. 在 xib/storyboard 中添加 AELeftView
@IBOutlet weak var leftView: AELeftView!

// 2. 设置代理
leftView.delegate = self

// 3. 加载目录
leftView.loadDirectories(atPath: "/path/to/directory")

// 4. 实现代理方法
extension ViewController: AELeftViewDelegate {
    func leftView(_ leftView: AELeftView, didSelectDirectory path: String) {
        // 处理目录选择
        leftView.loadDirectories(atPath: path)
    }
}
```

### 3. ViewController.swift 集成
位置: `AETerminal/Modules/Terminal/ViewController.swift`

已集成目录浏览功能：

1. 在 `viewDidLoad` 中调用 `setupLeftView()` 初始化
2. 加载用户主目录作为初始目录
3. 实现 `AELeftViewDelegate` 处理目录点击
4. 点击目录后自动加载该目录的子目录

## 使用流程

1. **初始化**
   - 应用启动时，自动加载用户主目录的子目录

2. **浏览目录**
   - 点击左侧列表中的任意目录
   - 自动加载并显示该目录的子目录
   - 可以无限递归浏览

3. **返回上级**
   - 目前需要手动实现返回功能
   - 可以添加导航栏显示当前路径
   - 可以添加返回按钮

## 下一步扩展建议

1. **添加面包屑导航**
   - 显示当前路径
   - 支持点击路径快速跳转

2. **添加返回按钮**
   - 返回上级目录
   - 支持前进/后退历史记录

3. **右键菜单**
   - 创建新文件夹
   - 删除文件夹
   - 重命名
   - 在 Finder 中显示

4. **搜索功能**
   - 在当前目录搜索
   - 递归搜索子目录

5. **显示文件**
   - 支持显示文件（目前只显示目录）
   - 支持文件选择和操作

## 注意事项

1. 目前只显示非隐藏的文件夹（不显示以 `.` 开头的文件夹）
2. 需要在 Interface Builder 中连接 `leftView` outlet
3. 确保 AEDirectory.swift 已添加到 Xcode 项目中
4. 访问某些系统目录可能需要权限

## 项目结构

```
AETerminal/
├── Core/
│   └── Utils/
│       └── AEDirectory.swift          # 目录工具类
└── Modules/
    └── Terminal/
        ├── ViewController.swift       # 主控制器
        └── AELeftView.swift          # 左侧目录视图
```
