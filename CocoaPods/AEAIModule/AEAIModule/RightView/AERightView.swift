//
//  AERightView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit
import AEAIEngin
import AEFoundation

/// 缓存的上下文信息（轻量级，用于持久化）
public struct CachedContext: Codable {

    let id: String
    let dir: String

    public init(from context: AEAIContext) {
        self.id = context.id
        self.dir = context.dir
    }
}

/// 右侧视图委托协议
public protocol AERightViewDelegate: AnyObject {
    /// 当用户选中某个 Context 时调用
    /// - Parameters:
    ///   - rightView: 右侧视图
    ///   - context: 被选中的上下文
    func rightView(_ rightView: AERightView, didSelectContext context: AEAIContext)
}

/// 右侧视图焦点委托协议
public protocol AERightViewFocusDelegate: AnyObject {
    /// 当 rightView 获得焦点时调用
    func rightViewDidBecomeFocused(_ rightView: AERightView)
}

/// 右侧视图 - 显示 Context 列表
public class AERightView: NSView {

    // MARK: - UI Components

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    // MARK: - Delegate

    public weak var delegate: AERightViewDelegate?

    // MARK: - Data

    /// 当前显示的上下文列表
    private var contexts: [AEAIContext] = []

    /// 当前选中的 Context
    private var selectedContext: AEAIContext?

    /// 当前选中的索引
    private var selectedIndex: Int = -1

    /// 是否是焦点视图
    private var isFocused: Bool = false

    // MARK: - Cache

    /// 缓存引擎（用于存储 Context 列表）
    private let cacheEngine = AECacheEngine(identifier: "AERightView", storageType: .file)

    /// 缓存键
    private let cacheKey = "contexts"

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadContexts()
        registerAsDelegate()
        registerCombinationKeyHandler()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        loadContexts()
        registerAsDelegate()
        registerCombinationKeyHandler()
    }

    deinit {
        AECombinationKeyManager.shared.unregister(self)
    }

    /// 注册组合键处理器
    private func registerCombinationKeyHandler() {
        AECombinationKeyManager.shared.register(self)
    }

    // MARK: - Setup

    private func setupUI() {
        // 创建 ScrollView
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        // 创建 TableView
        tableView = NSTableView()
        if #available(macOS 11.0, *) {
            tableView.style = .plain
        }
        tableView.rowSizeStyle = .default
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.headerView = nil

        // 配置选择模式
        tableView.allowsEmptySelection = true
        tableView.allowsMultipleSelection = false

        // 添加列
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ContextColumn"))
        column.width = 200
        tableView.addTableColumn(column)

        // 设置代理和数据源
        tableView.delegate = self
        tableView.dataSource = self

        scrollView.documentView = tableView

        // 添加约束
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    /// 注册为 AEAIContextManager 的代理
    private func registerAsDelegate() {
        AEAIContextManager.delegate = self
    }

    // MARK: - Data Loading

    /// 加载上下文列表
    private func loadContexts() {
        // 1. 先尝试从缓存加载
        if let cachedContexts = loadContextsFromCache(), !cachedContexts.isEmpty {
            // 从缓存的信息创建 AEAIContext 对象（使用缓存的 id）
            contexts = cachedContexts.compactMap { cached in
                let config = AEContextConfig(content: cached.dir)
                let context = AEAIContext(config: config, customId: cached.id)
                return context
            }

            // 应用重启后使用缓存中的第一个 context 作为默认选中
            if selectedContext == nil, let firstContext = contexts.first {
                selectedContext = firstContext
                // 通知业务层默认选中的 context
                notifySelectedContextToDelegate(firstContext)
            }
        } else {
            // 2. 如果缓存为空，从 ContextManager 加载
            contexts = AEAIContextManager.getAllContexts()
        }

        sortContextsByLastUsed()

        // 验证 selectedIndex 是否还有效
        if selectedIndex >= contexts.count {
            selectedIndex = contexts.isEmpty ? -1 : contexts.count - 1
        }

        tableView.reloadData()
    }

    /// 通知业务层选中的 Context
    private func notifySelectedContextToDelegate(_ context: AEAIContext) {
        // 延迟通知，确保视图已经完全加载
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.rightView(self, didSelectContext: context)
        }
    }

    /// 从缓存加载 Context 列表
    private func loadContextsFromCache() -> [CachedContext]? {
        return cacheEngine.get(cacheKey, as: [CachedContext].self)
    }

    /// 保存 Context 列表到缓存
    private func saveContextsToCache() {
        let cachedContexts = contexts.map { CachedContext(from: $0) }
        cacheEngine.set(cachedContexts, forKey: cacheKey)
    }

    /// 按最近使用时间排序（最近使用的在最前面）
    private func sortContextsByLastUsed() {
        contexts.sort { context1, context2 in
            // 如果有 lastUsedTime，按时间倒序排列
            if let time1 = context1.lastUsedTime, let time2 = context2.lastUsedTime {
                return time1 > time2
            }
            // 如果只有一个有 lastUsedTime，有的排在前面
            if context1.lastUsedTime != nil {
                return true
            }
            if context2.lastUsedTime != nil {
                return false
            }
            // 都没有 lastUsedTime，保持原顺序
            return false
        }
    }

    /// 刷新界面
    public func reloadData() {
        loadContexts()
    }

    // MARK: - Selection

    /// 设置当前选中的 Context
    public func setSelectedContext(_ context: AEAIContext) {
        selectedContext = context
        // 查找并更新 selectedIndex
        if let index = contexts.firstIndex(where: { $0.id == context.id }) {
            selectedIndex = index
        }
        tableView.reloadData()
    }

    /// 清除选中状态
    public func clearSelection() {
        selectedContext = nil
        selectedIndex = -1
        tableView.deselectAll(nil)
        tableView.reloadData()
    }

    /// 激活并选中当前使用的 Context
    public func focusAndSelectCurrent() {
        // 成为第一响应者
        window?.makeFirstResponder(tableView)

        // 如果有选中的 Context，找到它在列表中的位置并选中
        if let selected = selectedContext,
           let index = contexts.firstIndex(where: { $0.id == selected.id }) {
            selectedIndex = index
        } else if !contexts.isEmpty {
            // 如果没有选中的，选中第一个
            selectedIndex = 0
        }

        updateSelection()
    }
}

