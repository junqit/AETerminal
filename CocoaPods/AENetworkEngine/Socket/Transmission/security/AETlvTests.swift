import Foundation

/// TLV 测试用例
public class AETlvTests {

    /// 测试短长度编码（< 128 字节）
    public static func testShortLength() {
        print("\n=== 测试短长度编码 ===")

        let value = "Hello, World!".data(using: .utf8)!
        let tlv = AETlv(type: 0x01, value: value)

        let serialized = tlv.serialize()
        print("原始数据长度: \(value.count)")
        print("序列化后: \(serialized.hexString)")

        if let (parsed, consumed) = AETlv.deserialize(serialized) {
            print("解析成功:")
            print("  - Type: 0x\(String(format: "%02X", parsed.type))")
            print("  - Length: \(parsed.length)")
            print("  - Value: \(String(data: parsed.value, encoding: .utf8) ?? "N/A")")
            print("  - 消耗字节: \(consumed)")
            print("✅ 短长度测试通过")
        } else {
            print("❌ 解析失败")
        }
    }

    /// 测试中等长度编码（128-255 字节）
    public static func testMediumLength() {
        print("\n=== 测试中等长度编码 ===")

        let value = Data(repeating: 0xAB, count: 200)
        let tlv = AETlv(type: 0x02, value: value)

        let serialized = tlv.serialize()
        print("原始数据长度: \(value.count)")
        print("序列化后大小: \(serialized.count)")
        print("前 20 字节: \(serialized.prefix(20).hexString)")

        if let (parsed, consumed) = AETlv.deserialize(serialized) {
            print("解析成功:")
            print("  - Type: 0x\(String(format: "%02X", parsed.type))")
            print("  - Length: \(parsed.length)")
            print("  - Value 前 10 字节: \(parsed.value.prefix(10).hexString)")
            print("  - 消耗字节: \(consumed)")

            if parsed.value == value {
                print("✅ 中等长度测试通过")
            } else {
                print("❌ 数据不匹配")
            }
        } else {
            print("❌ 解析失败")
        }
    }

    /// 测试长长度编码（> 255 字节）
    public static func testLongLength() {
        print("\n=== 测试长长度编码 ===")

        let value = Data(repeating: 0xCD, count: 1024)
        let tlv = AETlv(type: 0x03, value: value)

        let serialized = tlv.serialize()
        print("原始数据长度: \(value.count)")
        print("序列化后大小: \(serialized.count)")
        print("前 20 字节: \(serialized.prefix(20).hexString)")

        if let (parsed, consumed) = AETlv.deserialize(serialized) {
            print("解析成功:")
            print("  - Type: 0x\(String(format: "%02X", parsed.type))")
            print("  - Length: \(parsed.length)")
            print("  - Value 前 10 字节: \(parsed.value.prefix(10).hexString)")
            print("  - 消耗字节: \(consumed)")

            if parsed.value == value {
                print("✅ 长长度测试通过")
            } else {
                print("❌ 数据不匹配")
            }
        } else {
            print("❌ 解析失败")
        }
    }

    /// 测试双字节 Type
    public static func testTwoByteType() {
        print("\n=== 测试双字节 Type ===")

        let value = "Double byte type".data(using: .utf8)!
        let tlv = AETlv(type: 0x8001, value: value)  // 双字节 Type

        let serialized = tlv.serialize()
        print("Type: 0x\(String(format: "%04X", tlv.type))")
        print("序列化后: \(serialized.hexString)")

        if let (parsed, consumed) = AETlv.deserialize(serialized) {
            print("解析成功:")
            print("  - Type: 0x\(String(format: "%04X", parsed.type))")
            print("  - Length: \(parsed.length)")
            print("  - Value: \(String(data: parsed.value, encoding: .utf8) ?? "N/A")")
            print("  - 消耗字节: \(consumed)")

            if parsed.type == tlv.type {
                print("✅ 双字节 Type 测试通过")
            } else {
                print("❌ Type 不匹配")
            }
        } else {
            print("❌ 解析失败")
        }
    }

    /// 测试多个 TLV 连续解析
    public static func testMultipleTlvs() {
        print("\n=== 测试多个 TLV 连续解析 ===")

        var data = Data()

        // TLV 1: 加密类型
        let tlv1 = AETlv(type: 0x01, value: "ECC".data(using: .utf8)!)
        data.append(tlv1.serialize())

        // TLV 2: 版本
        let tlv2 = AETlv(type: 0x02, value: "1.0".data(using: .utf8)!)
        data.append(tlv2.serialize())

        // TLV 3: 公钥（模拟 256 位）
        let tlv3 = AETlv(type: 0x03, value: Data(repeating: 0xFF, count: 32))
        data.append(tlv3.serialize())

        print("总数据长度: \(data.count)")
        print("数据: \(data.hexString)")

        let tlvs = AETlv.deserializeMultiple(data)
        print("\n解析出 \(tlvs.count) 个 TLV:")

        for (index, tlv) in tlvs.enumerated() {
            print("\nTLV \(index + 1):")
            print("  - Type: 0x\(String(format: "%02X", tlv.type))")
            print("  - Length: \(tlv.length)")
            if tlv.length < 32 {
                print("  - Value: \(String(data: tlv.value, encoding: .utf8) ?? tlv.value.hexString)")
            } else {
                print("  - Value: \(tlv.value.prefix(10).hexString)...")
            }
        }

        if tlvs.count == 3 {
            print("\n✅ 多 TLV 解析测试通过")
        } else {
            print("\n❌ 解析数量不正确")
        }
    }

    /// 测试超大数据（4 字节长度）
    public static func testVeryLongLength() {
        print("\n=== 测试超大数据（4 字节长度）===")

        let value = Data(repeating: 0xEF, count: 100_000)
        let tlv = AETlv(type: 0x04, value: value)

        let serialized = tlv.serialize()
        print("原始数据长度: \(value.count)")
        print("序列化后大小: \(serialized.count)")
        print("前 20 字节: \(serialized.prefix(20).hexString)")

        if let (parsed, consumed) = AETlv.deserialize(serialized) {
            print("解析成功:")
            print("  - Type: 0x\(String(format: "%02X", parsed.type))")
            print("  - Length: \(parsed.length)")
            print("  - 消耗字节: \(consumed)")

            if parsed.value.count == value.count {
                print("✅ 超大数据测试通过")
            } else {
                print("❌ 数据长度不匹配")
            }
        } else {
            print("❌ 解析失败")
        }
    }

    /// 运行所有测试
    public static func runAllTests() {
        print("========================================")
        print("        TLV 标准实现测试")
        print("========================================")

        testShortLength()
        testMediumLength()
        testLongLength()
        testTwoByteType()
        testMultipleTlvs()
        testVeryLongLength()

        print("\n========================================")
        print("           测试完成")
        print("========================================")
    }
}

// MARK: - Data Extension
extension Data {
    var hexString: String {
        return map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

// MARK: - 使用示例
/*
 // 运行所有测试
 AETlvTests.runAllTests()

 // 单独测试
 AETlvTests.testShortLength()
 AETlvTests.testMultipleTlvs()
 */
