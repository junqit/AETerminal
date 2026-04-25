import Foundation
import CommonCrypto

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

    /// 消息管理器
    public let messageManager: AEAIMessageManager

    /// AI 服务
    private let aiService: AEAIService

    /// 配置信息
    public let config: AEContextConfig

    /// 最后使用时间（用于排序）
    public var lastUsedTime: Date?

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
        self.aiService = AEAIService(config: AEAIServiceConfig(headers: ["session_id": self.id])) // 内部创建 AI 服务
        self.messageManager = AEAIMessageManager(contextID: self.id)

        // 加载命令历史记录
        loadCommandHistory()
    }

    /// 初始化上下文（指定 ID）
    /// - Parameters:
    ///   - config: 上下文配置
    ///   - customId: 自定义的 Context ID（来自云端）
    public init(config: AEContextConfig, customId: String) {
        self.config = config
        self.dir = config.dir
        self.id = customId  // 使用云端返回的 ID
        self.aiService = AEAIService(config: AEAIServiceConfig(headers: ["session_id": self.id]))
        self.messageManager = AEAIMessageManager(contextID: self.id)

        // 加载命令历史记录
        loadCommandHistory()
    }

    // MARK: - 消息发送接口

    /// 发送问题（接收 UI 发送的消息）并请求 AI 响应
    /// - Parameters:
    ///   - question: 问题对象
    ///   - completion: 完成回调，返回 AI 的原始响应结果
    public func sendQuestion(
        _ question: AEAIQuestion,
        completion: @escaping (Result<AnyObject, Error>) -> Void
    ) {
        // 更新最后使用时间
        lastUsedTime = Date()

        // 1. 创建并保存消息
        let message = messageManager.addMessage(question.content)

        // 2. 通过 AI 服务发送消息
        aiService.sendMessage(message) { [weak self] result in
            // 3. 将响应结果不修改地返回
            completion(result)
        }
    }

    /// 添加问题（不发送请求，仅记录）
    /// - Parameter question: 问题对象
    /// - Returns: 创建的消息对象
    @discardableResult
    public func addQuestion(_ question: AEAIQuestion) -> AEAIMessage {
        return messageManager.addMessage(question.content)
    }

    // MARK: - 消息导航接口

    /// 获取上一条问题
    /// - Returns: 上一条消息，如果没有则返回 nil
    public func getPreviousQuestion() -> AEAIMessage? {
        return messageManager.getPreviousMessage()
    }

    /// 获取下一条问题
    /// - Returns: 下一条消息，如果没有则返回 nil
    public func getNextQuestion() -> AEAIMessage? {
        return messageManager.getNextMessage()
    }

    /// 获取当前问题
    /// - Returns: 当前消息，如果没有则返回 nil
    public func getCurrentQuestion() -> AEAIMessage? {
        return messageManager.getCurrentMessage()
    }

    /// 获取所有问题
    /// - Returns: 所有消息数组
    public func getAllQuestions() -> [AEAIMessage] {
        return messageManager.getAllMessages()
    }

    /// 重置消息导航索引到最新消息
    public func resetToLatestQuestion() {
        messageManager.resetToLatest()
    }

    // MARK: - Command History Methods

    /// 添加命令到历史记录
    /// - Parameter command: 命令内容
    public func addCommandToHistory(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        // 如果和最近一条命令相同，不重复添加
        if let lastCommand = commandHistory.first, lastCommand.command == trimmedCommand {
            return
        }

        // 创建新的历史记录项
        let item = CommandHistoryItem(command: trimmedCommand)
        commandHistory.insert(item, at: 0)

        // 限制历史记录数量
        if commandHistory.count > maxHistoryCount {
            commandHistory.removeLast()
        }

        // 重置索引
        currentHistoryIndex = -1

        // 持久化
        saveCommandHistory()
    }

    /// 导航到上一条历史记录
    /// - Returns: 历史记录命令，如果没有则返回 nil
    public func navigateHistoryUp() -> String? {
        guard !commandHistory.isEmpty else { return nil }

        if currentHistoryIndex < commandHistory.count - 1 {
            currentHistoryIndex += 1
            return commandHistory[currentHistoryIndex].command
        }

        return commandHistory[currentHistoryIndex].command
    }

    /// 导航到下一条历史记录
    /// - Returns: 历史记录命令，如果到达最新则返回 nil
    public func navigateHistoryDown() -> String? {
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
    public var historyIndex: Int {
        return currentHistoryIndex
    }

    /// 重置历史记录导航索引
    public func resetHistoryNavigation() {
        currentHistoryIndex = -1
    }

    /// 清除所有历史记录
    public func clearCommandHistory() {
        commandHistory.removeAll()
        currentHistoryIndex = -1
        try? FileManager.default.removeItem(at: historyFileURL)
    }

    /// 获取最近的 N 条历史记录
    /// - Parameter count: 数量
    /// - Returns: 历史记录命令列表
    public func getRecentCommands(count: Int) -> [String] {
        return Array(commandHistory.prefix(count)).map { $0.command }
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
