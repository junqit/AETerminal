//
//  aeServicePath.swift
//  aeEngin
//
//  Created on 2026/04/25.
//

import Foundation

/// ae 服务 API 路径定义，所有路径以 /ae 开头
public enum AEAIServicePath: String {

    /// 创建 Context
    case createContext = "/ae/context/create"

    /// 获取 Context 信息
    case contextInfo = "/ae/context/info"

    /// 获取所有 Context 列表
    case contextList = "/ae/context/list"

    /// 获取所有对话列表
    case chatList = "/ae/context/chat/list"

    /// 发送问答消息
    case chat = "/ae/context/chat"
}

