//
//  AEAtom.swift
//  AEFoundation
//
//  原子性操作包装类
//

import Foundation

/// 原子性操作包装类
/// 提供线程安全的读写操作
public final class AEAtom<T> {

    /// 内部存储的值
    private var _value: T

    /// 锁，用于保证原子性操作
    private let lock = NSLock()

    /// 初始化
    /// - Parameter value: 初始值
    public init(_ value: T) {
        self._value = value
    }

    // MARK: - Public Methods

    /// 读取值（线程安全）
    /// - Parameter block: 读取闭包，接收当前值
    public func read(_ block: (T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(_value)
    }

    /// 写入值（线程安全）
    /// - Parameter block: 写入闭包，通过 inout 参数直接修改值
    public func write(_ block: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        block(&_value)
    }
}
