//
//  AEChatViewContainer.swift
//  AEAIModule
//
//  聊天视图容器 - 包含标题栏和聊天视图
//

import AppKit

/// 聊天视图容器代理协议
protocol AEChatViewContainerDelegate: AnyObject {
    func containerDidTap(_ container: AEChatViewContainer)
    func containerDidClose(_ container: AEChatViewContainer)
}

/// 聊天视图容器 - 包含标题栏和聊天视图
class AEChatViewContainer: NSView {

    // MARK: - Properties

    let contextId: String
    let contextName: String
    let chatView: AEChatView

    private var headerView: NSView!
    private var titleLabel: NSTextField!
    private var closeButton: NSButton!
    private var isActive: Bool = false

    weak var delegate: AEChatViewContainerDelegate?

    // MARK: - Initialization

    init(contextId: String, contextName: String) {
        self.contextId = contextId
        self.contextName = contextName
        self.chatView = AEChatView()

        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // 创建标题栏
        headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // 创建标题标签
        titleLabel = NSTextField(labelWithString: contextName)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 创建关闭按钮
        closeButton = NSButton()
        closeButton.title = "×"
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.font = NSFont.systemFont(ofSize: 16, weight: .light)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.target = self
        closeButton.action = #selector(closeButtonTapped)

        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)

        // 设置聊天视图
        chatView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerView)
        addSubview(chatView)

        // 设置约束
        NSLayoutConstraint.activate([
            // 标题栏约束
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 30),

            // 标题标签约束
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),

            // 关闭按钮约束
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            // 聊天视图约束
            chatView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            chatView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chatView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chatView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 添加点击手势
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(containerTapped))
        headerView.addGestureRecognizer(clickGesture)
    }

    // MARK: - Actions

    @objc private func containerTapped() {
        delegate?.containerDidTap(self)
    }

    @objc private func closeButtonTapped() {
        delegate?.containerDidClose(self)
    }

    // MARK: - Public Methods

    func setActive(_ active: Bool) {
        isActive = active

        if active {
            headerView.layer?.backgroundColor = NSColor.selectedControlColor.cgColor
            titleLabel.textColor = .white
        } else {
            headerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
            titleLabel.textColor = .labelColor
        }
    }
}
