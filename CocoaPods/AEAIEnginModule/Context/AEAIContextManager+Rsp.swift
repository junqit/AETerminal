import Foundation
import AENetworkEngine
import AELogProxy

/// AEAIContextManager 扩展 - 响应处理
extension AEAIContextManager {

    // MARK: - 统一接收响应

    public func handleRsp(_ response: AENetRsp) {
        
        guard let message = response.response else { return }

        let req = message["req"] as? [String: Any]
        let path = req?["path"] as? String

        switch path {
        case AEAIServicePath.createContext.rawValue:
            handleCreateContextRsp(response, message: message)
        case AEAIServicePath.contextList.rawValue:
            handleContextListRsp(response, message: message)
        default:
            handleContextMessageRsp(response, message: message)
        }
    }

    // MARK: - 响应处理

    private func handleCreateContextRsp(_ response: AENetRsp, message: [String: Any]) {
        guard response.code == .success else {
            AELog("❌ [AEAIContextManager] 服务端创建 Context 失败: code=\(response.code)")
            return
        }

        guard let cont = message["cont"] as? [String: Any],
              let ident = cont["ident"] as? String,
              let typeString = cont["type"] as? String,
              let contextType = AEAIContextConfig.AEAIContextType(rawValue: typeString) else {
            AELog("❌ [AEAIContextManager] 创建 Context 响应数据不完整")
            return
        }

        let space = cont["space"] as? String ?? ""
        let config = AEAIContextConfig(ident: ident, space: space, type: contextType)
        guard createLocalContext(config: config) != nil else {
            AELog("❌ [AEAIContextManager] 本地 Context 创建失败")
            return
        }
        AELog("[AEAIContextManager] Context 创建完成: \(ident)")
    }

    private func handleContextListRsp(_ response: AENetRsp, message: [String: Any]) {
        guard response.code == .success,
              let rsp = message["rsp"] as? [String: Any],
              let list = rsp["contexts"] as? [[String: Any]] else {
            AELog("❌ [AEAIContextManager] 获取 Context 列表失败")
            return
        }

        var hasWorkspace = false

        for item in list {
            guard let ident = item["ident"] as? String,
                  let typeString = item["type"] as? String else { continue }

            guard let contextType = AEAIContextConfig.AEAIContextType(rawValue: typeString) else {
                AELog("⚠️ [AEAIContextManager] 不支持的 Context 类型: \(typeString)")
                continue
            }

            if contextType == .directory || contextType == .permission { continue }
            if getContext(id: ident) != nil { continue }

            if contextType == .workspace { hasWorkspace = true }

            let space = item["space"] as? String ?? ""
            let config = AEAIContextConfig(ident: ident, space: space, type: contextType)
            _ = createLocalContext(config: config)
        }

        if !hasWorkspace {
            createHomeWorkspaceFromDirectory()
        }
    }

    private func createHomeWorkspaceFromDirectory() {
        var directory: AEDirectoryContext?
        contexts.read { dict in
            for value in dict.values {
                if let dir = value as? AEDirectoryContext {
                    directory = dir
                    break
                }
            }
        }

        guard let dir = directory else {
            AELog("❌ [AEAIContextManager] 未找到 Directory Context，无法创建 Home WorkSpace")
            return
        }

        let cwd = dir.contextInfo.cwd
        let config = AEAIContextConfig(ident: "", space: cwd, type: .workspace)
        createContext(config: config)
    }

    private func handleContextMessageRsp(_ response: AENetRsp, message: [String: Any]) {

        guard let cont = message["cont"] as? [String: Any],
              let contextId = cont["ident"] as? String,
              let targetContext = getContext(id: contextId) else {
            return
        }

        targetContext.receiveRsp(response)
    }
}
