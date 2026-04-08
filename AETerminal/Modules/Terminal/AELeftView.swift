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

/// 自定义目录 Cell
class DirectoryTableCellView: NSTableCellView {

    /// 背景视图（用于显示选中效果）
    private let backgroundView: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 展开/收起按钮
    let expandButton: NSButton = {
        let button = NSButton()
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.bezelStyle = .regularSquare
        button.imagePosition = .imageOnly
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 目录名称标签
    let nameLabel: NSTextField = {
        let label = NSTextField()
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 点击响应回调
    var onExpandButtonClicked: (() -> Void)?
    var onNameClicked: (() -> Void)?

    /// 缩进约束（用于动态调整）
    private var expandButtonLeadingConstraint: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        // 添加背景视图到最底层
        addSubview(backgroundView, positioned: .below, relativeTo: nil)
        addSubview(expandButton)
        addSubview(nameLabel)

        // 确保背景视图在最底层
        backgroundView.wantsLayer = true
        backgroundView.layer?.zPosition = -1

        // 创建并保存缩进约束
        expandButtonLeadingConstraint = expandButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4)

        NSLayoutConstraint.activate([
            // 背景视图约束 - 覆盖整个 cell
            backgroundView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            // 展开按钮约束
            expandButtonLeadingConstraint,
            expandButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 20),
            expandButton.heightAnchor.constraint(equalToConstant: 20),

            // 名称标签约束
            nameLabel.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // 设置按钮动作
        expandButton.target = self
        expandButton.action = #selector(expandButtonAction)

        // 添加点击手势到名称标签
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(nameLabelAction))
        nameLabel.addGestureRecognizer(clickGesture)
    }

    @objc private func expandButtonAction() {
        onExpandButtonClicked?()
    }

    @objc private func nameLabelAction() {
        onNameClicked?()
    }

    /// 配置 Cell
    func configure(with item: DirectoryItem, isSelected: Bool) {
        // 根据层级添加缩进
        let indentWidth: CGFloat = CGFloat(item.level) * 20
        expandButtonLeadingConstraint.constant = 4 + indentWidth

        // 设置展开按钮标题
        let expandIcon = item.isExpanded ? "▼" : "▶︎"

        // 设置选中状态的背景色和文字色
        if isSelected {
            // 选中状态：使用系统蓝色背景 + 白色文字
            let selectedColor = NSColor.selectedContentBackgroundColor
            backgroundView.layer?.backgroundColor = selectedColor.cgColor
            backgroundView.layer?.opacity = 1.0
            backgroundView.isHidden = false

            // 设置文字颜色为白色
            let whiteColor = NSColor.white

            // 使用 NSAttributedString 设置名称标签，确保颜色生效
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: whiteColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            nameLabel.attributedStringValue = NSAttributedString(string: "📁 \(item.name)", attributes: nameAttributes)

            // 设置按钮文字颜色
            let buttonAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: whiteColor,
                .font: NSFont.systemFont(ofSize: 12)
            ]
            expandButton.attributedTitle = NSAttributedString(string: expandIcon, attributes: buttonAttributes)

            print("✅ 设置选中: \(item.name), 背景色: \(selectedColor), hidden: \(backgroundView.isHidden)")
        } else {
            // 未选中状态：隐藏背景 + 默认文字颜色
            backgroundView.layer?.backgroundColor = NSColor.clear.cgColor
            backgroundView.layer?.opacity = 0.0
            backgroundView.isHidden = true

            // 恢复默认颜色
            let defaultColor = NSColor.labelColor

            // 使用 NSAttributedString 设置名称标签
            let nameAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: defaultColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
            nameLabel.attributedStringValue = NSAttributedString(string: "📁 \(item.name)", attributes: nameAttributes)

            // 恢复按钮默认颜色
            let buttonAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: defaultColor,
                .font: NSFont.systemFont(ofSize: 12)
            ]
            expandButton.attributedTitle = NSAttributedString(string: expandIcon, attributes: buttonAttributes)
        }

        // 强制刷新显示
        backgroundView.needsDisplay = true
        backgroundView.needsLayout = true
        needsLayout = true
    }
}

