//
//  AECloudStorageModule.swift
//  AECloudStorage
//
//  Created on 2026/09/08.
//

import Foundation
import AEModuleCenter
import AELogProxy

/// 云存储模块 - 管理多个云存储 provider 的注册与初始化（鉴权）
/// 应用启动时由 AEModuleCenter 转发 applicationDidFinishLaunching 触发自启
public final class AECloudStorageModule: NSObject, AEModuleProtocol, AECloudStorageProtocol {

    // MARK: - Properties

    /// provider 注册表（按 uid 索引）
    private var providers: [String: AEStorageInterface] = [:]

    /// 当前用户 id
    public private(set) var userId: String?

    /// 已注册 provider 数量
    public var count: Int { providers.count }

    /// 已加载（鉴权完成）provider 数量
    public var loadedCount: Int { providers.values.filter { $0.isLoaded }.count }

    /// 是否全部 provider 已加载（空注册表返回 false）
    public var isAllLoaded: Bool { !providers.isEmpty && loadedCount == count }

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    // MARK: - Registration

    /// 注册一个云存储 provider（同 uid 覆盖）
    /// - Parameter provider: 已构造的 provider（如 AEBaiduStorage）
    public func register(_ provider: AEStorageInterface) {
        providers[provider.uid] = provider
    }

    /// 注册用户 id（绑定当前云存储用户）
    /// - Parameter userId: 用户唯一标识
    public func register(userId: String) {
        self.userId = userId
    }

    /// 注销指定 uid 的 provider
    /// - Parameter uid: provider 唯一标识
    public func unregister(_ uid: String) {
        providers.removeValue(forKey: uid)
    }

    /// 清空所有 provider
    public func clear() {
        providers.removeAll()
    }

    // MARK: - Lookup

    /// 按 uid 获取 provider
    /// - Parameter uid: provider 唯一标识
    /// - Returns: 对应 provider（不存在返回 nil）
    public func provider(for uid: String) -> AEStorageInterface? {
        providers[uid]
    }

    /// 所有已注册 provider
    public var allProviders: [AEStorageInterface] { Array(providers.values) }

    /// 所有已加载（鉴权完成）provider
    public var loadedProviders: [AEStorageInterface] { providers.values.filter { $0.isLoaded } }

    // MARK: - Upload

    /// 上传文件/数据流
    /// - Parameter request: 上传描述（name=文件名、path=远端路径、source=本地路径或字节流）
    /// - Returns: provider 原始响应
    @discardableResult
    public func upload(_ request: AECloudUpload) async throws -> [String: Any] {

        guard !request.path.isEmpty else {
            AELog("⚠️ [CloudStorage] 上传失败，缺少远端路径，name:\(request.name)")
            throw NSError(domain: "AECloudStorageModule", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "缺少远端路径"])
        }

        guard let provider = providers.values.first else {
            AELog("⚠️ [CloudStorage] 上传失败，无可用 provider，name:\(request.name)")
            throw NSError(domain: "AECloudStorageModule", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "无可用 provider"])
        }

        let result: [String: Any]
        switch request.source {
        case .localPath(let localPath):
            result = try await provider.upload(localPath: localPath, remotePath: request.path)
        case .data(let data):
            let tempName = request.name.isEmpty ? "AECloudStorage-upload" : request.name
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempName)
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            result = try await provider.upload(localPath: tempURL.path, remotePath: request.path)
        }

        AELog("✅ [CloudStorage] 上传成功，name:\(request.name)，provider:\(provider.name)")
        return result
    }

    // MARK: - Provider Initialization

    /// 初始化指定 provider（执行鉴权校验；刷新 token、标记 isLoaded）
    /// - Parameter uid: provider 唯一标识
    /// - Returns: 是否鉴权成功（provider 不存在返回 false）
    @discardableResult
    public func initialize(uid: String) async -> Bool {

        guard let provider = providers[uid] else {
            AELog("⚠️ [CloudStorage] 初始化失败，provider 不存在，uid:\(uid)")
            return false
        }

        let ok = await provider.verify()
        if ok {
            AELog("✅ [CloudStorage] provider 初始化成功，name:\(provider.name)")
        } else {
            AELog("⚠️ [CloudStorage] provider 初始化失败，name:\(provider.name)")
        }

        return ok
    }

    /// 初始化全部 provider（顺序执行各 provider 的鉴权校验）
    /// - Returns: 各 provider 初始化结果 [uid: 是否成功]
    @discardableResult
    public func initializeAll() async -> [String: Bool] {

        var results: [String: Bool] = [:]

        for provider in providers.values {
            results[provider.uid] = await initialize(uid: provider.uid)
        }

        return results
    }

    // MARK: - AEModuleProtocol - Lifecycle

#if os(macOS)
    /// Application 启动完成（macOS）- 自启云存储初始化
    public func applicationDidFinishLaunching(_ notification: Notification) {
        startInitialization()
    }
#endif

#if os(iOS)
    /// Application 启动完成（iOS）- 自启云存储初始化
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        startInitialization()
        return true
    }
#endif

    // MARK: - AEModuleAccountProtocol

    /// 用户登录完成 - 触发云存储 provider 鉴权/初始化
    public func userDidLogin() {
        startInitialization()
    }

    // MARK: - Private

    /// 应用启动初期触发全量初始化（fire-and-forget）
    private func startInitialization() {

        guard #available(macOS 12.0, iOS 15.0, *) else {
            AELog("⚠️ [CloudStorage] 系统版本过低，跳过自动初始化")
            return
        }

        Task { await initializeAll() }
    }
}
