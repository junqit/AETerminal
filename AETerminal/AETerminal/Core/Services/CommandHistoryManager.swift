//
//  CommandHistoryManager.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/2.
//

import Foundation

/// 命令历史记录管理器
class CommandHistoryManager {

    // MARK: - Singleton

    static let shared = CommandHistoryManager()

    // MARK: - Properties

    /// 历史记录列表（索引0是最新的）
    private(set) var items: [CommandHistoryItem] = []

    /// 当前浏览索引（-1表示不在历史中）
    private(set) var currentIndex: Int = -1

    /// 最大历史记录数量
    var maxHistoryCount: Int = 100

    /// 存储服务
    private let storage: CommandHistoryStorageProtocol

    // MARK: - Initialization

    init(storage: CommandHistoryStorageProtocol = FileCommandHistoryStorage()) {
        self.storage = storage
        loadHistory()
    }

    // MARK: - Public Methods

    /// 添加新命令到历史记录
    /// - Parameter command: 命令内容
    func addCommand(_ command: String) {
        // 过滤空命令
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        // 如果和最近一条命令相同，不重复添加（可选）
        if let lastCommand = items.first, lastCommand.command == trimmedCommand {
            return
        }

        // 创建新的历史记录项
        let item = CommandHistoryItem(command: trimmedCommand)
        items.insert(item, at: 0)

        // 限制历史记录数量
        if items.count > maxHistoryCount {
            items.removeLast()
        }

        // 重置索引
        currentIndex = -1

        // 持久化
        saveHistory()
    }

    /// 获取上一条历史记录
    /// - Returns: 历史记录命令，如果没有则返回 nil
    func navigateUp() -> String? {
        guard !items.isEmpty else { return nil }

        if currentIndex < items.count - 1 {
            currentIndex += 1
            return items[currentIndex].command
        }

        return items[currentIndex].command
    }

    /// 获取下一条历史记录
    /// - Returns: 历史记录命令，如果到达最新则返回 nil
    func navigateDown() -> String? {
        guard !items.isEmpty, currentIndex > 0 else {
            if currentIndex == 0 {
                currentIndex = -1
            }
            return nil
        }

        currentIndex -= 1
        return items[currentIndex].command
    }

    /// 重置导航索引
    func resetNavigation() {
        currentIndex = -1
    }

    /// 清除所有历史记录
    func clearHistory() {
        items.removeAll()
        currentIndex = -1
        try? storage.clear()
    }

    /// 搜索历史记录
    /// - Parameter keyword: 搜索关键词
    /// - Returns: 匹配的历史记录列表
    func search(keyword: String) -> [CommandHistoryItem] {
        guard !keyword.isEmpty else { return items }
        return items.filter { $0.command.contains(keyword) }
    }

    /// 获取最近的 N 条历史记录
    /// - Parameter count: 数量
    /// - Returns: 历史记录列表
    func getRecentCommands(count: Int) -> [CommandHistoryItem] {
        return Array(items.prefix(count))
    }

    // MARK: - Private Methods

    /// 从存储加载历史记录
    private func loadHistory() {
        do {
            items = try storage.load()
        } catch {
            print("Failed to load command history: \(error)")
            items = []
        }
    }

    /// 保存历史记录到存储
    private func saveHistory() {
        do {
            try storage.save(items)
        } catch {
            print("Failed to save command history: \(error)")
        }
    }
}
