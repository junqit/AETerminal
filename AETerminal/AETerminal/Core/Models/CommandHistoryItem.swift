//
//  CommandHistoryItem.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/2.
//

import Foundation

/// 命令历史记录项
struct CommandHistoryItem: Codable {
    /// 唯一标识符
    let id: UUID
    /// 命令内容
    let command: String
    /// 执行时间
    let timestamp: Date

    init(command: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.command = command
        self.timestamp = timestamp
    }
}

extension CommandHistoryItem: Equatable {
    static func == (lhs: CommandHistoryItem, rhs: CommandHistoryItem) -> Bool {
        return lhs.id == rhs.id
    }
}
