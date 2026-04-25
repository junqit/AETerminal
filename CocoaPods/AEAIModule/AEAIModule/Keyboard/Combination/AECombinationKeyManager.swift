//
//  AECombinationKeyManager.swift
//  AEAIEngin
//
//  组合键管理器 - 统一管理和分发组合键事件
//

import Cocoa

/// 组合键管理器
public class AECombinationKeyManager {

    // MARK: - Singleton

    /// 单例实例
    public static let shared = AECombinationKeyManager()

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Properties

    /// 已注册的处理器（使用弱引用避免循环引用）
    private var handlers: [WeakHandlerWrapper] = []

    /// 锁，用于保护 handlers 数组的线程安全访问
    private let handlersLock = NSLock()

    /// 是否启用调试日志
    public var enableDebugLog: Bool = false

    /// 键盘事件监听器
    private var eventMonitor: Any?

    // MARK: - Monitoring

    /// 开始监听键盘事件
    private func startMonitoring() {
        // 如果已经在监听，先停止
        stopMonitoring()

        // 添加本地事件监听器
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // 让 handleKeyEvent 判断是否需要处理
            let handled = self.handleKeyEvent(event)

            // 如果事件被处理了，直接返回 nil，不向上传递
            if handled {
                return nil
            }

            // 未被处理，继续传递
            return event
        }

        if enableDebugLog {
            print("✅ 组合键管理器开始监听键盘事件")
        }
    }

    /// 停止监听键盘事件
    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil

            if enableDebugLog {
                print("🛑 组合键管理器停止监听键盘事件")
            }
        }
    }

    // MARK: - Registration

    /// 注册组合键处理器
    /// - Parameter handler: 实现 AECombinationKeyHandler 协议的对象
    public func register(_ handler: AECombinationKeyHandler) {
        handlersLock.lock()
        defer { handlersLock.unlock() }

        // 检查是否已注册
        if handlers.contains(where: { $0.handler?.combinationKeyHandlerID == handler.combinationKeyHandlerID }) {
            if enableDebugLog {
                print("⚠️ Handler '\(handler.combinationKeyHandlerID)' 已注册")
            }
            return
        }

        // 添加到列表
        handlers.append(WeakHandlerWrapper(handler: handler))

        if enableDebugLog {
            print("✅ 注册 Handler: \(handler.combinationKeyHandlerID)")
        }

        // 清理已释放的处理器（已在锁内）
        handlers.removeAll { $0.handler == nil }
    }

    /// 注销组合键处理器
    /// - Parameter handler: 要注销的处理器
    public func unregister(_ handler: AECombinationKeyHandler) {
        handlersLock.lock()
        defer { handlersLock.unlock() }

        let countBefore = handlers.count
        handlers.removeAll { $0.handler?.combinationKeyHandlerID == handler.combinationKeyHandlerID }

        if enableDebugLog && handlers.count < countBefore {
            print("🗑️ 注销 Handler: \(handler.combinationKeyHandlerID)")
        }

        // 清理已释放的处理器（已在锁内）
        handlers.removeAll { $0.handler == nil }
    }

    /// 注销指定 ID 的处理器
    /// - Parameter handlerID: 处理器 ID
    public func unregister(handlerID: String) {
        handlersLock.lock()
        defer { handlersLock.unlock() }

        let countBefore = handlers.count
        handlers.removeAll { $0.handler?.combinationKeyHandlerID == handlerID }

        if enableDebugLog && handlers.count < countBefore {
            print("🗑️ 注销 Handler: \(handlerID)")
        }

        // 清理已释放的处理器（已在锁内）
        handlers.removeAll { $0.handler == nil }
    }

    // MARK: - Event Handling

    /// 处理组合键事件
    /// - Parameter event: 键盘事件
    /// - Returns: 是否有处理器消费了该事件
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // 获取修饰键
        let modifiers = event.modifierFlags
        let cleanModifiers = modifiers.intersection([.command, .option, .shift, .control, .function])

        // 获取按键字符
        let key = event.characters ?? ""

        // 判断是否是功能键（回车、ESC、Tab等）
        let keyCode = event.keyCode
        let isFunctionKey = keyCode == AEKeyCode.return ||
                           keyCode == AEKeyCode.enter ||
                           keyCode == AEKeyCode.escape ||
                           keyCode == AEKeyCode.tab ||
                           keyCode == AEKeyCode.delete ||
                           keyCode == AEKeyCode.forwardDelete

        // 功能键直接处理，不需要修饰键
        if isFunctionKey {
            if enableDebugLog {
                print("⌨️ 功能键事件: \(key) (keyCode: \(keyCode))")
            }
        }
        // 非功能键必须有修饰键才处理（避免拦截普通字符输入）
        else if !cleanModifiers.isEmpty {
            if enableDebugLog {
                print("🔑 组合键事件: \(formatModifiers(cleanModifiers)) + \(key)")
            }
        }
        // 既不是功能键也没有修饰键，不处理
        else {
            return false
        }

        // 获取当前所有有效的处理器（在锁内完成拷贝和清理）
        handlersLock.lock()
        handlers.removeAll { $0.handler == nil }
        let currentHandlers = handlers.compactMap { $0.handler }
        handlersLock.unlock()

        // 把组合键事件发送给所有已注册的处理器，由处理器自己判断是否消费
        for handler in currentHandlers {
            // 调用处理器，由处理器自己判断是否需要消费（例如检查焦点状态）
            let handled = handler.handleCombinationKey(event: event, modifiers: cleanModifiers, key: key)

            if handled {
                if enableDebugLog {
                    print("✅ Handler '\(handler.combinationKeyHandlerID)' 消费了事件")
                }
                return true // 有处理器消费了，停止传递
            }
        }

        if enableDebugLog {
            print("⚠️ 没有 Handler 消费该事件")
        }

        return false
    }

    // MARK: - Helpers

    /// 格式化修饰键为可读字符串
    private func formatModifiers(_ modifiers: NSEvent.ModifierFlags) -> String {
        var result: [String] = []

        if modifiers.contains(.command) {
            result.append("⌘")
        }
        if modifiers.contains(.option) {
            result.append("⌥")
        }
        if modifiers.contains(.shift) {
            result.append("⇧")
        }
        if modifiers.contains(.control) {
            result.append("⌃")
        }
        if modifiers.contains(.function) {
            result.append("Fn")
        }

        return result.joined(separator: " + ")
    }

    // MARK: - Query

    /// 获取所有已注册的处理器 ID
    public func getAllHandlerIDs() -> [String] {
        handlersLock.lock()
        defer { handlersLock.unlock() }

        handlers.removeAll { $0.handler == nil }
        return handlers.compactMap { $0.handler?.combinationKeyHandlerID }
    }
}

// MARK: - Weak Wrapper

/// 弱引用包装器（避免循环引用）
private class WeakHandlerWrapper {
    weak var handler: AECombinationKeyHandler?

    init(handler: AECombinationKeyHandler) {
        self.handler = handler
    }
}
