import Foundation
import CommonCrypto
import AEModuleCenter
import AEAINetworkModule
import AENetworkEngine

/// Context 数据接收代理
public protocol AEAIContextDelegate: AnyObject {
    /// 接收到网络消息
    func context(_ context: AEAIContext, didReceiveResponse response: AENetRsp)
}

/// 命令历史记录项
internal struct CommandHistoryItem: Codable {
    let id: UUID
    let command: String
    let timestamp: Date

    init(command: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.command = command
        self.timestamp = timestamp
    }
}

/// AI 对话上下文
public class AEAIContext {

    /// 唯一标识（内容的摘要）
    public let id: String

    /// 上下文目录
    public let dir: String

    /// 配置信息
    internal let config: AEContextConfig

    /// 问题管理器
    private let questionManager: AEAIQuestionManager

    /// 最后使用时间（用于排序）
    public var lastUsedTime: Date?

    /// Context 代理
    public weak var delegate: AEAIContextDelegate?

    // MARK: - Command History

    /// 命令历史记录列表（索引0是最新的）
    private var commandHistory: [CommandHistoryItem] = []

    /// 当前浏览索引（-1表示不在历史中）
    private var currentHistoryIndex: Int = -1

    /// 最大历史记录数量
    private let maxHistoryCount: Int = 100

