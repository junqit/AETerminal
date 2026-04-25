//
//  CommandHistoryStorage.swift
//  AETerminal
//
//  Created by 田峻岐 on 2026/4/2.
//

import Foundation

/// 命令历史记录存储协议
protocol CommandHistoryStorageProtocol {
    func save(_ items: [CommandHistoryItem]) throws
    func load() throws -> [CommandHistoryItem]
    func clear() throws
}

/// 基于文件系统的命令历史记录存储
class FileCommandHistoryStorage: CommandHistoryStorageProtocol {

    // MARK: - Properties

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init(fileName: String = "command_history.json") {
        // 获取应用支持目录
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.aeterminal"
        let appDirectory = appSupportURL.appendingPathComponent(bundleIdentifier)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        self.fileURL = appDirectory.appendingPathComponent(fileName)

        // 配置日期编码格式
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - CommandHistoryStorageProtocol

    func save(_ items: [CommandHistoryItem]) throws {
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() throws -> [CommandHistoryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([CommandHistoryItem].self, from: data)
    }

    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

/// 基于 UserDefaults 的命令历史记录存储（备选方案）
class UserDefaultsCommandHistoryStorage: CommandHistoryStorageProtocol {

    // MARK: - Properties

    private let key: String
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    init(key: String = "commandHistory", userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - CommandHistoryStorageProtocol

    func save(_ items: [CommandHistoryItem]) throws {
        let data = try encoder.encode(items)
        userDefaults.set(data, forKey: key)
    }

    func load() throws -> [CommandHistoryItem] {
        guard let data = userDefaults.data(forKey: key) else {
            return []
        }
        return try decoder.decode([CommandHistoryItem].self, from: data)
    }

    func clear() throws {
        userDefaults.removeObject(forKey: key)
    }
}
