//
//  CPGFile.swift
//  ShapefileKit
//
//  Created by Pasi Salenius on 29.12.2024.
//

import Foundation

public enum CPGFileError: Error {
    case parseError
}

public enum CodePage: String {
    case isoLatin2 = "latin2"
    case shiftJIS = "shiftjis"
    case windowsCP1250 = "1250"
    case windowsCP1251 = "1251"
    case windowsCP1252 = "1252"
    case windowsCP1253 = "1253"
    case windowsCP1254 = "1254"
    case utf8 = "UTF-8"
    case utf16 = "UTF-16"
    
    var encoding: String.Encoding {
        switch self {
        case .isoLatin2:
            return .isoLatin2
        case .shiftJIS:
            return .shiftJIS
        case .windowsCP1250:
            return .windowsCP1250
        case .windowsCP1251:
            return .windowsCP1251
        case .windowsCP1252:
            return .windowsCP1252
        case .windowsCP1253:
            return .windowsCP1253
        case .windowsCP1254:
            return .windowsCP1254
        case .utf8:
            return .utf8
        case .utf16:
            return .utf16
        }
    }
}

class CPGFile {

    static let pathExtension = "cpg"
    
    var encoding: String.Encoding
    
    init(url: URL) throws {
        let string = try String(contentsOf: url, encoding: .ascii)
        
        guard let codePage = CodePage(rawValue: string) else {
            throw CPGFileError.parseError
        }
        
        self.encoding = codePage.encoding
    }
    
}