// MARK: - NSTableViewDataSource

extension AERightView: NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return contexts.count
    }
}

// MARK: - NSTableViewDelegate

extension AERightView: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < contexts.count else { return nil }

        let context = contexts[row]

        // 创建或复用 cell
        let identifier = NSUserInterfaceItemIdentifier("ContextCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cell == nil {
            cell = NSTableCellView()
            cell?.identifier = identifier

            // 创建图标 ImageView
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyDown
            cell?.addSubview(imageView)
            cell?.imageView = imageView

            // 创建文本 TextField
            let textField = NSTextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.isBordered = false
            textField.isEditable = false
            textField.backgroundColor = .clear
            textField.lineBreakMode = .byTruncatingMiddle
            textField.font = NSFont.systemFont(ofSize: 13)
            cell?.addSubview(textField)
            cell?.textField = textField

            // 设置约束
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 8),
                imageView.centerYAnchor.constraint(equalTo: cell!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }

        // 设置文件夹图标
        if #available(macOS 11.0, *) {
            cell?.imageView?.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        } else {
            // macOS 10.15 使用传统图标
            cell?.imageView?.image = NSImage(named: NSImage.folderName)
        }

        // 显示目录路径
        cell?.textField?.stringValue = context.dir

        // 判断是否是当前激活的 context（已确认）
        let isActiveContext = selectedContext?.id == context.id

        // 判断是否是当前选中的项（临时高亮）
        let isSelectedRow = row == selectedIndex

        // 设置选中状态的样式
        if isSelectedRow {
            // 临时选中：白色文字
            cell?.textField?.textColor = .white
            cell?.imageView?.contentTintColor = .white
        } else if isActiveContext {
            // 已确认的 context：蓝色高亮
            cell?.textField?.textColor = .systemBlue
            cell?.imageView?.contentTintColor = .systemBlue
        } else {
            // 普通状态
            cell?.textField?.textColor = .labelColor
            cell?.imageView?.contentTintColor = .systemGray
        }

        return cell
    }

    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }

    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // 双击事件检测
        if NSApp.currentEvent?.clickCount == 2 {
            handleDoubleClick(row: row)
        }
        return true
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < contexts.count else { return }

        // 同步更新 selectedIndex（界面选中效果）
        selectedIndex = selectedRow

        // 刷新所有行以更新视觉样式
        tableView.reloadData()

        // 注意：这里不更新 selectedContext，也不通知 delegate
        // 只有按回车键或双击时才真正切换 Context

        // 刷新显示
        tableView.reloadData()
    }

    /// 处理双击事件
    private func handleDoubleClick(row: Int) {
        guard row >= 0, row < contexts.count else { return }

        let context = contexts[row]

        // 更新 selectedContext
        selectedContext = context

        print("✅ 双击选择 Context: \(context.dir)")

        // 更新最后使用时间
        context.lastUsedTime = Date()

        // 重新排序，将选中的 context 移到第一位
        sortContextsByLastUsed()

        // 保存更新后的 Context 列表到缓存
        saveContextsToCache()

        // 通知业务层 - 用户双击切换 Context
        delegate?.rightView(self, didSelectContext: context)

        // 清除临时选中状态
        selectedIndex = -1
        tableView.deselectAll(nil)

        // 刷新显示
        tableView.reloadData()
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        return rowView
    }

    public func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        guard row < contexts.count else { return }
        let context = contexts[row]

        // 设置选中行的背景色
        if selectedContext?.id == context.id {
            rowView.backgroundColor = .selectedContentBackgroundColor
        } else {
            rowView.backgroundColor = .clear
        }
    }
}

// MARK: - AEAIContextManagerDelegate

extension AERightView: AEAIContextManagerDelegate {

    /// Context 列表发生变化时调用
    public func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 合并新旧 context 列表，保留历史 context
            var mergedContexts: [AEAIContext] = []
            var existingIDs = Set<String>()

