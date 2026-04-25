import Foundation
import Security
import CryptoKit

/// 加密算法类型
public enum AEEncryptionType: String {
    case ecc = "ECC"      // 椭圆曲线加密
    case rsa = "RSA"      // RSA 加密
}

/// TLV 格式（Type-Length-Value）- 符合标准的可变长度实现
/// Type: 1-2 字节
/// Length: 1-4 字节（使用 BER 编码）
/// Value: 根据 Length 指定的长度
public struct AETlv {
    /// Tag 类型（支持 1-2 字节）
    let type: UInt16

    /// 值数据
    let value: Data

    /// 计算的长度（字节数）
    var length: Int {
        return value.count
    }

    public init(type: UInt16, value: Data) {
        self.type = type
        self.value = value
    }

    // MARK: - 序列化
    /// 序列化为 Data
    func serialize() -> Data {
        var data = Data()

        // 1. 编码 Type（1 或 2 字节）
        if type <= 0xFF {
            // 单字节 Type
            data.append(UInt8(type))
        } else {
            // 双字节 Type (Big Endian)
            data.append(contentsOf: type.bigEndian.bytes)
        }

        // 2. 编码 Length（BER 编码）
        data.append(contentsOf: encodeLength(length))

        // 3. 添加 Value
        data.append(value)

        return data
    }

    /// 编码长度（BER/DER 编码规则）
    /// - 短格式：长度 < 128，使用 1 字节
    /// - 长格式：长度 >= 128，第一字节高位为 1，低 7 位表示后续字节数
    private func encodeLength(_ length: Int) -> Data {
        var data = Data()

        if length < 128 {
            // 短格式：0x00-0x7F
            data.append(UInt8(length))
        } else {
            // 长格式：0x81-0x84 表示后续 1-4 字节
            if length <= 0xFF {
                // 1 字节长度
                data.append(0x81)
                data.append(UInt8(length))
            } else if length <= 0xFFFF {
                // 2 字节长度
                data.append(0x82)
                data.append(contentsOf: UInt16(length).bigEndian.bytes)
            } else if length <= 0xFFFFFF {
                // 3 字节长度
                data.append(0x83)
                let bytes = UInt32(length).bigEndian.bytes
                data.append(contentsOf: bytes.suffix(3))
            } else {
                // 4 字节长度
                data.append(0x84)
                data.append(contentsOf: UInt32(length).bigEndian.bytes)
            }
        }

        return data
    }

    // MARK: - 反序列化
    /// 从 Data 反序列化
    /// - Parameter data: 原始数据
    /// - Returns: (TLV 对象, 消耗的字节数) 或 nil
    static func deserialize(_ data: Data) -> (tlv: AETlv, consumedBytes: Int)? {
        var offset = 0
        guard offset < data.count else { return nil }

        // 1. 解析 Type
        let (type, typeSize) = decodeType(data, offset: offset)
        offset += typeSize
        guard offset < data.count else { return nil }

        // 2. 解析 Length
        guard let (length, lengthSize) = decodeLength(data, offset: offset) else { return nil }
        offset += lengthSize

        // 3. 检查数据是否足够
        guard offset + length <= data.count else { return nil }

        // 4. 提取 Value
        let value = data.subdata(in: offset..<(offset + length))
        offset += length

        let tlv = AETlv(type: type, value: value)
        return (tlv, offset)
    }

    /// 解码 Type（支持 1-2 字节）
    /// - Returns: (Type 值, 消耗的字节数)
    private static func decodeType(_ data: Data, offset: Int) -> (UInt16, Int) {
        guard offset < data.count else { return (0, 0) }

        let firstByte = data[offset]

        // 判断是否为双字节 Type（第一字节的高位标志）
        // 简化处理：如果 type > 0x7F，则使用双字节
        if firstByte >= 0x80 && offset + 1 < data.count {
            // 双字节 Type
            let type = UInt16(bigEndian: data.withUnsafeBytes {
                $0.load(fromByteOffset: offset, as: UInt16.self)
            })
            return (type, 2)
        } else {
            // 单字节 Type
            return (UInt16(firstByte), 1)
        }
    }

    /// 解码 Length（BER/DER 编码）
    /// - Returns: (长度值, 消耗的字节数) 或 nil
    private static func decodeLength(_ data: Data, offset: Int) -> (Int, Int)? {
        guard offset < data.count else { return nil }

        let firstByte = data[offset]

        if firstByte < 0x80 {
            // 短格式：0x00-0x7F，直接就是长度
            return (Int(firstByte), 1)
        } else {
            // 长格式：0x81-0x84
            let numBytes = Int(firstByte & 0x7F)
            guard numBytes >= 1 && numBytes <= 4 else { return nil }
            guard offset + numBytes < data.count else { return nil }

            var length = 0
            for i in 1...numBytes {
                length = (length << 8) | Int(data[offset + i])
            }

            return (length, 1 + numBytes)
        }
    }

