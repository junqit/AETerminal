import Foundation

/// TCP Socket 配置
public struct AETCPSocketConfig {
    /// 服务器地址
    public var serverHost: String

    /// 服务器端口
    public var serverPort: UInt16

    /// 连接超时时间（秒）
    public var timeout: TimeInterval

    /// 缓冲区大小（字节）
    public var bufferSize: Int

    /// 是否启用日志
    public var enableLog: Bool

    /// MTU（Maximum Transmission Unit）大小
    public var mtu: Int

    public init(
        serverHost: String,
        serverPort: UInt16 = 9999,
        timeout: TimeInterval = 10.0,
        bufferSize: Int = 8192,
        enableLog: Bool = true,
        mtu: Int = 1400
    ) {
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.timeout = timeout
        self.bufferSize = bufferSize
        self.enableLog = enableLog
        self.mtu = mtu
    }
}

/// TCP 连接状态
public enum AETCPConnectionState {
    case disconnected   // 未连接
    case connecting     // 连接中
    case connected      // 已连接
    case failed         // 连接失败
}

/// TCP 连接回调
public protocol AETCPConnectionDelegate: AnyObject {
    /// 连接状态改变
    func tcpConnection(_ client: AnyObject, didChangeState state: AETCPConnectionState)

    /// 连接成功
    func tcpConnectionDidConnect(_ client: AnyObject)

    /// 连接失败
    func tcpConnection(_ client: AnyObject, didFailWithError error: Error)

    /// 断开连接
    func tcpConnectionDidDisconnect(_ client: AnyObject)

    /// MTU 确认完成
    func tcpConnection(_ client: AnyObject, didConfirmMTU mtu: Int)

    /// 接收到数据
    func tcpConnection(_ client: AnyObject, didReceive data: Data)
}
