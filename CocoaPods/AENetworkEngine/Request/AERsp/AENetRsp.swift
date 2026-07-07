//
//  AENetRsp.swift
//  AENetworkEngine
//
//  Created by 田峻岐 on 2026/4/1.
//

import Foundation
import AELogProxy

/// 响应状态码
public enum AENetRspCode: Int {
    
    case success = 200
    case created = 201
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case timeout = 408
    case serverError = 500
    case serviceUnavailable = 503
    case unknown = -1
}

/// HTTP 响应对象
public class AENetRsp {

    /// 请求唯一标识（关联 AENetReq）
    public let requestId: String

    /// 网络请求协议类型（关联 AENetReq）
    public let protocolType: AENetProtocolType

    /// 响应状态码
    public var code: AENetRspCode

    /// 响应头
    public var headers: [AnyHashable: Any]?

    /// 所有原始流数据
    private let rawData: Data?
    
    /// 是否为完整响应（非流式中间数据）
    public var isCompleted: Bool

    /// 原始响应对象
    public lazy var response: [String: Any]? = {
        return AENetRsp.dataToDictionary(data: self.rawData)
    }()

    /// 初始化方法
    public init(requestId: String,
                protocolType: AENetProtocolType,
                code: AENetRspCode = .unknown,
                headers: [AnyHashable: Any]? = nil,
                data: Data? = nil,
                isCompleted: Bool = true) {
        
        self.requestId = requestId
        self.protocolType = protocolType
        self.code = code
        self.headers = headers
        self.rawData = data
        self.isCompleted = isCompleted
    }

    /// 从字典创建实例
    /// 数据结构: {"code":200, "cont":{...}, "req":{"requestId":"...", "path":"..."}, "user":{...}}
    public static func fromMap(_ map: [String: Any], protocolType: AENetProtocolType = .socket) -> AENetRsp? {
        guard let req = map["req"] as? [String: Any],
              let requestId = req["requestId"] as? String else {
            AELog("⚠️ [AENetRsp] fromMap: 缺少 req.requestId")
            return nil
        }

        let codeValue = map["code"] as? Int ?? -1
        let code = AENetRspCode(rawValue: codeValue) ?? .unknown

        let data = try? JSONSerialization.data(withJSONObject: map, options: [])

        return AENetRsp(
            requestId: requestId,
            protocolType: protocolType,
            code: code,
            data: data
        )
    }

    static func dataToDictionary(data: Data?) -> [String: Any]? {
        
        guard let data = data else { return nil }

        do {
            if let jsonString = String(data: data, encoding: .utf8) {
                AELog(jsonString)
            }

            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            AELog("JSON 解析失败: \(error)")
            return nil
        }
    }
}
