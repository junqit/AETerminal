//
//  AEPacketBuffer.swift
//  AENetworkEngine
//
//  Created on 2026/04/27.
//

import Foundation
import AEFoundation
import AELogProxy

/// 数据包缓冲区 - 用于缓存接收到的数据
public class AEPacketBuffer {

    // MARK: - Properties

    /// 接收缓冲区（AEAtom 原子包装）
    private let buffer = AEAtom<Data>(Data())

    // MARK: - Public Methods

    /// 追加数据到缓冲区
    public func append(_ data: Data) {
        var bufferSize = 0
        buffer.write { buf in
            buf.append(data)
            bufferSize = buf.count
        }
    }

    /// 获取数据（使用下标范围）
    public func getData(start: Int, end: Int) -> Data? {
        var result: Data?
        buffer.read { buf in
            guard start >= 0, end <= buf.count, start < end else { return }
            result = buf.subdata(in: start..<end)
        }
        return result
    }

    /// 删除数据（使用下标范围）
    public func removeData(start: Int, end: Int) {
        buffer.write { buf in
            guard start >= 0, end <= buf.count, start < end else { return }
            buf.removeSubrange(start..<end)
        }
    }

    /// 清空缓冲区
    public func clear() {
        buffer.write { buf in
            buf.removeAll()
        }
    }

    /// 获取缓冲区大小
    public var count: Int {
        var size = 0
        buffer.read { buf in
            size = buf.count
        }
        return size
    }

    // MARK: - Subscript

    /// 下标访问（单个字节）
    public subscript(index: Int) -> UInt8? {
        var result: UInt8?
        buffer.read { buf in
            guard index >= 0, index < buf.count else { return }
            result = buf[index]
        }
        return result
    }

    /// 下标访问（范围）
    public subscript(range: Range<Int>) -> Data? {
        var result: Data?
        buffer.read { buf in
            guard range.lowerBound >= 0, range.upperBound <= buf.count else { return }
            result = buf.subdata(in: range)
        }
        return result
    }
}