            // 1. 先添加所有新的 context（从 Manager 来的）
            for newContext in contexts {
                mergedContexts.append(newContext)
                existingIDs.insert(newContext.id)
            }

            // 2. 保留旧列表中不在新列表中的 context（历史 context）
            for oldContext in self.contexts {
                if !existingIDs.contains(oldContext.id) {
                    mergedContexts.append(oldContext)
                }
            }

            // 3. 更新列表
            self.contexts = mergedContexts

            // 重新排序
            self.sortContextsByLastUsed()

            // 验证 selectedIndex 是否还有效
            if self.selectedIndex >= self.contexts.count {
                self.selectedIndex = self.contexts.isEmpty ? -1 : self.contexts.count - 1
            }

            // 保存更新后的列表到缓存
            self.saveContextsToCache()

            self.tableView.reloadData()
        }
    }

    /// 添加了新的 Context（可选实现）
    public func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext) {
        print("✅ 新增 Context: \(context.dir)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. 设置新 Context 为选中状态
            self.selectedContext = context

            // 2. 更新最后使用时间
            context.lastUsedTime = Date()

            // 3. 刷新列表（会触发排序，新 Context 会排到第一位）
            self.reloadData()

            // 4. 通知 delegate 切换到新 Context
            self.delegate?.rightView(self, didSelectContext: context)

            print("🎯 自动选中新创建的 Context: \(context.dir)")
        }
    }

    /// 删除了 Context（可选实现）
    public func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext) {
        print("🗑️ 删除 Context: \(context.dir)")
    }
}

// MARK: - AECombinationKeyHandler

extension AERightView: AECombinationKeyHandler {

    public var combinationKeyHandlerID: String {
        return "AERightView"
    }

    public func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        // 处理 Command+R：激活右侧视图
        if modifiers.contains(.command) && key.lowercased() == "r" {
            print("⌨️ Command+R 激活 AERightView")
            focusAndSelectCurrent()
            return true
        }

        // 检查焦点状态
        guard window?.firstResponder == tableView || isFocused else {
            return false
        }

        // 处理上下方向键
        switch event.keyCode {
        case AEKeyCode.upArrow:
            selectPreviousContext()
            return true
        case AEKeyCode.downArrow:
            selectNextContext()
            return true
        case AEKeyCode.return, AEKeyCode.enter:
            confirmSelectedContext()
            return true
        default:
            return false
        }
    }

    // MARK: - Navigation Helpers

    private func selectNextContext() {
        guard !contexts.isEmpty else { return }

        // 如果没有选中，从第一个开始
        if selectedIndex == -1 {
            selectedIndex = 0
        } else {
            // 向下移动，循环到顶部
            selectedIndex = (selectedIndex + 1) % contexts.count
        }

        updateSelection()
    }

    private func selectPreviousContext() {
        guard !contexts.isEmpty else { return }

        // 如果没有选中，从第一个开始
        if selectedIndex == -1 {
            selectedIndex = 0
        } else if selectedIndex == 0 {
            // 向上移动，循环到底部
            selectedIndex = contexts.count - 1
        } else {
            selectedIndex = selectedIndex - 1
        }

        updateSelection()
    }

    /// 更新 TableView 的选中状态（仅界面显示效果）
    private func updateSelection() {
        guard selectedIndex >= 0, selectedIndex < contexts.count else { return }

        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)

        // 只刷新界面，不更新 selectedContext（selectedContext 只在回车确认时更新）
        tableView.reloadData()
    }

    /// 确认选择当前 Context（回车键触发）
    private func confirmSelectedContext() {
        guard selectedIndex >= 0, selectedIndex < contexts.count else {
            print("⚠️ 没有选中的 Context")
            return
        }

        let context = contexts[selectedIndex]

        // 检查是否已经是当前选中的 Context
        if selectedContext?.id == context.id {
            print("⚠️ 已经是当前 Context，无需重复切换")
            return
        }

        // 更新 selectedContext
        selectedContext = context

        print("✅ 回车确认选择 Context: \(context.dir)")

        // 更新最后使用时间
        context.lastUsedTime = Date()

        // 重新排序，将选中的 context 移到第一位
        sortContextsByLastUsed()

        // 保存更新后的 Context 列表到缓存
        saveContextsToCache()

        // 通知业务层 - 用户确认切换 Context
        notifySelectedContextToDelegate(context)

        // 清除临时选中状态
        selectedIndex = -1
        tableView.deselectAll(nil)

        // 刷新显示
        tableView.reloadData()
    }

    // MARK: - Focus Handling

    public override func becomeFirstResponder() -> Bool {
        isFocused = true
        // 通知代理，rightView 获得焦点
        if let delegate = delegate as? AERightViewFocusDelegate {
            delegate.rightViewDidBecomeFocused(self)
        }
        return super.becomeFirstResponder()
    }

    public override func resignFirstResponder() -> Bool {
        isFocused = false
        // 失去焦点时清空临时选中状态
        clearSelection()
        return super.resignFirstResponder()
    }
}

