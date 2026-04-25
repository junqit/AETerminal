import Foundation
import AENetworkEngine

/// AI 服务配置
public struct AEAIServiceConfig {
    /// API 请求路径
    public var apiPath: String

    /// 自定义请求头
    public var headers: [String: String]

    /// 超时时间
    public var timeout: TimeInterval

    public init(
        apiPath: String = "/ae/context/chat",
        headers: [String: String] = [:],
        timeout: TimeInterval = 60
    ) {
        self.apiPath = apiPath
        self.headers = headers
        self.timeout = timeout
    }
}

/// AI 服务，处理消息发送和响应
public class AEAIService {

    /// 服务配置
    private let config: AEAIServiceConfig

    public init(config: AEAIServiceConfig = AEAIServiceConfig()) {
        
        self.config = config
    }

    // MARK: - 发送消息

    /// 发送 AI 消息
    /// - Parameters:
    ///   - message: 消息对象
    ///   - completion: 完成回调，返回原始响应结果
    public func sendMessage(
        _ message: AEAIMessage,
        completion: @escaping (Result<AnyObject, Error>) -> Void
    ) {
        // 构建请求参数
        var parameters: [String: Any] = [
            "contextId": message.contextID,
            "session_id": message.id,
            "user_input": message.content,
            "llm_types": ["gemini", "claude"],
//            "llm_types": ["gemini"],
            "timestamp": message.timestamp.timeIntervalSince1970
        ]
        
        parameters.merge(self.config.headers) { (current, new) in new }
        
        // 创建请求
        let request = AENetReq(
            post: config.apiPath,
            parameters: parameters
        )
        request.timeout = config.timeout

        // 发送请求
        AENetHttpEngine.send(request: request) { response in
            self.handleResponse(response, completion: completion)
        }
    }

    // MARK: - 处理响应

    /// 处理网络响应
    /// - Parameters:
    ///   - response: HTTP 响应对象
    ///   - completion: 完成回调
    private func handleResponse(
        _ response: AENetRsp,
        completion: @escaping (Result<AnyObject, Error>) -> Void
    ) {
        // 检查错误
        if let error = response.error {
            completion(.failure(error))
            return
        }

        // 检查状态码
        guard response.isSuccess else {
            let error = NSError(
                domain: "AEAIService",
                code: response.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP request failed with status code: \(response.statusCode)"]
            )
            completion(.failure(error))
            return
        }

        // 返回原始响应数据（不做修改）
        if let responseData = response.response {
            completion(.success(responseData as AnyObject))
        } else {
            let error = NSError(
                domain: "AEAIService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response data"]
            )
            completion(.failure(error))
        }
    }
}

// MARK: - Error
public enum AEAIError: Error {
    case contextNotFound
    case sendMessageFailed
    case invalidResponse
    case networkError(Error)

    public var localizedDescription: String {
        switch self {
        case .contextNotFound:
            return "Context not found"
        case .sendMessageFailed:
            return "Failed to send message"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
