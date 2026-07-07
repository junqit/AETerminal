import Foundation

// MARK: - AEAIContextManagerDelegate

extension AEAIEnginModule: AEAIContextManagerDelegate {

    public func contextManager(_ manager: AEAIContextManager, didAddContext context: AEAIContextInterface) {
        guard context.config.type == .workspace else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.notifyAllDelegates { delegate in
                delegate.enginModule(self, didAddContext: context)
            }
        }
    }

    public func contextManager(_ manager: AEAIContextManager, didRemoveContext context: AEAIContextInterface) {
        guard context.config.type == .workspace else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.notifyAllDelegates { delegate in
                delegate.enginModule(self, didRemoveContext: context)
            }
        }
    }

    public func contextManager(_ manager: AEAIContextManager, didChangeCurrentContext context: AEAIContextInterface) {
        guard context.config.type == .workspace else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.notifyAllDelegates { delegate in
                delegate.enginModule(self, didChangeCurrentContext: context)
            }
        }
    }

}
