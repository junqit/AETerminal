import Foundation

/// IO 协议 - 定义发送和接收的能力
public protocol AEIOProtocol: AnyObject {
    /// MTU 大小（Maximum Transmission Unit）
    var mtu: Int { get }

    /// 是否已连接
    var isConnected: Bool { get }

    /// 发送数据
    /// - Parameters:
    ///   - data: 要发送的数据
    ///   - completion: 完成回调
    func send(data: Data, completion: ((Bool, Error?) -> Void)?)

    /// 注册接收回调
    /// - Parameters:
    ///   - identifier: 回调标识符
    ///   - handler: 接收数据的处理器
    func registerReceiveHandler(identifier: String, handler: @escaping (Data) -> Void)

    /// 移除接收回调
    /// - Parameter identifier: 回调标识符
    func removeReceiveHandler(identifier: String)

    /// 清除所有接收回调
    func clearAllReceiveHandlers()
}

/// IO 协议扩展 - TCP 实现
extension AETCPSocketClient: AEIOProtocol {
    public var isConnected: Bool {
        return state == .connected
    }

    public var mtu: Int {
        // TCP 通常支持更大的 MTU
        return 1400
    }

    public func registerReceiveHandler(identifier: String, handler: @escaping (Data) -> Void) {
        // TCP 实现可以通过代理模式实现
        // 这里需要在 AETCPSocketClient 中添加回调管理
    }

    public func removeReceiveHandler(identifier: String) {
        // 移除指定的接收处理器
    }

    public func clearAllReceiveHandlers() {
        // 清除所有接收处理器
    }
}
