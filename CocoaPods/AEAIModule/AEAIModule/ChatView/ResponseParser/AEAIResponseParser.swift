//
//  AEAIResponseParser.swift
//  AEAIModule
//
//  Created by 田峻岐 on 2026/4/13.
//

import Foundation

/// AI 响应解析器 - 解析 llm_responses 内的所有内容
public class AEAIResponseParser {

    // MARK: - 解析结果

    /// 解析后的响应内容
    public struct ParsedResponse {
        /// 响应文本内容
        public let text: String
        /// 是否为 Markdown 格式
        public let isMarkdown: Bool
        /// AI 助手名称
        public let assistantName: String
        /// 原始响应数据(用于调试)
        public let rawData: [String: Any]?

        public init(text: String, isMarkdown: Bool, assistantName: String = "AI", rawData: [String: Any]? = nil) {
            self.text = text
            self.isMarkdown = isMarkdown
            self.assistantName = assistantName
            self.rawData = rawData
        }
    }

    // MARK: - 初始化

    public init() {}

    // MARK: - 公共方法

    /// 解析 AI 响应
    /// - Parameter response: 原始响应对象
    /// - Returns: 解析后的响应内容数组(支持多个 AI 响应)
    public func parseResponse(_ response: AnyObject) -> [ParsedResponse] {
        print("🔍 AEAIResponseParser - 开始解析响应: \(response)")

        var results: [ParsedResponse] = []

        // 解析响应数据
        if let dict = response as? [String: Any] {
            print("📦 响应是字典类型，键: \(dict.keys.sorted())")

            // 调试：打印完整的数据结构
            print("📊 完整数据结构：")
            debugPrintDictStructure(dict)

            // 解析 llm_responses
            if let llmResponsesArray = dict["llm_responses"] as? [[String: Any]] {
                // 格式 1: llm_responses 是数组
                print("✅ 找到 llm_responses 数组，共 \(llmResponsesArray.count) 项")
                for (index, responseDict) in llmResponsesArray.enumerated() {
                    print("📝 解析第 \(index + 1) 个响应: \(responseDict.keys.sorted())")
                    let assistantName = extractAssistantName(from: responseDict, defaultName: "AI")
                    let (text, isMarkdown) = parseResponseContent(responseDict)
                    if !text.isEmpty {
                        results.append(ParsedResponse(text: text, isMarkdown: isMarkdown, assistantName: assistantName, rawData: responseDict))
                    }
                }
            }
            else if let llmResponsesDict = dict["llm_responses"] as? [String: Any] {
                // 格式 2: llm_responses 是字典（如 {"claude": {...}, "gpt": {...}}）
                print("✅ 找到 llm_responses 字典，键: \(llmResponsesDict.keys.sorted())")

                // 按键名排序，确保解析顺序一致（优先 claude）
                let sortedKeys = llmResponsesDict.keys.sorted { key1, key2 in
                    if key1.lowercased() == "claude" { return true }
                    if key2.lowercased() == "claude" { return false }
                    return key1 < key2
                }

                for key in sortedKeys {
                    if let responseDict = llmResponsesDict[key] as? [String: Any] {
                        print("📝 解析 \(key) 响应: \(responseDict.keys.sorted())")
                        let assistantName = key.capitalized
                        let (text, isMarkdown) = parseResponseContent(responseDict)
                        if !text.isEmpty {
                            results.append(ParsedResponse(text: text, isMarkdown: isMarkdown, assistantName: assistantName, rawData: responseDict))
                        }
                    }
                }
            }
            // 兼容其他可能的数据格式
            else if let data = dict["data"] as? [String: Any] {
                print("📝 找到 data 字段，尝试解析")
                let (text, isMarkdown) = parseResponseContent(data)
                if !text.isEmpty {
                    results.append(ParsedResponse(text: text, isMarkdown: isMarkdown, rawData: dict))
                }
            }
            // 直接在根级别查找
            else {
                print("📝 在根级别查找内容")
                let (text, isMarkdown) = parseResponseContent(dict)
                if !text.isEmpty {
                    results.append(ParsedResponse(text: text, isMarkdown: isMarkdown, rawData: dict))
                }
            }

            // 如果都没找到，格式化整个字典作为 JSON
            if results.isEmpty {
                print("⚠️ 未找到标准字段，格式化整个响应")
                if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    let formattedText = "```json\n\(jsonString)\n```"
                    results.append(ParsedResponse(text: formattedText, isMarkdown: true, rawData: dict))
                } else {
                    results.append(ParsedResponse(text: "\(dict)", isMarkdown: false, rawData: dict))
                }
            }
        }
        else if let string = response as? String {
            // 如果已经是字符串
            print("✅ 响应是字符串类型")
            let isMarkdown = detectMarkdown(string)
            results.append(ParsedResponse(text: string, isMarkdown: isMarkdown))
        }
        else if let data = response as? Data, let string = String(data: data, encoding: .utf8) {
            // 如果是 Data 类型
            print("✅ 响应是 Data 类型")
            let isMarkdown = detectMarkdown(string)
            results.append(ParsedResponse(text: string, isMarkdown: isMarkdown))
        }
        else {
            // 其他类型，直接转换为字符串描述
            print("⚠️ 响应类型未知: \(type(of: response))")
            let text = "\(response)"
            results.append(ParsedResponse(text: text, isMarkdown: false))
        }

