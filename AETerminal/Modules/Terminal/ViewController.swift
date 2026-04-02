//
//  ViewController.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/1.
//

import Cocoa
import AENetworkEngine

class ViewController: NSViewController {

    @IBOutlet weak var inputTextView: NSTextView!
    @IBOutlet weak var scrollViewHeightConstraint: NSLayoutConstraint!

    private let minHeight: CGFloat = 20
    private let maxHeight: CGFloat = 200

    // 命令历史记录管理器
    private let historyManager = CommandHistoryManager.shared

    // 暂存当前输入（用于在浏览历史时保存）
    private var currentInput: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer?.backgroundColor = NSColor.systemBlue.cgColor

        AENetHttpEngine.configure(config: AENetHttpConfig(baseURL: "http://127.0.0.1:9000"))

        // 设置 textView 的 delegate
        inputTextView.delegate = self

        // 设置初始高度
        updateTextViewHeight()

        // Do any additional setup after loading the view.
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        // 让 textView 成为第一响应者，可以直接接收键盘输入
        self.view.window?.makeFirstResponder(inputTextView)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    // 根据内容更新 TextView 高度
    private func updateTextViewHeight() {
        guard let layoutManager = inputTextView.layoutManager,
              let textContainer = inputTextView.textContainer else { return }

        // 强制布局
        layoutManager.ensureLayout(for: textContainer)

        // 计算所需高度
        let usedRect = layoutManager.usedRect(for: textContainer)
        var newHeight = ceil(usedRect.height)

        // 限制在最小和最大高度之间
        newHeight = max(minHeight, min(newHeight, maxHeight))

        // 更新约束
        scrollViewHeightConstraint.constant = newHeight
    }

    // MARK: - History Navigation

    /// 向上浏览历史记录（更旧的命令）
    private func navigateHistoryUp() {
        // 如果是第一次按上下键，保存当前输入
        if historyManager.currentIndex == -1 {
            currentInput = inputTextView.string
        }

        if let command = historyManager.navigateUp() {
            inputTextView.string = command
            updateTextViewHeight()
            moveCursorToEnd()
        }
    }

    /// 向下浏览历史记录（更新的命令）
    private func navigateHistoryDown() {
        if let command = historyManager.navigateDown() {
            inputTextView.string = command
        } else {
            // 回到当前输入
            inputTextView.string = currentInput
        }

        updateTextViewHeight()
        moveCursorToEnd()
    }

    /// 将光标移到文本末尾
    private func moveCursorToEnd() {
        let textLength = inputTextView.string.count
        inputTextView.setSelectedRange(NSRange(location: textLength, length: 0))
    }
}

extension ViewController: NSTextViewDelegate {

    // 响应回车键和上下键
    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // 回车键被按下，获取 text 信息
            let text = textView.string
            print("回车键按下，输入内容: \(text)")

            // 添加到历史记录
            historyManager.addCommand(text)

            // 重置导航和当前输入
            currentInput = ""

            // 处理输入的文本
            handleInputText(text)

            // 清空 textView
            textView.string = ""

            // 更新高度
            updateTextViewHeight()

            // 返回 true 表示我们已经处理了这个命令
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            // 上键被按下，显示上一条历史记录
            navigateHistoryUp()
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            // 下键被按下，显示下一条历史记录
            navigateHistoryDown()
            return true
        }

        // 返回 false 让系统处理其他命令
        return false
    }

    // 文本内容改变时调用
    func textDidChange(_ notification: Notification) {
        updateTextViewHeight()
    }

    // 处理输入文本的方法
    private func handleInputText(_ text: String) {
        // 这里可以添加处理输入文本的逻辑
        // 例如：执行命令、发送消息等
        
        let req = AENetHttpReq(post: "chat", parameters: ["user_input":text])
        AENetHttpEngine.send(request: req) { rsp in
            
            
            print("回车键按下，输入内容: \(rsp.response)")

        }
    }
}

