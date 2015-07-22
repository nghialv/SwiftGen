import Foundation
//@import SwiftIdentifier
//@import SwiftGenIndentation

public final class SwiftGenL10nEnumBuilder {
    public init() {}

    public func addEntry(entry: Entry) {
        parsedLines.append(entry)
    }

    // Localizable.strings files are generally UTF16, not UTF8!
    public func parseLocalizableStringsFile(path: String) throws {
		if let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
			for (key, value) in dict {
				addEntry(Entry(key: key, value: value))
			}
			return
		}
		throw NSError(domain: "SwiftGen", code: -1, userInfo: nil)
    }
    
    public func build(enumName enumName : String = "L10n", indentation indent : SwiftGenIndentation = .Spaces(4)) -> String {
        var text = "// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen\n\n"
        let t = indent.string
        
        text += "enum \(enumName.asSwiftIdentifier()) {\n"
        
        for entry in parsedLines {
            let caseName = entry.key.asSwiftIdentifier(forbiddenChars: "_")
            text += "\(t)case \(caseName)"
            if !entry.types.isEmpty {
                text += "(" + ", ".join(entry.types.map{ $0.rawValue }) + ")"
            }
            text += "\n"
        }
        
        text += "}\n\n"
        
        text += "extension \(enumName.asSwiftIdentifier()) : CustomStringConvertible {\n"
        
        text += "\(t)var description : String { return self.string }\n\n"
        
        text += "\(t)var string : String {\n"
        text += "\(t)\(t)switch self {\n"
        
        for entry in parsedLines {
            let caseName = entry.key.asSwiftIdentifier(forbiddenChars: "_")
            text += "\(t)\(t)\(t)case .\(caseName)"
            if !entry.types.isEmpty {
                let params = (0..<entry.types.count).map { "let p\($0)" }
                text += "(" + ", ".join(params) + ")"
            }
            text += ":\n"
            text += "\(t)\(t)\(t)\(t)return \(enumName).tr(\"\(entry.key)\""
            if !entry.types.isEmpty {
                text += ", "
                let params = (0..<entry.types.count).map { "p\($0)" }
                text += ", ".join(params)
            }
            text += ")\n"
        }
        
        text += "\(t)\(t)}\n"
        text += "\(t)}\n\n"
        
        text += "\(t)private static func tr(key: String, _ args: CVarArgType...) -> String {\n"
        text += "\(t)\(t)let format = NSLocalizedString(key, comment: \"\")\n"
        text += "\(t)\(t)return String(format: format, arguments: args)\n"
        text += "\(t)}\n"
        text += "}\n\n"
        
        text += "func tr(key: \(enumName)) -> String {\n"
        text += "\(t)return key.string\n"
        text += "}\n"
        
        return text
    }
    
    
    
    // MARK: - Public Enum types
    
    public enum PlaceholderType : String {
        case String
        case Float
        case Int
        
        init?(formatChar char: Character) {
            switch char {
            case "@":
                self = .String
            case "f":
                self = .Float
            case "d", "i", "u":
                self = .Int
            default:
                return nil
            }
        }
    }
    
    public struct Entry {
        let key: String
        let types: [PlaceholderType]
        
        init(key: String, types: [PlaceholderType]) {
            self.key = key
            self.types = types
        }
        
        init(key: String, types: PlaceholderType...) {
            self.key = key
            self.types = types
        }
		
		init(key: String, value: String) {
			self.key = key
			self.types = SwiftGenL10nEnumBuilder.typesFromFormatString(value)
		}
    }
    
    
    
    // MARK: - Private Helpers
    
    private var parsedLines = [Entry]()
    
    // "I give %d apples to %@" --> [.Int, .String]
    private static func typesFromFormatString(formatString: String) -> [PlaceholderType] {
        var types = [PlaceholderType]()
        var placeholderIndex: Int? = nil
        var lastPlaceholderIndex = 0
        
        for char in formatString.characters {
            if char == "%" {
                // TODO: Manage the "%%" special sequence
                placeholderIndex = lastPlaceholderIndex++
            }
            else if placeholderIndex != nil {
                // TODO: Manage positional placeholders like "%2$@"
                //       That change the order the placeholder should be inserted in the types array
                //        (If types.count+1 < placehlderIndex, we'll need to insert "Any" types to fill the gap)
                if let type = PlaceholderType(formatChar: char) {
                    types.append(type)
                    placeholderIndex = nil
                }
                else if char == "%" {
                    // Treat it as "%%"
                    // FIXME: This case will also be executed with strings like "%--%"
                    //        Better add some more security during that parsing later
                    placeholderIndex = nil
                }
            }
        }
        
        return types
    }
}
