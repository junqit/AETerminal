//
//  AEAIServicePath.swift
//  AEAIEngin
//
//  Created on 2026/04/25.
//

import Foundation

/// AEAI 服务 API 路径定义，所有路径以 /aeai 开头
public enum AEAIServicePath: String {
    
    case createContext = "/aeai/context/create"
    case closeContext = "/aeai/context/close"
    case chat = "/aeai/context/chat"
    case cancel = "/aeai/context/cancel"
}

