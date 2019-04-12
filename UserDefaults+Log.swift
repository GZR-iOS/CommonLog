//
//  UserDefaults+Log.swift
//  CommonLog
//
//  Created by DươngPQ on 4/11/19.
//

import Foundation

public extension UserDefaults {

    private struct FieldDescription {
        var key = ""
        var type = ""
        var value = ""
    }

    private static func getPrefDescription(path: String, file: String, firstCol: inout Int, secCol: inout Int) -> [FieldDescription]? {
        if let data = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent(file)) {
            var fields = [FieldDescription]()
            for (key, value) in data {
                var data = FieldDescription()
                data.key = "\(key)"
                data.type = "[\(type(of: value))]"
                data.value = "\(CMGetDescription(value))"
                if firstCol < data.key.count {
                    firstCol = data.key.count
                }
                if secCol < data.type.count {
                    secCol = data.type.count
                }
                fields.append(data)
            }
            fields.sort { (left, right) -> Bool in
                return left.key.compare(right.key) == .orderedAscending
            }
            return fields
        }
        return nil
    }

    static func getUserDefaultsDescription() -> String {
        if let url = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Preferences"),
            let files = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            var firstCol = 0
            var secCol = 0
            var descriptions = [String: [FieldDescription]]()
            for file in files where (file as NSString).pathExtension.lowercased() == "plist" {
                if let desc = getPrefDescription(path: url.path, file: file, firstCol: &firstCol, secCol: &secCol) {
                    descriptions[file] = desc
                }
            }
            var result = ""
            let prefNames = descriptions.keys.sorted()
            for file in prefNames {
                CMWriteSuffix(max: firstCol + 3, word: "[\(file)]", result: &result, char: "─")
                result += " "
                CMWriteSuffix(max: secCol, word: "", result: &result, char: "─")
                result += " "
                CMWriteSuffix(max: 20, word: "", result: &result, char: "─")
                result += "\n"
                let fields = descriptions[file] ?? []
                for field in fields {
                    result += " • "
                    CMWriteSuffix(max: firstCol, word: field.key, result: &result)
                    result += " "
                    CMWriteSuffix(max: secCol, word: field.type, result: &result)
                    result += " " + field.value + "\n"
                }
            }
            return result
        }
        return ""
    }

}
