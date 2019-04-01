//
//  CMLogging.swift
//
//  Created by DươngPQ on 29/01/2019.
//

import Foundation

public var CMLogIndent = "  "

// MARK: -

private func CMShiftDescription(_ desc: String) -> String {
    let padding = "\n\(CMLogIndent)"
    var result = desc.replacingOccurrences(of: "\n", with: padding)
    if result.count >= padding.count {
        let index = result.index(result.endIndex, offsetBy: -padding.count)
        if String(result[index...]) == padding {
            result = String(result[..<index]) + "\n"
        }
    }
    return CMLogIndent + result
}

public func CMGetDescription(_ object: Any?) -> String {
    if object == nil {
        return "〈nil〉"
    }
    if object is NSNull {
        return "〈NSNull〉"
    }
    if let number = object as? NSNumber {
        if NSStringFromClass(number.classForCoder) == "__NSCFBoolean" {
            return number.boolValue ? "〈true〉" : "〈false〉"
        }
        return "\(number)"
    }
    if let error = object as? NSError {
        var result = "ERROR: domain=\"\(error.domain)\"; code=\(error.code); \"\(error.localizedDescription)\""
        if error.userInfo.count > 0 {
            result += "; UserInfo:\n" + CMShiftDescription(CMGetDictionaryDescription(error.userInfo))
        }
        return result
    }
    if let data = object as? Data {
        return "DATA: \(data.count) bytes"
    }
    if let str = object as? String {
        return "\"\(str)\""
    }
    if let dic = object as? [AnyHashable: Any] {
        return CMGetDictionaryDescription(dic)
    }
    if let array = object as? [Any] {
        return CMGetArrayDescription(array)
    }
    if let obj = object as? NSObject {
        return obj.description
    }
    return "\(object!)"
}

public func CMGetDictionaryDescription(_ dic: [AnyHashable: Any]) -> String {
    if dic.count == 0 {
        return "〈0〉{}"
    }
    var result = "〈\(dic.count)〉{\n"
    for (key, value) in dic {
        result += CMShiftDescription("\(key) ＝ \(CMGetDescription(value))") + ";\n"
    }
    result += "}"
    return result
}

public func CMGetArrayDescription(_ array: [Any]) -> String {
    if array.count == 0 {
        return "〈0〉[]"
    }
    var result = "〈\(array.count)〉[\n"
    for item in array {
        result += CMShiftDescription(CMGetDescription(item)) + ",\n"
    }
    result = String(result[..<result.index(result.endIndex, offsetBy: -2)]) + "\n]"
    return result
}

public protocol CMLoggerClient: class {
    func log(data: String, catgory: CMLogger.LogCategory?, group: String?, date: Date, functionName: String,
             fileName: String, lineNum: Int, process: ProcessInfo, thread: mach_port_t, isMainThread: Bool)
}

/** Logger
 - Format:
 ```
 📌[Group]Category Date Time [processName:processId:threadId(m: main thread)] File [Line] Function
 Contents
 🏁
 ```
 - **Group** & **Category** may be not available.
 - Logs with **group** or **category** contained in *disabledGroup* / *disabledCategory* are ignored.
 - Content items are separated by *separator*
 */
public class CMLogger {

    public static let shared = CMLogger()

    /// How logging works
    public enum LogType {
        /// Not log
        case none
        /// Logging runs in request thread
        case sync
        /// Logging runs in custom thread
        case async(OperationQueue)
        /// Logging runs in main thread
        case main
    }

    public struct LogCategory {

        public let value: String

        public init(_ raw: String) {
            value = raw
        }
        public static let info = LogCategory("💬")
        public static let warning = LogCategory("⚠️")
        public static let critical = LogCategory("❌")
    }

    public var logDateFormat = "y-MM-dd HH:mm:ss.SSS"
    public var dateFormatter: DateFormatter = {
        let result = DateFormatter()
        result.locale = Locale.current
        result.timeZone = TimeZone.current
        result.calendar = Calendar.current
        return result
    }()
    public var separator = "\n"
    private let logQueue: OperationQueue
    public var logType: LogType
    public var disabledGroup = [String]()
    public var disabledCategory = [LogCategory]()
    public var clients = [CMLoggerClient]()

    private init() {
        logQueue = OperationQueue()
        logQueue.maxConcurrentOperationCount = 1
        logType = .async(logQueue)
    }

