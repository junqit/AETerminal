//
//  AEComparisonView.swift
//  最简单的等宽对比视图实现
//
//  使用方法：
//  let comparisonView = AEComparisonView(responses: [response1, response2])
//  comparisonView.frame = CGRect(x: 0, y: 0, width: 800, height: 300)
//  parentView.addSubview(comparisonView)
//

import AppKit

public class AEComparisonView: NSView {

    private let responses: [(name: String, text: String)]

    public init(responses: [(name: String, text: String)]) {
        self.responses = responses
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 8

        // 创建水平 StackView
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually  // 关键：等宽分配
        stackView.spacing = 1  // 分隔线宽度
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // 为每个响应创建面板
        for response in responses {
            let panel = createPanel(name: response.name, text: response.text)
            stackView.addArrangedSubview(panel)
        }

        addSubview(stackView)

        // StackView 填满整个视图
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func createPanel(name: String, text: String) -> NSView {
        let panel = NSView()
        panel.wantsLayer = true
        panel.translatesAutoresizingMaskIntoConstraints = false  // 关键：让约束生效

        // 设置背景色
        if #available(macOS 10.14, *) {
            panel.layer?.backgroundColor = NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.15, green: 0.15, blue: 0.16, alpha: 1.0)
                } else {
                    return NSColor.white
                }
            }.cgColor
        } else {
            panel.layer?.backgroundColor = NSColor.white.cgColor
        }

        // 创建标题
        let titleLabel = NSTextField(labelWithString: name)
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.isBezeled = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 使用 ScrollView + TextView 显示内容
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // 创建 TextView
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.string = text

        // 设置文本容器
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        panel.addSubview(titleLabel)
        panel.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8)
        ])

        print("   创建面板: \(name), 内容长度: \(text.count)")

        return panel
    }
}
