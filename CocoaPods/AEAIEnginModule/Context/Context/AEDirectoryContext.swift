//
//  AEDirectoryContext.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AENetworkEngine

/// Directory Context 实现
public class AEDirectoryContext: AEContext {

    public required init(config: AEAIContextConfig) {
        super.init(config: config)
    }

    override public func didReceiveContextInfo() {
        guard let delegate = delegate else { return }
        delegate.contextDidFinishInitialization(self)
    }
}
 
