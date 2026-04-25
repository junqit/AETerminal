import Foundation
import CommonCrypto
import AEModuleCenter
import AEAINetworkModule
import AENetworkEngine

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

    // MARK: - 消息发送接口

    /// 发送问题（接收 UI 发送的消息）并请求 AI 响应
    /// - Parameters:
    ///   - question: 问题对象
    ///   - completion: 完成回调，返回 AI 的原始响应结果
    public func sendQuestion(
        _ question: AEAIQuestion,
        completion: @escaping (Result<AnyObject, Error>) -> Void
    ) {
        lastUsedTime = Date()
        questionManager.addQuestion(question)

        guard let networkService = AEModuleCenter.module(for: AEAINetworkProtocol.self) else {
            let error = NSError(domain: "AEAIContext", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network service not available"])
            print("❌ AEAIContext 获取网络服务失败")
            completion(.failure(error))
            return
        }

        print("✅ AEAIContext 获取网络服务成功")

        let parameters: [String: Any] = [
            "llm_types": ["claude", "gemini"],
            "context": toDictionary(),
            "question": question.toDictionary()
        ]

        let request = AENetReq(post: AEAIServicePath.chat.rawValue, parameters: parameters, protocolType: .http)
        request.timeout = 1000

        networkService.sendRequest(request) { response in
            if let error = response.error {
                completion(.failure(error))
                return
            }

            guard response.isSuccess else {
                completion(.failure(NSError(domain: "AEAIContext", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP request failed"])))
                return
            }

            if let responseData = response.response {
                completion(.success(responseData as AnyObject))
            } else {
                completion(.failure(NSError(domain: "AEAIContext", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            }
        }
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
