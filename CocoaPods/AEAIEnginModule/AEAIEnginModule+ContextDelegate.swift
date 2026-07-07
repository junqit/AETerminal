import Foundation
import AENetworkEngine

// MARK: - AEAIContextDelegate

extension AEAIEnginModule: AEAIContextDelegate {

    public func sendRequest(_ request: AENetReq, from context: AEAIContextInterface) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.notifyAllDelegates { delegate in
                delegate.enginModule(self, willSendRequest: request, from: context)
            }
        }
    }

    public func didReceiveRsp(_ response: AENetRsp, from context: AEAIContextInterface) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.notifyAllDelegates { delegate in
                delegate.enginModule(self, didReceiveRsp: response, from: context)
            }
        }
    }
}
