//
//  AEAIEnginModule.swift
//  AEAIEnginModule
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AEModuleCenter
import AENetworkEngine
import AEAINetworkModule
import AELogProxy

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private struct WeakDelegate {
    weak var value: AEAIEnginModuleDelegate?
    init(_ value: AEAIEnginModuleDelegate) { self.value = value }
}

/// AI Engine 模块实现
public class AEAIEnginModule: NSObject, AEAIEnginModuleProtocol {

    // MARK: - Properties

    private var delegates: [WeakDelegate] = []
    private let delegateLock = NSLock()

    /// Context 管理器（懒加载，用户登录后创建）
    internal var contextManager: AEAIContextManager?

    private var networkService: AEAINetworkProtocol? {
        return AEModuleCenter.module(for: AEAINetworkProtocol.self)
    }

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - AEModuleProtocol

#if os(macOS)
    public func applicationDidFinishLaunching(_ notification: Notification) {
        
        registerNetworkListener()
    }

    public func applicationWillTerminate(_ notification: Notification) {
    }
#elseif os(iOS)
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        registerNetworkListener()
        return true
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        networkService?.removeListener(self)
    }
#endif

    // MARK: - AEAIEnginModuleProtocol

    public func addDelegate(_ delegate: AEAIEnginModuleDelegate) {
        delegateLock.lock()
        delegates.removeAll { $0.value == nil }
        if !delegates.contains(where: { $0.value === delegate }) {
            delegates.append(WeakDelegate(delegate))
        }
        delegateLock.unlock()
    }

    public func removeDelegate(_ delegate: AEAIEnginModuleDelegate) {
        delegateLock.lock()
        delegates.removeAll { $0.value == nil || $0.value === delegate }
        delegateLock.unlock()
    }

    // MARK: - AEModuleAccountProtocol

    public func userDidLogin() {
        AELog("[AEAIEnginModule] 用户已登录，初始化 ContextManager")
        setupContextManager()
    }
    

    // MARK: - AEAIEnginModuleProtocol


    // MARK: - AEAIContextManagerInterface

    public func createContext(config: AEAIContextConfig) {
        contextManager?.createContext(config: config)
    }

    public func selectContext(config: AEAIContextConfig) -> Bool {
        return contextManager?.selectContext(config: config) ?? false
    }

    public func getCurrentContext() -> AEAIContextInterface? {
        return contextManager?.getCurrentContext()
    }

    // MARK: - 处理用户输入
    public func handleInputCompleted(_ question: AEAIQuestion) {
        guard contextManager != nil else {
            AELog("❌ [AEAIEnginModule] ContextManager 未创建，用户未登录")
            return
        }

        switch question.type {
        case .command:
            guard let commandType = question.parameters?["commandType"] as? String else { return }

            switch commandType {
            case "directory":
                if let context = findContext(ofType: AEDirectoryContext.self) {
                    context.sendQuestion(question)
                }
            case "permission":
                if let context = findContext(ofType: AEPermissionContext.self) {
                    context.sendQuestion(question)
                }
            default:
                break
            }

        case .text, .search:
            guard let context = getCurrentContext() else { return }
            context.sendQuestion(question)
        }
    }

    // MARK: - Internal Methods

    internal func notifyAllDelegates(_ action: @escaping (AEAIEnginModuleDelegate) -> Void) {
        delegateLock.lock()
        let allDelegates = delegates.compactMap { $0.value }
        delegateLock.unlock()

        allDelegates.forEach { action($0) }
    }

    // MARK: - Private Methods

    private func setupContextManager() {
        guard contextManager == nil else { return }

        let manager = AEAIContextManager()
        manager.delegate = self
        manager.contextDelegate = self
        contextManager = manager
        manager.checkAndRestoreContext()
    }

    private func registerNetworkListener() {
        networkService?.addListener(self)
    }

    internal func findContext<T: AEAIContextInterface>(ofType type: T.Type) -> T? {
        return contextManager?.getAllContexts().first(where: { $0 is T }) as? T
    }
}
