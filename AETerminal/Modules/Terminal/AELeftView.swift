//
//  AELeftView.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/7.
//

import Foundation
import AppKit
import AEAIEngin

/// 目录选择回调协议
protocol AELeftViewDelegate: AnyObject {
    /// 当用户确认选择目录时调用
    /// - Parameter path: 选中的目录完整路径
    func leftView(_ leftView: AELeftView, didConfirmDirectory path: String)
}

/// 左侧目录列表视图
class AELeftView: NSView {

    // MARK: - Properties

    weak var delegate: AELeftViewDelegate?

    /// 当前显示的目录路径
    private(set) var currentPath: String = ""

    /// 路径浏览历史栈
    private var pathStack: [String] = []

    /// 目录列表
    private var directories: [String] = []

    /// TableView
    private let tableView: NSTableView = {
        let table = NSTableView()
        table.headerView = nil
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .regular
        table.focusRingType = .none

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "DirectoryColumn"))
        column.width = 200
        table.addTableColumn(column)

        return table
    }()

    /// ScrollView
    private let scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.backgroundColor = .clear
        return scroll
    }()

    /// 底部按钮容器
    private let bottomContainer: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return view
    }()

    /// 返回上一级按钮
    private let backButton: NSButton = {
        let button = NSButton()
        button.title = "← 返回"
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }()

    /// 确认选择按钮
    private let confirmButton: NSButton = {
        let button = NSButton()
        button.title = "确认选择"
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }()

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 设置背景色
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // 配置 ScrollView
        scrollView.documentView = tableView
        addSubview(scrollView)
        addSubview(bottomContainer)

        // 添加按钮到底部容器
        bottomContainer.addSubview(backButton)
        bottomContainer.addSubview(confirmButton)

        // 设置约束
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // ScrollView 约束
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomContainer.topAnchor),

            // 底部容器约束
            bottomContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomContainer.heightAnchor.constraint(equalToConstant: 80),

            // 返回按钮约束
            backButton.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 12),
            backButton.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 12),
            backButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -12),
            backButton.heightAnchor.constraint(equalToConstant: 28),

            // 确认按钮约束
            confirmButton.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 12),
            confirmButton.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            confirmButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -12),
            confirmButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        // 设置 TableView 代理和数据源
        tableView.delegate = self
        tableView.dataSource = self

        // 设置按钮事件
        backButton.target = self
        backButton.action = #selector(backButtonClicked)
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonClicked)

        // 初始状态：返回按钮不可用
        backButton.isEnabled = false
    }

    // MARK: - Public Methods

    /// 加载指定路径的子目录（初始加载）
    /// - Parameter path: 目录路径
    func loadDirectories(atPath path: String) {
        pathStack = [path] // 重置路径栈
        currentPath = path
        directories = AEDirectory.subdirectories(atPath: path)
        tableView.reloadData()
        updateBackButtonState()
    }

    /// 刷新当前目录
    func refresh() {
        directories = AEDirectory.subdirectories(atPath: currentPath)
        tableView.reloadData()
    }

    // MARK: - Private Methods

    /// 进入子目录
    private func navigateToSubdirectory(named name: String) {
        let fullPath = (currentPath as NSString).appendingPathComponent(name)

        // 检查是否为目录
        guard AEDirectory.isDirectory(atPath: fullPath) else {
            return
        }

        // 将当前路径压入栈
        pathStack.append(currentPath)

        // 加载新目录
        currentPath = fullPath
        directories = AEDirectory.subdirectories(atPath: fullPath)
        tableView.reloadData()
        updateBackButtonState()
    }

    /// 返回上一级目录
    private func navigateBack() {
        guard let previousPath = pathStack.popLast() else {
            return
        }

        currentPath = previousPath
        directories = AEDirectory.subdirectories(atPath: currentPath)
        tableView.reloadData()
        updateBackButtonState()
    }

    /// 更新返回按钮状态
    private func updateBackButtonState() {
        backButton.isEnabled = !pathStack.isEmpty
    }

    // MARK: - Button Actions

    @objc private func backButtonClicked() {
        navigateBack()
    }

    @objc private func confirmButtonClicked() {
        // 通过 delegate 返回当前选中的目录路径
        delegate?.leftView(self, didConfirmDirectory: currentPath)
    }
}

// MARK: - NSTableViewDataSource

extension AELeftView: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return directories.count
    }
}

// MARK: - NSTableViewDelegate

extension AELeftView: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("DirectoryCell")

        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier

            let textField = NSTextField()
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            textField.translatesAutoresizingMaskIntoConstraints = false

            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        let directoryName = directories[row]
        cellView?.textField?.stringValue = "📁 \(directoryName)"

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < directories.count else { return }

        let selectedDirectory = directories[selectedRow]

        // 进入选中的子目录
        navigateToSubdirectory(named: selectedDirectory)

        // 清除选择状态
        tableView.deselectAll(nil)
    }
}
