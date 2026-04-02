//
//  CommandHistoryDebugger.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/2.
//

import Foundation

/// 命令历史记录调试工具
struct CommandHistoryDebugger {

    private let manager: CommandHistoryManager

    init(manager: CommandHistoryManager = .shared) {
        self.manager = manager
    }

    // MARK: - Debug Methods

    /// 打印所有历史记录
    func printAllHistory() {
        print("━━━━━━━━━━ Command History ━━━━━━━━━━")
        print("Total: \(manager.items.count) commands")
        print("Current Index: \(manager.currentIndex)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for (index, item) in manager.items.enumerated() {
            let marker = index == manager.currentIndex ? "→" : " "
            let dateStr = formatDate(item.timestamp)
            print("\(marker) [\(index)] \(dateStr) | \(item.command)")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// 打印最近 N 条历史记录
    func printRecentHistory(count: Int = 10) {
        let recentItems = manager.getRecentCommands(count: count)

        print("━━━━━━━━━━ Recent \(count) Commands ━━━━━━━━━━")

        for (index, item) in recentItems.enumerated() {
            let dateStr = formatDate(item.timestamp)
            print("[\(index)] \(dateStr) | \(item.command)")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// 打印搜索结果
    func printSearchResults(keyword: String) {
        let results = manager.search(keyword: keyword)

        print("━━━━━━━━━━ Search: '\(keyword)' ━━━━━━━━━━")
        print("Found: \(results.count) matches")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for (index, item) in results.enumerated() {
            let dateStr = formatDate(item.timestamp)
            print("[\(index)] \(dateStr) | \(item.command)")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// 打印历史记录统计
    func printStatistics() {
        let items = manager.items

        print("━━━━━━━━━━ History Statistics ━━━━━━━━━━")
        print("Total Commands: \(items.count)")
        print("Max Capacity: \(manager.maxHistoryCount)")
        print("Usage: \(String(format: "%.1f", Double(items.count) / Double(manager.maxHistoryCount) * 100))%")

        if let oldest = items.last {
            let dateStr = formatDate(oldest.timestamp)
            print("Oldest: \(dateStr)")
        }

        if let newest = items.first {
            let dateStr = formatDate(newest.timestamp)
            print("Newest: \(dateStr)")
        }

        // 统计命令长度
        let avgLength = items.isEmpty ? 0 : items.reduce(0) { $0 + $1.command.count } / items.count
        print("Average Command Length: \(avgLength) chars")

        // 找出最长的命令
        if let longest = items.max(by: { $0.command.count < $1.command.count }) {
            print("Longest Command: \(longest.command.count) chars")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }

    /// 导出历史记录为纯文本
    func exportAsText() -> String {
        var text = "Command History Export\n"
        text += "Generated at: \(formatDate(Date()))\n"
        text += "Total: \(manager.items.count) commands\n"
        text += String(repeating: "=", count: 50) + "\n\n"

        for (index, item) in manager.items.enumerated() {
            text += "[\(index + 1)] \(formatDate(item.timestamp))\n"
            text += "\(item.command)\n\n"
        }

        return text
    }

    /// 获取历史记录统计数据
    func getStatistics() -> HistoryStatistics {
        let items = manager.items
        let avgLength = items.isEmpty ? 0 : items.reduce(0) { $0 + $1.command.count } / items.count

        return HistoryStatistics(
            totalCount: items.count,
            maxCapacity: manager.maxHistoryCount,
            averageLength: avgLength,
            oldest: items.last?.timestamp,
            newest: items.first?.timestamp
        )
    }

    // MARK: - Private Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Statistics Model

struct HistoryStatistics {
    let totalCount: Int
    let maxCapacity: Int
    let averageLength: Int
    let oldest: Date?
    let newest: Date?

    var usagePercentage: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(totalCount) / Double(maxCapacity) * 100
    }
}

// MARK: - Debug Extension

extension CommandHistoryManager {
    /// 便捷访问调试器
    var debugger: CommandHistoryDebugger {
        return CommandHistoryDebugger(manager: self)
    }
}
