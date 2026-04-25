import Foundation

/// AI 问题管理器
internal class AEAIQuestionManager {

    /// 问题历史记录列表（索引0是最新的）
    private var questions: [AEAIQuestion] = []

    /// 当前选中的索引（0表示最新消息）
    private var currentIndex: Int = 0

    /// 最大历史记录数量
    private let maxCount: Int = 50

    /// Context ID（用于持久化）
    private let contextID: String

    /// 历史记录存储文件路径
    private var historyFileURL: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.aeterminal"
        let appDirectory = appSupportURL.appendingPathComponent(bundleIdentifier).appendingPathComponent("QuestionHistory")
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory.appendingPathComponent("questions_\(contextID).json")
    }

    init(contextID: String) {
        self.contextID = contextID
        loadQuestions()
    }

    func addQuestion(_ question: AEAIQuestion) {
        let trimmedContent = question.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        if let lastQuestion = questions.first, lastQuestion.content == trimmedContent {
            currentIndex = 0
            return
        }

        questions.insert(question, at: 0)

        if questions.count > maxCount {
            questions.removeLast()
        }

        currentIndex = 0
        saveQuestions()
    }

    func navigateUp() -> AEAIQuestion? {
        guard !questions.isEmpty else { return nil }

        currentIndex = (currentIndex + 1) % questions.count
        return questions[currentIndex]
    }

    func navigateDown() -> AEAIQuestion? {
        guard !questions.isEmpty else { return nil }

        currentIndex = (currentIndex - 1 + questions.count) % questions.count
        return questions[currentIndex]
    }

    func getCurrentQuestion() -> AEAIQuestion? {
        guard !questions.isEmpty, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var index: Int {
        return currentIndex
    }

    func resetNavigation() {
        currentIndex = 0
    }

    func clearAll() {
        questions.removeAll()
        currentIndex = 0
        try? FileManager.default.removeItem(at: historyFileURL)
    }

    func getRecent(count: Int) -> [AEAIQuestion] {
        return Array(questions.prefix(count))
    }

    func getAll() -> [AEAIQuestion] {
        return questions
    }

    private func loadQuestions() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: historyFileURL)

            if let dictArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                questions = dictArray.compactMap { dict in
                    guard let content = dict["content"] as? String else { return nil }

                    let typeString = dict["type"] as? String ?? "text"
                    let type: AEAIQuestion.QuestionType
                    switch typeString {
                    case "command":
                        type = .command
                    case "search":
                        type = .search
                    default:
                        type = .text
                    }

                    let parameters = dict["parameters"] as? [String: Any]
                    return AEAIQuestion(content: content, type: type, parameters: parameters)
                }
            }
        } catch {
            print("Failed to load question history for context \(contextID): \(error)")
            questions = []
        }
    }

    private func saveQuestions() {
        do {
            let dictArray = questions.map { $0.toDictionary() }
            let data = try JSONSerialization.data(withJSONObject: dictArray, options: .prettyPrinted)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("Failed to save question history for context \(contextID): \(error)")
        }
    }
}