/// 目录项数据结构
class DirectoryItem {
    let name: String
    let fullPath: String
    let level: Int // 层级深度，从 0 开始
    var isExpanded: Bool
    var children: [DirectoryItem]?

    init(name: String, fullPath: String, level: Int, isExpanded: Bool = false) {
        self.name = name
        self.fullPath = fullPath
        self.level = level
        self.isExpanded = isExpanded
        self.children = nil
    }
}

/// 左侧目录列表视图
class AELeftView: NSView {

    // MARK: - Properties

    weak var delegate: AELeftViewDelegate?

    /// 是否是焦点视图
    private var isFocused: Bool = false

    /// 根目录路径
    private(set) var rootPath: String = ""

    /// 当前选中的目录路径
    private(set) var currentPath: String = ""

    /// 根目录项列表
    private var rootItems: [DirectoryItem] = []

    /// 展平后用于显示的目录项列表
    private var displayItems: [DirectoryItem] = []

    /// 当前选中的目录项
    private var selectedItem: DirectoryItem?

    /// TableView
    private let tableView: NSTableView = {
        let table = NSTableView()
        table.headerView = nil
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none // 禁用默认选中高亮
        table.focusRingType = .none
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false

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
        registerCombinationKeyHandler()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
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
        // 设置背景色
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // 配置 ScrollView
        scrollView.documentView = tableView
        addSubview(scrollView)
        addSubview(bottomContainer)

        // 添加按钮到底部容器
        bottomContainer.addSubview(confirmButton)

        // 设置约束
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        bottomContainer.translatesAutoresizingMaskIntoConstraints = false
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
            bottomContainer.heightAnchor.constraint(equalToConstant: 48),

            // 确认按钮约束
            confirmButton.leadingAnchor.constraint(equalTo: bottomContainer.leadingAnchor, constant: 12),
            confirmButton.topAnchor.constraint(equalTo: bottomContainer.topAnchor, constant: 10),
            confirmButton.trailingAnchor.constraint(equalTo: bottomContainer.trailingAnchor, constant: -12),
            confirmButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        // 设置 TableView 代理和数据源
        tableView.delegate = self
        tableView.dataSource = self

        // 设置按钮事件
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonClicked)
    }

    // MARK: - Public Methods

    /// 加载指定路径的子目录
    /// - Parameter path: 根目录路径
    func loadDirectories(atPath path: String) {
        rootPath = path
        currentPath = path
        selectedItem = nil // 清除选中项

        // 加载根目录的子目录
        let subdirs = AEDirectory.subdirectories(atPath: path)
        rootItems = subdirs.map { name in
            let fullPath = (path as NSString).appendingPathComponent(name)
            return DirectoryItem(name: name, fullPath: fullPath, level: 0)
        }

        // 重建显示列表
        rebuildDisplayItems()
        tableView.reloadData()
    }

    /// 刷新当前显示
    func refresh() {
        loadDirectories(atPath: rootPath)
    }

    // MARK: - Private Methods

    /// 重建展平的显示列表
    private func rebuildDisplayItems() {
        displayItems = []
        for item in rootItems {
            appendItemToDisplay(item)
        }
    }

    /// 递归追加目录项到显示列表
    private func appendItemToDisplay(_ item: DirectoryItem) {
        displayItems.append(item)

        // 如果展开了，递归添加子项
        if item.isExpanded, let children = item.children {
            for child in children {
                appendItemToDisplay(child)
            }
        }
    }

    /// 切换目录的展开/收起状态
    private func toggleDirectory(at index: Int) {
        guard index < displayItems.count else { return }
        let item = displayItems[index]

        // 点击三角形时，清除选中状态
        selectedItem = nil
        currentPath = rootPath
        print("清除选中状态")

        if item.isExpanded {
            // 收起
            item.isExpanded = false
            print("收起目录: \(item.name)")
        } else {
            // 展开：加载子目录
            if item.children == nil {
                loadChildren(for: item)
            }
            item.isExpanded = true
            print("展开目录: \(item.name), 子目录数: \(item.children?.count ?? 0)")
        }

        // 重建显示列表
        rebuildDisplayItems()

        // 刷新表格
        tableView.reloadData()
    }

    /// 选中目录（不展开）
    private func selectDirectory(at index: Int) {
        guard index < displayItems.count else { return }
        let item = displayItems[index]

        // 如果点击的是已经选中的目录，保持选中状态
        if selectedItem?.fullPath == item.fullPath {
            print("已选中目录: \(item.fullPath)")
            return
        }

        // 更新选中项
        selectedItem = item
        currentPath = item.fullPath

        print("选中目录: \(item.name) - \(item.fullPath)")

        // 刷新表格以更新选中状态
        tableView.reloadData()
    }

    /// 加载目录的子目录
    private func loadChildren(for item: DirectoryItem) {
        let subdirs = AEDirectory.subdirectories(atPath: item.fullPath)
        item.children = subdirs.map { name in
            let fullPath = (item.fullPath as NSString).appendingPathComponent(name)
            return DirectoryItem(name: name, fullPath: fullPath, level: item.level + 1)
        }
    }

    // MARK: - Button Actions

    @objc private func confirmButtonClicked() {
        // 通过 delegate 返回当前选中的目录路径
        // 如果有选中项，返回选中项的路径；否则返回根目录
        let pathToConfirm = selectedItem?.fullPath ?? rootPath
        delegate?.leftView(self, didConfirmDirectory: pathToConfirm)

        print("确认选择目录: \(pathToConfirm)")
    }
}

