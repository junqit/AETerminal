//
//  AEPacketBuffer.swift
//  AENetworkEngine
//
//  Created on 2026/04/27.
//

import Foundation

/// 数据包缓冲区 - 用于缓存接收到的数据
public class AEPacketBuffer {

    // MARK: - Properties

    /// 接收缓冲区
    private var buffer = Data()

    /// 缓冲区访问锁
    private let lock = NSLock()

    // MARK: - Public Methods

    /// 追加数据到缓冲区
    /// - Parameter data: 新接收的数据
    public func append(_ data: Data) {
        lock.lock()
        buffer.append(data)
        let bufferSize = buffer.count
        lock.unlock()

        print("📦 [Buffer] 追加数据: \(data.count) bytes, 缓冲区总大小: \(bufferSize) bytes")
    }

    /// 获取数据（使用下标范围）
    /// - Parameter range: 数据范围
    /// - Returns: 指定范围的数据，如果范围无效返回 nil
    public func getData(start: Int, end: Int) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard start >= 0, end <= buffer.count, start < end else {
            return nil
        }

        return buffer.subdata(in: start..<end)
    }

    /// 删除数据（使用下标范围）
    /// - Parameters:
    ///   - start: 开始下标
    ///   - end: 结束下标
    public func removeData(start: Int, end: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard start >= 0, end <= buffer.count, start < end else {
            return
        }

        buffer.removeSubrange(start..<end)
        print("🗑️ [Buffer] 删除 [\(start)..<\(end)]，剩余: \(buffer.count) bytes")
    }

    /// 清空缓冲区
    public func clear() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()

        print("🧹 [Buffer] 缓冲区已清空")
    }

    /// 获取缓冲区大小
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }

    // MARK: - Subscript

    /// 下标访问（单个字节）
    /// - Parameter index: 字节索引
    /// - Returns: 指定位置的字节
    public subscript(index: Int) -> UInt8? {
        lock.lock()
        defer { lock.unlock() }

        guard index >= 0, index < buffer.count else {
            return nil
        }

        return buffer[index]
    }

    /// 下标访问（范围）
    /// - Parameter range: 数据范围
    /// - Returns: 指定范围的数据
    public subscript(range: Range<Int>) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard range.lowerBound >= 0, range.upperBound <= buffer.count else {
            return nil
        }

        return buffer.subdata(in: range)
    }
}
