//
//  AEWebModuleProtocol.swift
//  AEWebModule
//
//  Created on 2026/09/08.
//

import Foundation
import AEModuleCenter

/// Web 模块能力协议（继承 AEModuleProtocol；嵌入 WebView + 打开网址）
public protocol AEWebModuleProtocol: AEModuleProtocol {

    /// 嵌入用的 Web 控制器（caller 将 controller.view 嵌入自有视图层级）
    var controller: AEWebViewController { get }

    /// 打开网址（载入已嵌入的 WebView）
    /// - Parameter url: 要打开的网址
    func open(url: URL)
}
