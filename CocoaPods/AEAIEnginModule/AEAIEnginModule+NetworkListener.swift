import Foundation
import AENetworkEngine
import AEAINetworkModule
import AELogProxy

// MARK: - AENetworkMessageListener

extension AEAIEnginModule: AENetworkMessageListener {

    public func didReceiveRsp(_ response: AENetRsp) {
        AELog("[AEAIEnginModule] 收到响应: requestId=\(response.requestId), code=\(response.code)")
        guard let contextManager = contextManager else { return }
        contextManager.handleRsp(response)
    }
}