// MARK: - NSTableViewDataSource

extension AELeftView: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayItems.count
    }
}

// MARK: - NSTableViewDelegate

extension AELeftView: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("DirectoryCell")

        guard row < displayItems.count else { return nil }
        let item = displayItems[row]

        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? DirectoryTableCellView

        if cellView == nil {
            cellView = DirectoryTableCellView()
            cellView?.identifier = identifier
        }

        // 配置 cell
        let isSelected = (selectedItem?.fullPath == item.fullPath)

        if isSelected {
            print("🔵 Row \(row) (\(item.name)) 应该显示为选中状态")
        }

        cellView?.configure(with: item, isSelected: isSelected)

        // 设置回调
        cellView?.onExpandButtonClicked = { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            if let index = self.displayItems.firstIndex(where: { $0.fullPath == item.fullPath }) {
                self.toggleDirectory(at: index)
            }
        }

        cellView?.onNameClicked = { [weak self, weak item] in
            guard let self = self, let item = item else { return }
            if let index = self.displayItems.firstIndex(where: { $0.fullPath == item.fullPath }) {
                self.selectDirectory(at: index)
            }
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // 禁用 TableView 的默认选择行为，使用自定义的点击处理
        return false
    }
}

// MARK: - AECombinationKeyHandler

extension AELeftView: AECombinationKeyHandler {

    public var combinationKeyHandlerID: String {
        return "AELeftView"
    }

    public func handleCombinationKey(event: NSEvent, modifiers: NSEvent.ModifierFlags, key: String) -> Bool {
        // 由业务层自己判断是否需要处理（检查焦点状态）
        guard window?.firstResponder == tableView || isFocused else {
            return false // 没有焦点，不处理
        }

        // 处理 Command 键组合
        if modifiers.contains(.command) {
            switch key.uppercased() {
            case "L":
                print("⌘L: 刷新目录列表")
                refresh()
                return true
            default:
                break
            }
        }

        // 处理 Control 键组合
        if modifiers.contains(.control) {
            switch key.uppercased() {
            case "N", "DOWN":
                // 向下选择
                print("⌃N: 向下选择目录")
                return true
            case "P", "UP":
                // 向上选择
                print("⌃P: 向上选择目录")
                return true
            default:
                break
            }
        }

        return false
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