    /// 历史记录存储文件路径
    private var historyFileURL: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.aeterminal"
        let appDirectory = appSupportURL.appendingPathComponent(bundleIdentifier).appendingPathComponent("CommandHistory")
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent("context_\(id).json")
    }

    /// 初始化上下文
    /// - Parameter config: 上下文配置
    public init(config: AEContextConfig) {
        self.config = config
        self.dir = config.dir
        self.id = Self.generateID(from: config.dir)
        self.questionManager = AEAIQuestionManager(contextID: self.id)

        loadCommandHistory()
    }

    /// 初始化上下文（指定 ID）
    /// - Parameters:
    ///   - config: 上下文配置
    ///   - customId: 自定义的 Context ID（来自云端）
    public init(config: AEContextConfig, customId: String) {
        self.config = config
        self.dir = config.dir
        self.id = customId
        self.questionManager = AEAIQuestionManager(contextID: self.id)

        loadCommandHistory()
    }

    // MARK: - Network Listener Management

    /// 注册网络监听（当 Context 变为活动状态时调用）
    public func registerNetworkListener() {
        guard let networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self) else {
            print("⚠️ AEAIContext[\(id)] 注册网络监听失败：无法获取网络服务")
            return
        }
        networkService.addListener(self)
        print("✅ AEAIContext[\(id)] 注册网络监听成功")
    }

    /// 移除网络监听（当 Context 变为非活动状态时调用）
    public func unregisterNetworkListener() {
        guard let networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self) else {
            return
        }
        networkService.removeListener(self)
        print("✅ AEAIContext[\(id)] 移除网络监听成功")
    }

    // MARK: - 消息发送接口

    /// 发送问题（接收 UI 发送的消息）并请求 AI 响应
    /// - Parameter question: 问题对象
    public func sendQuestion(_ question: AEAIQuestion) {

        lastUsedTime = Date()
        questionManager.addQuestion(question)

        let request = AENetReq(post: AEAIServicePath.chat.rawValue, parameters: nil, protocolType: .http)
        request.timeout = 1000

        guard let networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self) else {
            print("❌ AEAIContext 获取网络服务失败")
            let error = NSError(domain: "AEAIContext", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network service not available"])
            let errorResponse = AENetRsp(
                requestId: request.requestId,
                protocolType: .http,
                statusCode: -1,
                error: error
            )
            delegate?.context(self, didReceiveResponse: errorResponse)
            return
        }

        print("✅ AEAIContext 获取网络服务成功")

        // 组装请求参数，将 requestId 作为公有参数添加
        let parameters: [String: Any] = [
            "requestId": request.requestId,
            "llm_types": ["claude", "gemini"],
            "context": toDictionary(),
            "question": question.toDictionary()
        ]
        request.parameters = parameters

        // 发送请求，通过 listener 接收响应
        networkService.sendRequest(request, completion: nil)
    }

    // MARK: - Question History Methods

    /// 导航到上一条历史问题
    /// - Returns: 历史问题对象，如果没有则返回 nil
    public func navigateQuestionUp() -> AEAIQuestion? {
        return questionManager.navigateUp()
    }

    /// 导航到下一条历史问题
    /// - Returns: 历史问题对象，如果没有则返回 nil
    public func navigateQuestionDown() -> AEAIQuestion? {
        return questionManager.navigateDown()
    }

    /// 获取当前问题
    /// - Returns: 当前问题对象，如果没有则返回 nil
    public func getCurrentQuestion() -> AEAIQuestion? {
        return questionManager.getCurrentQuestion()
    }

    /// 重置问题历史导航索引
    public func resetQuestionNavigation() {
        questionManager.resetNavigation()
    }

    // MARK: - Command History Methods

    /// 添加命令到历史记录
    /// - Parameter command: 命令内容
    internal func addCommandToHistory(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        if let lastCommand = commandHistory.first, lastCommand.command == trimmedCommand {
            return
        }

        let item = CommandHistoryItem(command: trimmedCommand)
        commandHistory.insert(item, at: 0)

        if commandHistory.count > maxHistoryCount {
            commandHistory.removeLast()
        }

        currentHistoryIndex = -1
        saveCommandHistory()
    }

    /// 导航到上一条历史记录
    /// - Returns: 历史记录命令，如果没有则返回 nil
    internal func navigateHistoryUp() -> String? {
        guard !commandHistory.isEmpty else { return nil }

        if currentHistoryIndex < commandHistory.count - 1 {
            currentHistoryIndex += 1
            return commandHistory[currentHistoryIndex].command
        }

        return commandHistory[currentHistoryIndex].command
    }

    /// 导航到下一条历史记录
    /// - Returns: 历史记录命令，如果到达最新则返回 nil
    internal func navigateHistoryDown() -> String? {
        guard !commandHistory.isEmpty, currentHistoryIndex > 0 else {
            if currentHistoryIndex == 0 {
                currentHistoryIndex = -1
            }
            return nil
        }

        currentHistoryIndex -= 1
        return commandHistory[currentHistoryIndex].command
    }

    /// 获取当前历史记录索引
    internal var historyIndex: Int {
        return currentHistoryIndex
    }

    /// 重置历史记录导航索引
    internal func resetHistoryNavigation() {
        currentHistoryIndex = -1
    }

    /// 清除所有历史记录
    internal func clearCommandHistory() {
        commandHistory.removeAll()
        currentHistoryIndex = -1
        try? FileManager.default.removeItem(at: historyFileURL)
    }

    /// 获取最近的 N 条历史记录
    /// - Parameter count: 数量
    /// - Returns: 历史记录命令列表
    internal func getRecentCommands(count: Int) -> [String] {
        return Array(commandHistory.prefix(count)).map { $0.command }
    }

    /// 转换为字典
    internal func toDictionary() -> [String: Any] {
        return [
            "id": id
        ]
    }

    // MARK: - Private Command History Methods

    /// 从文件加载命令历史记录
    private func loadCommandHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            commandHistory = try decoder.decode([CommandHistoryItem].self, from: data)
        } catch {
            print("Failed to load command history for context \(id): \(error)")
            commandHistory = []
        }
    }

    /// 保存命令历史记录到文件
    private func saveCommandHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(commandHistory)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save command history for context \(id): \(error)")
        }
    }

    // MARK: - 私有方法

    /// 根据内容生成唯一标识（SHA256摘要）
    private static func generateID(from content: String) -> String {
        guard let data = content.data(using: .utf8) else {
            return UUID().uuidString
        }
        return data.sha256Hash()
    }

    // MARK: - Network Message Handling

    /// 接收网络消息（内部方法，由 AEAIContextManager 调用）
    internal func handleNetworkMessage(_ response: AENetRsp) {
        delegate?.context(self, didReceiveResponse: response)
    }
}

// MARK: - AENetworkMessageListener

extension AEAIContext: AENetworkMessageListener {

    /// 接收到网络消息
    public func didReceiveMessage(_ response: AENetRsp) {
        print("📥 AEAIContext[\(id)] 收到网络消息, requestId: \(response.response)")

        guard let message = response.response else {
            print("⚠️ 响应数据为空")
            return
        }

        // 从响应中提取 context.id
        guard let contextData = message["context"] as? [String: Any],
              let contextId = contextData["id"] as? String else {
            print("⚠️ 消息中缺少 context.id 字段")
            return
        }

        // 检查是否是发给当前 Context 的消息
        if contextId == self.id {
            print("✅ 消息属于当前 Context")
            delegate?.context(self, didReceiveResponse: response)
        } else {
            print("⚠️ 消息不属于当前 Context[\(id)]，实际为[\(contextId)]，忽略")
        }
    }
}

// MARK: - Data Extension for SHA256
extension Data {
    func sha256Hash() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