        print("✅ AEAIResponseParser - 解析完成，共 \(results.count) 个响应")
        for (index, result) in results.enumerated() {
            print("   响应 \(index + 1): \(result.assistantName)")
            print("   内容长度: \(result.text.count)")
            print("   是否 Markdown: \(result.isMarkdown)")
            print("   内容预览: \(result.text.prefix(100))...")
        }
        return results
    }

    // MARK: - 私有方法

    /// 从响应字典中提取助手名称
    private func extractAssistantName(from dict: [String: Any], defaultName: String = "AI") -> String {
        // 尝试从常见字段提取名称
        if let name = dict["model"] as? String {
            return name.capitalized
        }
        if let name = dict["assistant_name"] as? String {
            return name
        }
        if let name = dict["name"] as? String {
            return name
        }
        return defaultName
    }

    /// 解析响应内容（支持多种字段名和类型）
    /// - Parameter dict: 响应字典
    /// - Returns: (内容文本, 是否为 Markdown)
    private func parseResponseContent(_ dict: [String: Any]) -> (String, Bool) {
        // 优先级顺序尝试不同的字段名
        let fieldNames = [
            ("response", true),      // 通用字段，默认 markdown
            ("markdown", true),      // 明确的 markdown 字段
            ("content", true),       // 内容字段，默认 markdown
            ("text", false),         // 普通文本
            ("message", false),      // 消息字段
            ("answer", true),        // 答案字段
            ("result", true)         // 结果字段
        ]

        for (fieldName, defaultMarkdown) in fieldNames {
            if let value = dict[fieldName] {
                // 尝试多种类型
                if let stringValue = value as? String {
                    print("✅ 找到字段 '\(fieldName)' (String)")
                    return (stringValue, detectMarkdown(stringValue, default: defaultMarkdown))
                } else if let dictValue = value as? [String: Any] {
                    print("✅ 找到字段 '\(fieldName)' (Dictionary), 递归解析")
                    return parseResponseContent(dictValue)
                } else if let arrayValue = value as? [[String: Any]], let first = arrayValue.first {
                    print("✅ 找到字段 '\(fieldName)' (Array), 解析第一个元素")
                    return parseResponseContent(first)
                } else if let arrayValue = value as? [String], let first = arrayValue.first {
                    print("✅ 找到字段 '\(fieldName)' (String Array), 取第一个")
                    return (first, detectMarkdown(first, default: defaultMarkdown))
                } else {
                    // 其他类型，转为字符串
                    let stringValue = "\(value)"
                    print("✅ 找到字段 '\(fieldName)' (Other: \(type(of: value)))")
                    return (stringValue, detectMarkdown(stringValue, default: defaultMarkdown))
                }
            }
        }

        print("⚠️ 未找到任何已知字段")
        return ("", false)
    }

    /// 检测文本是否包含 Markdown 标记
    /// - Parameters:
    ///   - text: 待检测的文本
    ///   - default: 默认值（如果无法判断）
    /// - Returns: 是否为 Markdown
    private func detectMarkdown(_ text: String, default defaultValue: Bool = true) -> Bool {
        // 检查常见的 Markdown 标记
        let markdownPatterns = [
            "```",           // 代码块
            "##",            // 标题
            "**",            // 粗体
            "- ",            // 列表
            "* ",            // 列表
            "> ",            // 引用
            "[",             // 链接
            "`"              // 行内代码
        ]

        for pattern in markdownPatterns {
            if text.contains(pattern) {
                return true
            }
        }

        // 如果没有检测到 Markdown 标记，使用默认值
        return defaultValue
    }

    /// 调试工具：打印字典的完整结构
    /// - Parameter dict: 待打印的字典
    /// - Parameter indent: 缩进级别
    private func debugPrintDictStructure(_ dict: [String: Any], indent: Int = 0) {
        let indentStr = String(repeating: "  ", count: indent)
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            if let dictValue = value as? [String: Any] {
                print("\(indentStr)\(key): [Dictionary]")
                debugPrintDictStructure(dictValue, indent: indent + 1)
            } else if let arrayValue = value as? [[String: Any]] {
                print("\(indentStr)\(key): [Array of Dictionary] (count: \(arrayValue.count))")
                if let first = arrayValue.first {
                    debugPrintDictStructure(first, indent: indent + 1)
                }
            } else if let arrayValue = value as? [String] {
                print("\(indentStr)\(key): [Array of String] (count: \(arrayValue.count))")
                if let first = arrayValue.first {
                    print("\(indentStr)  [0]: \(first.prefix(50))...")
                }
            } else {
                let valueStr = "\(value)"
                let preview = valueStr.prefix(100)
                print("\(indentStr)\(key): \(type(of: value)) = \(preview)...")
            }
        }
    }
}
