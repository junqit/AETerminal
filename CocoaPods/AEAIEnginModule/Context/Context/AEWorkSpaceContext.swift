//
//  AEWorkSpaceContext.swift
//  AEAIEngin
//
//  Created by Claude on 2026/4/28.
//

import Foundation
import AENetworkEngine

/// WorkSpace Context 实现
public class AEWorkSpaceContext: AEContext {

    /// 对话列表
    public private(set) var chatList: [[String: Any]] = []

    public required init(config: AEAIContextConfig) {
        super.init(config: config)
    }

    override public func onInitialize() {
        super.onInitialize()
        
        let request = AENetReq(
            post: AEAIServicePath.chatList.rawValue
        )
        guard let delegate = delegate else { return }
        delegate.sendRequest(request, from: self)
    }

    override public func handleRsp(_ response: AENetRsp, path: String, message: [String: Any]) {
        guard path == AEAIServicePath.chatList.rawValue,
              response.code == .success,
              let rsp = message["rsp"] as? [String: Any],
              let data = rsp["data"] as? [String: Any],
              let list = data["chats"] as? [[String: Any]] else { return }

        chatList = list
    }
}
