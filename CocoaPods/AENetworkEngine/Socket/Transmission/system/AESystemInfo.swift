import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// 系统信息模型
public struct AESystemInfo: Codable {
    /// 设备类型
    public let deviceType: String

    /// 系统名称
    public let systemName: String

    /// 系统版本
    public let systemVersion: String

    /// 应用版本
    public let appVersion: String

    /// 设备标识符
    public let deviceId: String

    /// 网络类型
    public let networkType: String

    /// 时间戳
    public let timestamp: TimeInterval

    public init() {
        #if os(iOS)
        self.deviceType = UIDevice.current.model
        self.systemName = UIDevice.current.systemName
        self.systemVersion = UIDevice.current.systemVersion
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #elseif os(macOS)
        self.deviceType = "Mac"
        self.systemName = "macOS"
        let version = ProcessInfo.processInfo.operatingSystemVersion
        self.systemVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        self.deviceId = Self.getMacDeviceId()
        #else
        self.deviceType = "Unknown"
        self.systemName = "Unknown"
        self.systemVersion = "Unknown"
        self.deviceId = "Unknown"
        #endif

        self.appVersion = Self.getAppVersion()
        self.networkType = Self.getNetworkType()
        self.timestamp = Date().timeIntervalSince1970
    }

    private static func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "1.0.0"
    }

    private static func getNetworkType() -> String {
        // 简化实现，实际可以使用 Reachability 库检测
        return "WiFi"
    }

    #if os(macOS)
    private static func getMacDeviceId() -> String {
        // 使用 MAC 地址或其他硬件标识
        let task = Process()
        task.launchPath = "/sbin/sysctl"
        task.arguments = ["kern.uuid"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        }
        return "unknown"
    }
    #endif

    /// 序列化为 JSON Data
    public func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// 从 JSON Data 反序列化
    public static func fromData(_ data: Data) -> AESystemInfo? {
        try? JSONDecoder().decode(AESystemInfo.self, from: data)
    }
}

/// 系统信息交换管理器
public class AESystemInfoManager {
    private var localInfo: AESystemInfo
    private var remoteInfo: AESystemInfo?
    private let lock = NSLock()

    public init() {
        self.localInfo = AESystemInfo()
    }

    /// 获取本地系统信息
    public func getLocalInfo() -> AESystemInfo {
        return localInfo
    }

    /// 发送系统信息
    public func sendSystemInfo(via io: AEIOProtocol, completion: ((Bool) -> Void)? = nil) {
        guard let data = localInfo.toData() else {
            completion?(false)
            return
        }

        io.send(data: data) { success, error in
            if success {
                print("[AESystemInfo] ✓ 已发送本地系统信息")
            } else {
                print("[AESystemInfo] ✗ 发送系统信息失败: \(error?.localizedDescription ?? "unknown")")
            }
            completion?(success)
        }
    }

    /// 接收并保存对端系统信息
    public func receiveSystemInfo(_ data: Data) -> Bool {
        guard let info = AESystemInfo.fromData(data) else {
            print("[AESystemInfo] ✗ 解析系统信息失败")
            return false
        }

        lock.lock()
        remoteInfo = info
        lock.unlock()

        print("[AESystemInfo] ✓ 收到对端系统信息:")
        print("  - 设备类型: \(info.deviceType)")
        print("  - 系统: \(info.systemName) \(info.systemVersion)")
        print("  - 应用版本: \(info.appVersion)")

        return true
    }

    /// 获取对端系统信息
    public func getRemoteInfo() -> AESystemInfo? {
        lock.lock()
        defer { lock.unlock() }
        return remoteInfo
    }
}
