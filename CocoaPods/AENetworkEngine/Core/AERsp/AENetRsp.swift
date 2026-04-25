//
//  AENetRsp.swift
//  AENetworkEngine
//
//  Created by 田峻岐 on 2026/4/1.
//

import Foundation

/// HTTP 响应对象
public class AENetRsp {

    /// 请求唯一标识（关联 AENetReq）
    public let requestId: String

    /// 网络请求协议类型（关联 AENetReq）
    public let protocolType: AENetProtocolType

    /// 响应状态码
    public var statusCode: Int

    /// 响应头
    public var headers: [AnyHashable: Any]?

    /// 错误信息
    public var error: Error?

    private let rawData: Data?

    /// 原始响应对象
    public lazy var response: [String: Any]? = {
        return AENetRsp.dataToDictionary(data: self.rawData)
    }()

    /// 初始化方法
    public init(requestId: String,
                protocolType: AENetProtocolType,
                statusCode: Int = 0,
                headers: [AnyHashable: Any]? = nil,
                data: Data? = nil,
                error: Error? = nil) {
        self.requestId = requestId
        self.protocolType = protocolType
        self.statusCode = statusCode
        self.headers = headers
        self.error = error
        self.rawData = data
    }

    /// 判断请求是否成功
    public var isSuccess: Bool {
        return error == nil && (200..<300).contains(statusCode)
    }

    static func dataToDictionary(data: Data?) -> [String: Any]? {
        guard let data = data else { return nil }

        do {
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }

            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("JSON 解析失败: \(error)")
            return nil
        }
    }
}
