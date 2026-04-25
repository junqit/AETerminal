//
//  AEDBCacheEngine.swift
//  AEFoundation
//
//  基于 SQLite 数据库的缓存引擎
//

import Foundation
import SQLite3

/// 基于 SQLite 数据库的缓存引擎
public class AEDBCacheEngine: AECacheEngineProtocol {

    /// 唯一标识（用于命名空间隔离）
    private let identifier: String

    /// 数据库路径
    private let dbPath: String

    /// 数据库指针
    private var db: OpaquePointer?

    /// 初始化
    /// - Parameter identifier: 唯一标识
    public init(identifier: String) {
        self.identifier = identifier

        // 创建数据库目录：~/Library/Application Support/AEFoundation/{identifier}/
        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dbDirectory = appSupportDirectory
            .appendingPathComponent("AEFoundation")
            .appendingPathComponent(identifier)

        try? fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

        self.dbPath = dbDirectory.appendingPathComponent("cache.db").path

        // 打开数据库
        openDatabase()

        // 创建表
        createTable()
    }

    deinit {
        closeDatabase()
    }

    /// 打开数据库
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ 无法打开数据库: \(dbPath)")
        }
    }

    /// 关闭数据库
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    /// 创建表
    private func createTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS cache (
            key TEXT PRIMARY KEY,
            value BLOB NOT NULL,
            created_at INTEGER NOT NULL
        );
        """

        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableSQL, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                // 表创建成功
            } else {
                print("❌ 无法创建表")
            }
        } else {
            print("❌ SQL 准备失败")
        }
        sqlite3_finalize(createTableStatement)
    }

    public func set<T: Codable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }

        let insertSQL = """
        INSERT OR REPLACE INTO cache (key, value, created_at)
        VALUES (?, ?, ?);
        """

        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK {
            let nsData = data as NSData
            let timestamp = Int64(Date().timeIntervalSince1970)

            sqlite3_bind_text(insertStatement, 1, (key as NSString).utf8String, -1, nil)
            sqlite3_bind_blob(insertStatement, 2, nsData.bytes, Int32(nsData.length), nil)
            sqlite3_bind_int64(insertStatement, 3, timestamp)

            if sqlite3_step(insertStatement) != SQLITE_DONE {
                print("❌ 插入数据失败")
            }
        }
        sqlite3_finalize(insertStatement)
    }

    public func get<T: Codable>(_ key: String, as type: T.Type) -> T? {
        let querySQL = "SELECT value FROM cache WHERE key = ?;"

        var queryStatement: OpaquePointer?
        var result: T?

        if sqlite3_prepare_v2(db, querySQL, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (key as NSString).utf8String, -1, nil)

            if sqlite3_step(queryStatement) == SQLITE_ROW {
                if let blob = sqlite3_column_blob(queryStatement, 0) {
                    let length = sqlite3_column_bytes(queryStatement, 0)
                    let data = Data(bytes: blob, count: Int(length))
                    result = try? JSONDecoder().decode(type, from: data)
                }
            }
        }
        sqlite3_finalize(queryStatement)

        return result
    }

    public func remove(forKey key: String) {
        let deleteSQL = "DELETE FROM cache WHERE key = ?;"

        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(deleteStatement, 1, (key as NSString).utf8String, -1, nil)
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
    }

    public func removeAll() {
        let deleteAllSQL = "DELETE FROM cache;"

        var deleteAllStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteAllSQL, -1, &deleteAllStatement, nil) == SQLITE_OK {
            sqlite3_step(deleteAllStatement)
        }
        sqlite3_finalize(deleteAllStatement)
    }

    public func exists(forKey key: String) -> Bool {
        let querySQL = "SELECT COUNT(*) FROM cache WHERE key = ?;"

        var queryStatement: OpaquePointer?
        var count = 0

        if sqlite3_prepare_v2(db, querySQL, -1, &queryStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(queryStatement, 1, (key as NSString).utf8String, -1, nil)

            if sqlite3_step(queryStatement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(queryStatement, 0))
            }
        }
        sqlite3_finalize(queryStatement)

        return count > 0
    }
}
