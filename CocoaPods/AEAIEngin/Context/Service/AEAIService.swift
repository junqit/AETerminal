import Foundation

public enum AEAIError: Error {
    case contextNotFound
    case sendMessageFailed
    case invalidResponse
    case networkError(Error)

    public var localizedDescription: String {
        switch self {
        case .contextNotFound: return "Context not found"
        case .sendMessageFailed: return "Failed to send message"
        case .invalidResponse: return "Invalid response from server"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}
