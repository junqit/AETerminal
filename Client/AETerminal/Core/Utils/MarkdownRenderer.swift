//
//  MarkdownRenderer.swift
//  AETerminal
//
//  Created by Claude on 2026/4/11.
//

import Foundation
import AppKit

/// Markdown 渲染器 - 将 Markdown 文本转换为 NSAttributedString
class MarkdownRenderer {

    // MARK: - 字体配置

    private let baseFont: NSFont
    private let baseFontSize: CGFloat
    private let codeFont: NSFont

    init(fontSize: CGFloat = 13) {
        self.baseFontSize = fontSize
        self.baseFont = NSFont.systemFont(ofSize: fontSize)
        self.codeFont = NSFont.monospacedSystemFont(ofSize: fontSize - 1, weight: .regular)
    }

    // MARK: - 公共方法

    /// 渲染 Markdown 文本为富文本
    /// - Parameter markdown: Markdown 源文本
    /// - Returns: 渲染后的富文本
    func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 按行处理
        let lines = markdown.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""

        for line in lines {
            // 处理代码块
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    result.append(renderCodeBlock(codeBlockContent, language: codeBlockLanguage))
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                    inCodeBlock = false
                } else {
                    // 开始代码块
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3).trimmingCharacters(in: .whitespaces))
                }
                continue
            }

            if inCodeBlock {
                // 收集代码块内容
                codeBlockContent += line + "\n"
            } else {
                // 处理普通行
                result.append(renderLine(line))
            }
        }

        // 如果还有未关闭的代码块
        if inCodeBlock {
            result.append(renderCodeBlock(codeBlockContent, language: codeBlockLanguage))
        }

        return result
    }

    // MARK: - 私有方法

    /// 渲染单行文本
    private func renderLine(_ line: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 空行
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(NSAttributedString(string: "\n"))
            return result
        }

        // 标题
        if line.hasPrefix("#") {
            return renderHeading(line)
        }

        // 无序列表
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return renderListItem(line, ordered: false)
        }

        // 有序列表 (1. 2. 3. 等)
        if line.range(of: "^\\d+\\.\\s", options: .regularExpression) != nil {
            return renderListItem(line, ordered: true)
        }

        // 引用
        if line.hasPrefix("> ") {
            return renderBlockquote(line)
        }

        // 普通段落（支持行内格式）
        return renderParagraph(line)
    }

    /// 渲染标题
    private func renderHeading(_ line: String) -> NSAttributedString {
        var level = 0
        var content = line

        // 计算标题级别
        for char in line {
            if char == "#" {
                level += 1
            } else {
                break
            }
        }

        // 提取标题内容
        if level > 0 && level <= 6 {
            content = String(line.dropFirst(level).trimmingCharacters(in: .whitespaces))
        }

        // 根据级别设置字体大小
        let fontSize = baseFontSize + CGFloat(7 - level) * 2
        let font = NSFont.boldSystemFont(ofSize: fontSize)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: dynamicTextColor()
        ]

        let result = NSMutableAttributedString(string: content + "\n", attributes: attrs)
        return result
    }

    /// 渲染列表项
    private func renderListItem(_ line: String, ordered: Bool) -> NSAttributedString {
        let bullet = ordered ? "  " : "  • "
        let content: String

        if ordered {
            // 有序列表，保留数字
            if let match = line.range(of: "^\\d+\\.\\s", options: .regularExpression) {
                content = String(line[match.upperBound...])
            } else {
                content = line
            }
        } else {
            // 无序列表，去掉标记
            content = String(line.dropFirst(2))
        }

        let result = NSMutableAttributedString(string: bullet)
        result.append(renderInlineFormats(content))
        result.append(NSAttributedString(string: "\n"))

        return result
    }

    /// 渲染引用
    private func renderBlockquote(_ line: String) -> NSAttributedString {
        let content = String(line.dropFirst(2))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.headIndent = 20
                style.firstLineHeadIndent = 20
                return style
            }()
        ]

        let result = NSMutableAttributedString(string: "▎ " + content + "\n", attributes: attrs)
        return result
    }

    /// 渲染段落（支持行内格式）
    private func renderParagraph(_ line: String) -> NSAttributedString {
        let result = renderInlineFormats(line)
        let mutable = NSMutableAttributedString(attributedString: result)
        mutable.append(NSAttributedString(string: "\n"))
        return mutable
    }

    /// 渲染行内格式（粗体、斜体、行内代码、链接等）
    private func renderInlineFormats(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 简单的行内格式解析
        // TODO: 实现更完善的正则匹配（粗体、斜体、行内代码、链接等）

        // 暂时使用简单的文本处理
        result.append(NSAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: dynamicTextColor()
        ]))

        return result
    }

    /// 渲染行内代码
    private func renderInlineCode(_ code: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: codeFont,
            .foregroundColor: NSColor.systemPink,
            .backgroundColor: NSColor.controlBackgroundColor
        ]
        return NSAttributedString(string: code, attributes: attrs)
    }

    /// 渲染粗体
    private func renderBold(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: baseFontSize),
            .foregroundColor: dynamicTextColor()
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    /// 渲染斜体
    private func renderItalic(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: baseFontSize, weight: .light),
            .foregroundColor: dynamicTextColor(),
            .obliqueness: 0.2
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    /// 渲染链接
    private func renderLink(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    /// 渲染代码块
    private func renderCodeBlock(_ code: String, language: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // 代码块背景和边框效果
        let codeAttrs: [NSAttributedString.Key: Any] = [
            .font: codeFont,
            .foregroundColor: codeTextColor(),
            .backgroundColor: codeBackgroundColor(),
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.headIndent = 10
                style.firstLineHeadIndent = 10
                style.tailIndent = -10
                return style
            }()
        ]

        // 语言标签（如果有）
        if !language.isEmpty {
            let langAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: baseFontSize - 2),
                .foregroundColor: NSColor.secondaryLabelColor,
                .backgroundColor: codeBackgroundColor()
            ]
            result.append(NSAttributedString(string: "[\(language)]\n", attributes: langAttrs))
        }

        // 代码内容
        result.append(NSAttributedString(string: code, attributes: codeAttrs))
        result.append(NSAttributedString(string: "\n"))

        return result
    }

    // MARK: - 颜色工具

    /// 动态文本颜色（根据深色/浅色模式）
    private func dynamicTextColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return .white
                } else {
                    return .black
                }
            }
        } else {
            return .labelColor
        }
    }

    /// 代码文本颜色
    private func codeTextColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
                } else {
                    return NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                }
            }
        } else {
            return .labelColor
        }
    }

    /// 代码背景颜色
    private func codeBackgroundColor() -> NSColor {
        if #available(macOS 10.14, *) {
            return NSColor(name: nil) { appearance in
                if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                    return NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
                } else {
                    return NSColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
                }
            }
        } else {
            return .controlBackgroundColor
        }
    }
}
