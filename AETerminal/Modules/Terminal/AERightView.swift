//
//  AERightView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit
import AEAIEngin

/// 右侧视图 - 显示 Context 列表
class AERightView: NSView {

    // MARK: - UI Components

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!

    // MARK: - Data

    /// 当前显示的上下文列表
    private var contexts: [AEAIContext] = []

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
        tableView.reloadData()
    }

    /// 刷新界面
    public func reloadData() {
        loadContexts()
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
        }

        cell?.stringValue = context.content
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
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

