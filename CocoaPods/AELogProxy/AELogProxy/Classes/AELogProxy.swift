import Foundation

private let _aeLogDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
}()

public func AELog(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line) {
    let timestamp = _aeLogDateFormatter.string(from: Date())
    let fileName = (file as NSString).lastPathComponent
    let output = items.map { "\($0)" }.joined(separator: separator)
    print("[\(timestamp)][\(fileName):\(line)] \(output)", terminator: terminator)
}
