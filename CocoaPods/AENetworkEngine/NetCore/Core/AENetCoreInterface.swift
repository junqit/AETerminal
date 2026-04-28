//
//  AENetCoreInterface.swift
//  AENetworkEngine
//
//  Created on 2026/04/28.
//

import Foundation

/// 网络核心协议 - 定义各个网络核心的公开方法
public protocol AENetCoreProtocol: AnyObject {

    /// 网络核心代理，用于接收主动推送的数据
    var delegate: AENetCoreDelegate? { get set }

    /// 发送网络请求
    /// - Parameters:
    ///   - request: 网络请求对象
    ///   - completion: 完成回调（可选），返回响应对象
    func send(request: AENetReq, completion: ((AENetRsp) -> Void)?)

    /// 网络核心类型
    var coreType: AENetworkType { get }
}

/// 网络核心代理协议 - 用于接收主动推送的数据
public protocol AENetCoreDelegate: AnyObject {

    /// 接收到主动推送的响应
    /// - Parameter response: 响应对象
    func netCore(didReceive response: AENetRsp)
}
