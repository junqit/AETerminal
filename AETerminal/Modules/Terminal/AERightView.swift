//
//  AERightView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit
import AEAIEngin

/// 右侧视图委托协议
protocol AERightViewDelegate: AnyObject {
    /// 当用户选中某个 Context 时调用
    /// - Parameters:
    ///   - rightView: 右侧视图
    ///   - context: 被选中的上下文
    func rightView(_ rightView: AERightView, didSelectContext context: AEAIContext)
}

/// 右侧视图 - 显示 Context 列表
class AERightView: NSView {

    // MARK: - UI Components

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    // MARK: - Delegate

    weak var delegate: AERightViewDelegate?

    // MARK: - Data

    /// 当前显示的上下文列表
    private var contexts: [AEAIContext] = []

    /// 当前选中的 Context
    private var selectedContext: AEAIContext?

    /// 是否是焦点视图
    private var isFocused: Bool = false

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
        tableView.style = .plain
        tableView.rowSizeStyle = .default
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.headerView = nil

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
        contexts = AEAIContextManager.getAllContexts()
        sortContextsByLastUsed()
        tableView.reloadData()
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
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

extension AERightView: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return contexts.count
    }
}

// MARK: - NSTableViewDelegate

extension AERightView: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
        cell?.imageView?.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)

        // 显示目录路径
        cell?.textField?.stringValue = context.content

        // 设置选中状态的样式
        if selectedContext?.id == context.id {
            cell?.textField?.textColor = .white
            cell?.imageView?.contentTintColor = .white
        } else {
            cell?.textField?.textColor = .labelColor
            cell?.imageView?.contentTintColor = .systemBlue
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < contexts.count else { return }

        let context = contexts[selectedRow]
        selectedContext = context

        // 通知代理
        delegate?.rightView(self, didSelectContext: context)

        // 刷新显示
        tableView.reloadData()
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        return rowView
    }

    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
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
    func contextManager(_ manager: AEAIContextManager.Type, didUpdateContexts contexts: [AEAIContext]) {
        DispatchQueue.main.async { [weak self] in
            self?.contexts = contexts
            self?.tableView.reloadData()
        }
    }

    /// 添加了新的 Context（可选实现）
    func contextManager(_ manager: AEAIContextManager.Type, didAddContext context: AEAIContext) {
        print("✅ 新增 Context: \(context.content)")
    }

    /// 删除了 Context（可选实现）
    func contextManager(_ manager: AEAIContextManager.Type, didRemoveContext context: AEAIContext) {
        print("🗑️ 删除 Context: \(context.content)")
    }
}

// MARK: - AECombinationKeyHandler

extension AERightView: AECombinationKeyHandler {

    public var combinationKeyHandlerID: String {
        return "AERightView"
    }

    public func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        // 由业务层自己判断是否需要处理（检查焦点状态）
        guard window?.firstResponder == tableView || isFocused else {
            return false // 没有焦点，不处理
        }

        // 处理 Command 键组合
        if modifiers.contains(.command) {
            // 方向键通过 keyCode 判断
            switch event.keyCode {
            case AEKeyCode.upArrow:
                selectPreviousContext()
                return true
            case AEKeyCode.downArrow:
                selectNextContext()
                return true
            default:
                break
            }

            // 其他字母键
            switch key.uppercased() {
            case "R":
                print("⌘R: 刷新 Context 列表")
                reloadData()
                return true
            default:
                break
            }
        }

        // 处理回车键（确认选择）
        if event.keyCode == AEKeyCode.return || event.keyCode == AEKeyCode.enter {
            confirmSelectedContext()
            return true
        }

        return false
    }

    // MARK: - Navigation Helpers

    private func selectNextContext() {
        guard !contexts.isEmpty else { return }
        let currentRow = tableView.selectedRow
        let nextRow = (currentRow + 1) < contexts.count ? (currentRow + 1) : 0
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
    }

    private func selectPreviousContext() {
        guard !contexts.isEmpty else { return }
        let currentRow = tableView.selectedRow
        let prevRow = currentRow > 0 ? (currentRow - 1) : (contexts.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: prevRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(prevRow)
    }

    /// 确认选择当前 Context
    private func confirmSelectedContext() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < contexts.count else {
            print("⚠️ 没有选中的 Context")
            return
        }

        let context = contexts[selectedRow]
        selectedContext = context

        print("✅ 确认选择 Context: \(context.content)")

        // 通过 delegate 返回当前选中的 Context
        delegate?.rightView(self, didSelectContext: context)

        // 刷新显示
        tableView.reloadData()
    }

    // MARK: - Focus Handling

    public override func becomeFirstResponder() -> Bool {
        isFocused = true
        return super.becomeFirstResponder()
    }

    public override func resignFirstResponder() -> Bool {
        isFocused = false
        return super.resignFirstResponder()
    }
}