    private func doLog(data: [Any?], category: LogCategory?, group: String?, date: Date, threadId: mach_port_t,
                       isMain: Bool, process: ProcessInfo, functionName: String, fileName: String, lineNum: Int) {
        var result = "📌"
        if let grp = group {
            if disabledGroup.contains(grp) { return }
            result += "[\(grp)]"
        }
        if let cat = category {
            if disabledCategory.contains(where: { (item) -> Bool in
                return item.value == cat.value
            }) { return }
            result += cat.value
        }

        dateFormatter.dateFormat = logDateFormat
        result += " " + dateFormatter.string(from: date) + " [\(process.processName):\(process.processIdentifier):\(threadId)\(isMain ? "(m)" : "")]"
        result += " " + (fileName as NSString).lastPathComponent + " [\(lineNum)] " + functionName

        var content = ""
        if data.count > 0 {
            for item in data {
                if let str = item as? String {
                    content += str + separator
                } else {
                    content += CMGetDescription(item) + separator
                }
            }
            content = String(content[..<content.index(content.endIndex, offsetBy: -separator.count)])
        }

        result += "\n" + content + "\n🏁"
        print(result)
        for client in clients {
            client.log(data: content, catgory: category, group: group, date: date, functionName: functionName,
                       fileName: fileName, lineNum: lineNum, process: process, thread: threadId, isMainThread: isMain)
        }
    }

    public func log(data: [Any?], category: LogCategory?, group: String?, date: Date,
                     functionName: String, fileName: String, lineNum: Int) {
        let threadId = pthread_mach_thread_np(pthread_self())
        let isMain = Thread.isMainThread
        let process = ProcessInfo.processInfo
        switch logType {
        case .sync:
            doLog(data: data, category: category, group: group, date: date, threadId: threadId,
                  isMain: isMain, process: process, functionName: functionName, fileName: fileName, lineNum: lineNum)
        case .main:
            DispatchQueue.main.async {
                CMLogger.shared.doLog(data: data, category: category, group: group, date: date,
                                      threadId: threadId, isMain: isMain, process: process,
                                      functionName: functionName, fileName: fileName, lineNum: lineNum)
            }
        case .async(let queue):
            queue.addOperation {
                CMLogger.shared.doLog(data: data, category: category, group: group, date: date,
                                      threadId: threadId, isMain: isMain, process: process,
                                      functionName: functionName, fileName: fileName, lineNum: lineNum)
            }
        case .none:
            break
        }
    }

    public func log(block: @escaping () -> String, category: LogCategory?, group: String?, date: Date,
                     functionName: String, fileName: String, lineNum: Int) {
        let threadId = pthread_mach_thread_np(pthread_self())
        let isMain = Thread.isMainThread
        let process = ProcessInfo.processInfo
        switch logType {
        case .sync:
            doLog(data: [block()], category: category, group: group, date: date, threadId: threadId,
                  isMain: isMain, process: process, functionName: functionName, fileName: fileName, lineNum: lineNum)
        case .main:
            DispatchQueue.main.async {
                CMLogger.shared.doLog(data: [block()], category: category, group: group, date: date,
                                      threadId: threadId, isMain: isMain, process: process,
                                      functionName: functionName, fileName: fileName, lineNum: lineNum)
            }
        case .async(let queue):
            queue.addOperation {
                CMLogger.shared.doLog(data: [block()], category: category, group: group, date: date,
                                      threadId: threadId, isMain: isMain, process: process,
                                      functionName: functionName, fileName: fileName, lineNum: lineNum)
            }
        case .none:
            break
        }
    }

}

public func CMLog(_ data: Any?..., category: CMLogger.LogCategory? = nil, group: String? = nil, date: Date = Date(),
                  functionName: String = #function, fileName: String = #file, lineNum: Int = #line) {
    CMLogger.shared.log(data: data, category: category, group: group, date: date, functionName: functionName, fileName: fileName, lineNum: lineNum)
}

public func CMLog(block: @escaping () -> String, category: CMLogger.LogCategory? = nil, group: String? = nil,
                  date: Date = Date(), functionName: String = #function, fileName: String = #file, lineNum: Int = #line) {
    CMLogger.shared.log(block: block, category: category, group: group, date: date, functionName: functionName, fileName: fileName, lineNum: lineNum)
}
