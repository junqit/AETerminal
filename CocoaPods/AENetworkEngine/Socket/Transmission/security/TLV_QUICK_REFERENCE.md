# TLV 快速参考

## 长度编码速查表

| 数据长度 | 编码格式 | 字节数 | 示例 |
|---------|---------|-------|------|
| 0-127 | 短格式 | 1 | `0x0D` (13) |
| 128-255 | `0x81 LL` | 2 | `0x81 C8` (200) |
| 256-65535 | `0x82 HH LL` | 3 | `0x82 04 00` (1024) |
| 65536-16777215 | `0x83 HH MM LL` | 4 | `0x83 01 00 00` (65536) |
| >16777215 | `0x84 HH HH LL LL` | 5 | `0x84 00 01 86 A0` (100000) |

## Type 编码

| Type 范围 | 字节数 | 说明 |
|----------|-------|------|
| 0x00-0x7F | 1 | 单字节 Type |
| 0x80-0xFFFF | 2 | 双字节 Type (Big Endian) |

## 常用示例

### 1. 小字符串 (13 字节)
```
输入: "Hello, World!"
编码: 01 0D 48 65 6C 6C 6F 2C 20 57 6F 72 6C 64 21
      │  │  └─────────────────── 13 字节数据
      │  └─ 长度 13 (短格式)
      └─ Type 0x01
```

### 2. 中等数据 (200 字节)
```
编码: 02 81 C8 [200 bytes]
      │  │  │
      │  │  └─ 长度 200
      │  └─ 长格式标记 (1字节长度)
      └─ Type 0x02
```

### 3. 大数据 (1024 字节)
```
编码: 03 82 04 00 [1024 bytes]
      │  │  │  │
      │  │  └──┴─ 长度 1024 (0x0400)
      │  └─ 长格式标记 (2字节长度)
      └─ Type 0x03
```

### 4. ECC 公钥 (32 字节)
```
编码: 03 20 [32 bytes public key]
      │  │
      │  └─ 长度 32 (短格式)
      └─ Type 0x03 (公钥)
```

## 解码流程

```
1. 读取 Type (1 或 2 字节)
   └─ 检查首字节是否 >= 0x80

2. 读取 Length
   ├─ 首字节 < 0x80 → 直接就是长度
   └─ 首字节 >= 0x80 → 读取后续字节
      └─ 后续字节数 = (首字节 & 0x7F)

3. 读取 Value (Length 个字节)
```

## 代码片段

### 编码
```swift
let tlv = AETlv(type: 0x01, value: data)
let encoded = tlv.serialize()
```

### 解码单个
```swift
if let (tlv, consumed) = AETlv.deserialize(data) {
    // 使用 tlv
}
```

### 解码多个
```swift
let tlvs = AETlv.deserializeMultiple(data)
```

## 加密协商 Tag

| Tag | 名称 | 说明 |
|-----|------|------|
| 0x01 | ENCRYPTION_TYPE | 加密类型 (ECC/RSA) |
| 0x02 | PROTOCOL_VERSION | 协议版本 (1.0) |
| 0x03 | PUBLIC_KEY | 公钥数据 |
| 0x04 | SESSION_ID | 会话标识符 |
| 0x05 | TIMESTAMP | 时间戳 |

## 常见错误

❌ **错误**：直接用固定字节数解析
```swift
let type = data[0]
let length = UInt16(data[1...2])  // 错误！
```

✅ **正确**：使用标准解析
```swift
if let (tlv, _) = AETlv.deserialize(data) {
    // 正确处理
}
```

## 性能提示

- ✅ 复用 TLV 对象
- ✅ 批量解析多个 TLV
- ✅ 预分配缓冲区
- ❌ 避免频繁序列化小数据
- ❌ 避免在循环中创建临时 Data