    // MARK: - 批量解析
    /// 解析多个 TLV
    static func deserializeMultiple(_ data: Data) -> [AETlv] {
        var tlvs: [AETlv] = []
        var offset = 0

        while offset < data.count {
            let remaining = data.subdata(in: offset..<data.count)
            guard let (tlv, consumed) = deserialize(remaining) else { break }
            tlvs.append(tlv)
            offset += consumed
        }

        return tlvs
    }
}

/// 网络加密安全模块
public class AENetSecurity {
    private var symmetricKey: SymmetricKey?
    private var encryptionType: AEEncryptionType
    private let lock = NSLock()

    public init(encryptionType: AEEncryptionType = .ecc) {
        self.encryptionType = encryptionType
    }

    // MARK: - 密钥协商
    /// 生成协商请求（发送方）
    public func generateNegotiationRequest() -> Data {
        var data = Data()

        // TLV Tag 定义
        let TAG_ENCRYPTION_TYPE: UInt16 = 0x01
        let TAG_PROTOCOL_VERSION: UInt16 = 0x02
        let TAG_PUBLIC_KEY: UInt16 = 0x03

        // 1. 加密类型 TLV
        let typeData = encryptionType.rawValue.data(using: .utf8)!
        let typeTlv = AETlv(type: TAG_ENCRYPTION_TYPE, value: typeData)
        data.append(typeTlv.serialize())

        // 2. 协议版本 TLV
        let version = "1.0"
        let versionData = version.data(using: .utf8)!
        let versionTlv = AETlv(type: TAG_PROTOCOL_VERSION, value: versionData)
        data.append(versionTlv.serialize())

        // 3. 公钥 TLV（根据加密类型生成）
        if encryptionType == .ecc {
            let privateKey = P256.KeyAgreement.PrivateKey()
            let publicKeyData = privateKey.publicKey.rawRepresentation
            let keyTlv = AETlv(type: TAG_PUBLIC_KEY, value: publicKeyData)
            data.append(keyTlv.serialize())
        }

        return data
    }

    /// 处理协商请求（接收方）
    public func handleNegotiationRequest(_ data: Data) -> Data? {
        // 使用批量解析
        let tlvs = AETlv.deserializeMultiple(data)

        var selectedType: AEEncryptionType?
        var publicKeyData: Data?

        // 解析所有 TLV
        for tlv in tlvs {
            switch tlv.type {
            case 0x01: // 加密类型
                if let typeStr = String(data: tlv.value, encoding: .utf8),
                   let type = AEEncryptionType(rawValue: typeStr) {
                    selectedType = type
                }

            case 0x02: // 协议版本
                if let version = String(data: tlv.value, encoding: .utf8) {
                    print("[AENetSecurity] 对端协议版本: \(version)")
                }

            case 0x03: // 公钥
                publicKeyData = tlv.value

            default:
                print("[AENetSecurity] ⚠️ 未知的 TLV Type: 0x\(String(format: "%02X", tlv.type))")
            }
        }

        // 生成响应
        if let type = selectedType {
            encryptionType = type

            // 完成密钥交换
            if let peerKey = publicKeyData {
                completeKeyExchange(peerPublicKey: peerKey)
            }

            return generateNegotiationResponse()
        }

        return nil
    }

    /// 生成协商响应
    private func generateNegotiationResponse() -> Data {
        var data = Data()

        // 1. 确认加密类型
        let typeData = encryptionType.rawValue.data(using: .utf8)!
        let typeTlv = AETlv(type: 0x01, value: typeData)
        data.append(typeTlv.serialize())

        // 2. 发送服务端公钥（如果需要）
        if encryptionType == .ecc {
            let privateKey = P256.KeyAgreement.PrivateKey()
            let publicKeyData = privateKey.publicKey.rawRepresentation
            let keyTlv = AETlv(type: 0x03, value: publicKeyData)
            data.append(keyTlv.serialize())
        }

        // 3. 生成对称密钥
        if symmetricKey == nil {
            symmetricKey = SymmetricKey(size: .bits256)
        }

        return data
    }

    /// 完成密钥交换
    public func completeKeyExchange(peerPublicKey: Data) {
        // 使用 ECC 进行密钥交换
        if encryptionType == .ecc {
            do {
                let peerKey = try P256.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
                let privateKey = P256.KeyAgreement.PrivateKey()
                let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)

                // 派生对称密钥
                let symmetricKeyData = sharedSecret.hkdfDerivedSymmetricKey(
                    using: SHA256.self,
                    salt: Data(),
                    sharedInfo: Data(),
                    outputByteCount: 32
                )
                symmetricKey = symmetricKeyData
            } catch {
                print("密钥交换失败: \(error)")
            }
        }
    }

    // MARK: - 加密/解密
    /// 加密数据
    public func encrypt(_ data: Data) -> Data? {
        guard let key = symmetricKey else { return nil }

        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("加密失败: \(error)")
            return nil
        }
    }

    /// 解密数据
    public func decrypt(_ data: Data) -> Data? {
        guard let key = symmetricKey else { return nil }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            print("解密失败: \(error)")
            return nil
        }
    }
}

// Helper extension
extension FixedWidthInteger {
    var bytes: [UInt8] {
        withUnsafeBytes(of: self) { Array($0) }
    }
}
