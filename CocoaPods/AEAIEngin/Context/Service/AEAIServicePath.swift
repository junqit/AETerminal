//
//  aeServicePath.swift
//  aeEngin
//
//  Created on 2026/04/25.
//

import Foundation

/// ae 服务 API 路径定义，所有路径以 /ae 开头
public enum AEAIServicePath: String {
    
    case createContext = "/ae/context/create"
    case closeContext = "/ae/context/close"
    case chat = "/ae/context/chat"
    case cancel = "/ae/context/cancel"
}

