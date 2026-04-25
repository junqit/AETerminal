//
//  AEDirectory.swift
//  AETerminal
//
//  Created by Claude on 2026/4/7.
//

import Foundation

/// 目录管理工具类
public class AEDirectory {

    /// 返回真实的用户主目录（非沙盒容器）
    /// - Returns: 用户主目录路径，如 /Users/username
    public static func homeDirectory() -> String {
        // 使用 POSIX API 获取真实的用户主目录（绕过沙盒）
        let passwordEntry = getpwuid(getuid())
        if let homeDir = passwordEntry?.pointee.pw_dir {
            return String(cString: homeDir)
        }

        // 备用方案：尝试从环境变量获取
        if let homeEnv = ProcessInfo.processInfo.environment["HOME"] {
            // 检查是否为沙盒路径
            if !homeEnv.contains("/Library/Containers/") {
                return homeEnv
            }
        }

        // 最后备用方案
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// 返回真实的 Downloads 目录
    /// - Returns: Downloads 目录路径，如 /Users/username/Downloads
    public static func downloadsDirectory() -> String {
        let home = homeDirectory()
        return (home as NSString).appendingPathComponent("Downloads")
    }

    /// 返回真实的 Documents 目录
    /// - Returns: Documents 目录路径，如 /Users/username/Documents
    public static func documentsDirectory() -> String {
        let home = homeDirectory()
        return (home as NSString).appendingPathComponent("Documents")
    }

    /// 返回真实的 Desktop 目录
    /// - Returns: Desktop 目录路径，如 /Users/username/Desktop
    public static func desktopDirectory() -> String {
        let home = homeDirectory()
        return (home as NSString).appendingPathComponent("Desktop")
    }

    /// 返回当前应用的工作目录
    /// - Returns: 当前工作目录路径
    public static func currentDirectory() -> String {
        return FileManager.default.currentDirectoryPath
    }

    /// 返回应用沙盒容器的 Documents 目录
    /// - Returns: 应用沙盒 Documents 目录路径
    public static func sandboxDocumentsDirectory() -> String? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path
    }

    /// 返回应用沙盒容器的 Application Support 目录
    /// - Returns: 应用沙盒 Application Support 目录路径
    public static func sandboxApplicationSupportDirectory() -> String? {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path
    }

    /// 获取指定目录下的子目录（不包含文件）
    /// - Parameter path: 目录路径
    /// - Returns: 子目录名称数组
    public static func subdirectories(atPath path: String) -> [String] {
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        var directories: [String] = []

        for item in contents {
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 过滤隐藏文件夹
                    if !item.hasPrefix(".") {
                        directories.append(item)
                    }
                }
            }
        }

        return directories.sorted()
    }

    /// 获取指定目录下的子目录完整路径
    /// - Parameter path: 目录路径
    /// - Returns: 子目录完整路径数组
    public static func subdirectoriesFullPath(atPath path: String) -> [String] {
        let subdirs = subdirectories(atPath: path)
        return subdirs.map { (path as NSString).appendingPathComponent($0) }
    }

    /// 创建文件夹
    /// - Parameter path: 文件夹路径
    /// - Returns: 是否创建成功
    @discardableResult
    public static func createDirectory(atPath path: String) -> Bool {
        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            print("创建文件夹失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 删除文件夹
    /// - Parameter path: 文件夹路径
    /// - Returns: 是否删除成功
    @discardableResult
    public static func deleteDirectory(atPath path: String) -> Bool {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            print("文件夹不存在: \(path)")
            return false
        }

        do {
            try fileManager.removeItem(atPath: path)
            return true
        } catch {
            print("删除文件夹失败: \(error.localizedDescription)")
            return false
        }
    }

    /// 检查路径是否存在
    /// - Parameter path: 路径
    /// - Returns: 是否存在
    public static func exists(atPath path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }

    /// 检查路径是否为目录
    /// - Parameter path: 路径
    /// - Returns: 是否为目录
    public static func isDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
