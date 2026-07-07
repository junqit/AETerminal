# 🚀 AEModuleCenter 发布指南

## 📋 发布前检查清单

- [x] 代码已完成
- [x] 单元测试已通过
- [x] 文档已完善
- [x] podspec 已配置
- [ ] 代码已推送到 GitHub
- [ ] 已打版本 tag
- [ ] podspec 验证通过

---

## 📦 发布步骤

### Step 1: 初始化 Git 仓库（如果还未初始化）

```bash
cd /Users/tianjunqi/Project/Self/Agents/Client/CocoaPods/aemodulecenter

# 初始化 git（如果是新仓库）
git init

# 添加远程仓库
git remote add origin git@github.com:junqit/aemodulecenter.git
```

### Step 2: 提交代码

```bash
# 添加所有文件
git add .

# 提交
git commit -m "Initial commit: AEModuleCenter v1.0.0

- Thread-safe module management
- Automatic lifecycle event forwarding
- Weak reference support
- Complete unit tests
"

# 推送到 main 分支
git branch -M main
git push -u origin main
```

### Step 3: 打版本标签

```bash
# 创建并推送 tag
git tag -a 1.0.0 -m "Release version 1.0.0"
git push origin 1.0.0
```

### Step 4: 验证 Podspec

```bash
# 验证 podspec（本地验证）
pod spec lint AEModuleCenter.podspec --verbose

# 如果需要跳过某些警告
pod spec lint AEModuleCenter.podspec --allow-warnings
```

### Step 5: 发布到 CocoaPods（可选）

如果要发布到 CocoaPods Trunk：

```bash
# 注册 CocoaPods Trunk（首次使用）
pod trunk register your-email@example.com 'junqit' --description='My MacBook'

# 验证注册
pod trunk me

# 推送到 CocoaPods
pod trunk push AEModuleCenter.podspec

# 如果有警告需要跳过
pod trunk push AEModuleCenter.podspec --allow-warnings
```

---

## 📝 Podspec 配置说明

当前 podspec 配置：

```ruby
Pod::Spec.new do |s|
  s.name             = 'AEModuleCenter'
  s.version          = '1.0.0'
  s.summary          = 'A thread-safe module management center for iOS applications.'
  
  s.homepage         = 'https://github.com/junqit/aemodulecenter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'junqit' => 'junqit@github.com' }
  s.source           = { :git => 'git@github.com:junqit/aemodulecenter.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'
  
  s.source_files = 'AEModuleCenter/Classes/**/*.swift'
  s.frameworks = 'UIKit', 'Foundation'
end
```

**重要说明：**
- `source` 使用 SSH 格式：`git@github.com:junqit/aemodulecenter.git`
- 如果发布到 CocoaPods Trunk，建议改为 HTTPS：`https://github.com/junqit/aemodulecenter.git`

---

## 🔧 使用方式

### 方式 1: CocoaPods（私有仓库）

在 `Podfile` 中添加：

```ruby
# 如果使用 SSH
pod 'AEModuleCenter', :git => 'git@github.com:junqit/aemodulecenter.git', :tag => '1.0.0'

# 或使用 HTTPS
pod 'AEModuleCenter', :git => 'https://github.com/junqit/aemodulecenter.git', :tag => '1.0.0'
```

### 方式 2: CocoaPods（公开发布后）

```ruby
pod 'AEModuleCenter', '~> 1.0.0'
```

### 方式 3: Swift Package Manager

在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/junqit/aemodulecenter.git", from: "1.0.0")
]
```

---

## 🔄 版本更新流程

### 更新版本

1. 修改代码
2. 更新版本号：
   ```bash
   # 编辑 AEModuleCenter.podspec
   s.version = '1.1.0'
   ```
3. 提交并打 tag：
   ```bash
   git add .
   git commit -m "Release v1.1.0: New features"
   git tag -a 1.1.0 -m "Release version 1.1.0"
   git push origin main
   git push origin 1.1.0
   ```
4. 验证并发布：
   ```bash
   pod spec lint AEModuleCenter.podspec
   pod trunk push AEModuleCenter.podspec
   ```

---

## 🛠️ 故障排查

### 问题 1: git clone 失败

```
fatal: Remote branch 1.0.0 not found in upstream origin
```

**解决方案：** 确保已推送 tag 到远程仓库
```bash
git push origin 1.0.0
```

### 问题 2: SSH URL 警告

```
WARN | source: Git SSH URLs will NOT work for people behind firewalls
```

**解决方案：** 如果要公开发布，改用 HTTPS：
```ruby
s.source = { :git => 'https://github.com/junqit/aemodulecenter.git', :tag => s.version.to_s }
```

### 问题 3: URL 无法访问

```
NOTE | url: The URL is not reachable
```

**解决方案：** 确保仓库已在 GitHub 上创建并设置为公开（或团队可访问）

---

## 📊 版本号规范

使用 [语义化版本](https://semver.org/lang/zh-CN/)：

- **主版本号 (MAJOR)**: 不兼容的 API 修改
- **次版本号 (MINOR)**: 向下兼容的功能性新增
- **修订号 (PATCH)**: 向下兼容的问题修正

示例：
- `1.0.0` - 初始发布
- `1.0.1` - Bug 修复
- `1.1.0` - 新增功能
- `2.0.0` - 破坏性更新

---

## 📚 相关文档

- [CocoaPods 官方指南](https://guides.cocoapods.org/)
- [创建 Podspec](https://guides.cocoapods.org/making/specs-and-specs-repo.html)
- [语义化版本](https://semver.org/)
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

---

## ✅ 快速命令汇总

```bash
# 1. 推送代码
git add .
git commit -m "Initial commit"
git push -u origin main

# 2. 打标签
git tag -a 1.0.0 -m "Release v1.0.0"
git push origin 1.0.0

# 3. 验证
pod spec lint AEModuleCenter.podspec --allow-warnings

# 4. 发布（可选）
pod trunk push AEModuleCenter.podspec
```

---

祝发布顺利！🎉
