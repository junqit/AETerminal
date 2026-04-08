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

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadContexts()
        registerAsDelegate()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        loadContexts()
        registerAsDelegate()
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
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField

        if cell == nil {
            cell = NSTextField()
            cell?.identifier = identifier
            cell?.isBordered = false
            cell?.isEditable = false
            cell?.backgroundColor = .clear
            cell?.lineBreakMode = .byTruncatingMiddle
        }

        // 显示目录路径
        cell?.stringValue = context.content

        // 设置选中状态的样式
        if selectedContext?.id == context.id {
            cell?.textColor = .white
        } else {
            cell?.textColor = .labelColor
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

