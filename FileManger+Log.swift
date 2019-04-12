//
//  FileManger+Log.swift
//
//  Created by DươngPQ on 4/11/19.
//

import Foundation

public extension FileManager {

    private static let TypeMap: [FileAttributeType: String] = [
        FileAttributeType.typeUnknown: "?",
        FileAttributeType.typeDirectory: "D",
        FileAttributeType.typeSocket: "S",
        FileAttributeType.typeRegular: "R",
        FileAttributeType.typeBlockSpecial: "B",
        FileAttributeType.typeSymbolicLink: "L",
        FileAttributeType.typeCharacterSpecial: "C"
    ]

    private class ItemDescription {
        var name = ""
        var type: FileAttributeType?
        var typeDesc = ""
        var size = ""
        var destination: String?
        var created = ""
        var modified = ""
        var permissions = ""
        var children = [ItemDescription]()
        var error: Error?
    }

    private static func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.calendar = Calendar.current
        formatter.dateFormat = "y/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private static func getDescriptionOfItem(path: String, level: UInt, firstCol: inout Int, perCol: inout Int, sizeCol: inout Int, creCol: inout Int, modCol: inout Int) -> ItemDescription {
        let result = ItemDescription()
        result.name = (path as NSString).lastPathComponent
        let fileMan = FileManager.default
        do {
            let attr = try fileMan.attributesOfItem(atPath: path)
            if let data = attr[FileAttributeKey.type] as? FileAttributeType {
                result.type = data
                if let desc = TypeMap[data] {
                    result.typeDesc = "[\(desc)]"
                }
                if data == .typeDirectory {
                    if let subitems = try? fileMan.contentsOfDirectory(atPath: path) {
                        for subItem in subitems {
                            result.children.append(getDescriptionOfItem(path: (path as NSString).appendingPathComponent(subItem), level: level + 1, firstCol: &firstCol, perCol: &perCol, sizeCol: &sizeCol, creCol: &creCol, modCol: &modCol))
                        }
                    }
                } else if data == .typeSymbolicLink {
                    result.destination = (try? fileMan.destinationOfSymbolicLink(atPath: path)) ?? ""
                }
            }
            var len = result.typeDesc.count + 1 + result.name.count + Int(level) * 3
            if firstCol < len { firstCol = len }
            if let data = attr[FileAttributeKey.size] as? NSNumber {
                result.size = "\(data)"
                len = result.size.count
                if sizeCol < len { sizeCol = len}
            }
            if let data = attr[FileAttributeKey.creationDate] as? Date {
                result.created = "\(formatDate(date: data))"
                len = result.created.count
                if creCol < len { creCol = len}
            }
            if let data = attr[FileAttributeKey.modificationDate] as? Date {
                result.modified = "\(formatDate(date: data))"
                len = result.modified.count
                if modCol < len { modCol = len}
            }
            if let data = attr[FileAttributeKey.posixPermissions] as? NSNumber {
                result.permissions = "\(data)"
                len = result.permissions.count
                if perCol < len { perCol = len}
            }
            if result.children.count > 0 {
                result.children.sort { (left, right) -> Bool in
                    if left.type == FileAttributeType.typeDirectory && right.type != FileAttributeType.typeDirectory {
                        return true
                    }
                    if left.type != FileAttributeType.typeDirectory && right.type == FileAttributeType.typeDirectory {
                        return false
                    }
                    return left.name.compare(right.name) == .orderedAscending
                }
            }
        } catch let err {
            result.error = err
        }
        return result
    }

    private static func writeLevelPrefix(level: UInt, result: inout String, isLast: Bool, levelStatuses: inout [UInt: Bool]) {
        if isLast { levelStatuses[level] = true }
        var index: UInt = 1
        while index <= level {
            if index == level {
                result += isLast ? " └─" : " ├─"
            } else {
                if levelStatuses[index] ?? false {
                    result += "   "
                } else {
                    result += " │ "
                }
            }
            index += 1
        }
    }

    private static func writeDescriptionOfItem(item: ItemDescription, level: UInt, result: inout String, firstCol: Int, perCol: Int,
                                               sizeCol: Int, creCol: Int, modCol: Int, isLastItem: Bool, levelStatuses: inout [UInt: Bool]) {
        if let err = item.error as NSError? {
            writeLevelPrefix(level: level, result: &result, isLast: isLastItem, levelStatuses: &levelStatuses)
            result += "[🚫]" + item.name + ": "
            result += "[ERROR] " + err.localizedDescription
        } else {
            var word = ""
            writeLevelPrefix(level: level, result: &word, isLast: isLastItem, levelStatuses: &levelStatuses)
            word += item.typeDesc + " " + item.name
            CMWriteSuffix(max: firstCol, word: word, result: &result)
            result += " "
            CMWriteSuffix(max: perCol, word: item.permissions, result: &result)
            result += " "
            CMWriteSuffix(max: sizeCol, word: item.size, result: &result)
            result += " "
            CMWriteSuffix(max: creCol, word: item.created, result: &result)
            result += " "
            CMWriteSuffix(max: modCol, word: item.modified, result: &result)
            if let dest = item.destination {
                result += " ⤇ " + dest
            }
        }
        result += "\n"
        for (index, child) in item.children.enumerated() {
            levelStatuses[level + 1] = false
            writeDescriptionOfItem(item: child, level: level + 1, result: &result, firstCol: firstCol, perCol: perCol, sizeCol: sizeCol,
                                   creCol: creCol, modCol: modCol, isLastItem: index == (item.children.count - 1), levelStatuses: &levelStatuses)
        }
    }

    /// Description of App data files.
    /// To use with `po` we should use `as NSString` (`po FileManager.getAppFilesDataDescription() as NSString`)
    static func getAppFilesDataDescription() -> String {
        var rootPath = ""
        for url in FileManager.default.urls(for: .documentDirectory, in: .userDomainMask) {
            rootPath = url.deletingLastPathComponent().path
            break
        }
        var firstCol: Int = 11 // [Type] Name
        var perCol: Int = 3 // PER
        var sizeCol: Int = 4 // Size
        var creCol: Int = 7 // Created
        var modCol: Int = 8 // Modified
        let rootDesc = getDescriptionOfItem(path: rootPath, level: 0, firstCol: &firstCol, perCol: &perCol,
                                            sizeCol: &sizeCol, creCol: &creCol, modCol: &modCol)
        var result = rootPath + "\n"
        CMWriteSuffix(max: firstCol, word: "[TYPE] NAME", result: &result)
        result += " "
        CMWriteSuffix(max: perCol, word: "PER", result: &result)
        result += " "
        CMWriteSuffix(max: sizeCol, word: "SIZE", result: &result)
        result += " "
        CMWriteSuffix(max: creCol, word: "CREATED", result: &result)
        result += " "
        CMWriteSuffix(max: modCol, word: "MODIFIED", result: &result)
        result += "\n"
        CMWriteSuffix(max: firstCol, word: "", result: &result, char: "─")
        result += "┼"
        CMWriteSuffix(max: perCol, word: "", result: &result, char: "─")
        result += "┼"
        CMWriteSuffix(max: sizeCol, word: "", result: &result, char: "─")
        result += "┼"
        CMWriteSuffix(max: creCol, word: "", result: &result, char: "─")
        result += "┼"
        CMWriteSuffix(max: modCol, word: "", result: &result, char: "─")
        result += "\n"

        var levelStatuses = [UInt: Bool]()
        writeDescriptionOfItem(item: rootDesc, level: 0, result: &result, firstCol: firstCol, perCol: perCol, sizeCol: sizeCol,
                               creCol: creCol, modCol: modCol, isLastItem: false, levelStatuses: &levelStatuses)
        return result
    }

}
