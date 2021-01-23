//
//  ZimFile.swift
//  Kiwix
//
//  Created by Chris Li on 4/10/18.
//  Copyright © 2018 Chris Li. All rights reserved.
//

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif
import RealmSwift

class ZimFile: Object, Identifiable {
    
    // MARK: -  non-optional properties
    
    @objc dynamic var id: String = ""
    @objc dynamic var groupID: String = ""
    @objc dynamic var title: String = ""
    @objc dynamic var fileDescription: String = ""
    @objc dynamic var languageCode: String = ""
    @objc dynamic var categoryRaw: String = Category.other.rawValue
    
    // MARK: -  optional properties
    
    @objc dynamic var creator: String?
    @objc dynamic var publisher: String?
    @objc dynamic var creationDate: Date?
    @objc dynamic var downloadURL: String?
    @objc dynamic var faviconURL: String?
    @objc dynamic var faviconData: Data?
    let size = RealmOptional<Int64>()
    let articleCount = RealmOptional<Int64>()
    let mediaCount = RealmOptional<Int64>()
    
    // MARK: -  additional Properties
    
    @objc dynamic var hasDetails = false
    @objc dynamic var hasIndex = false
    @objc dynamic var hasPictures = false
    @objc dynamic var hasVideos = false
    @objc dynamic var includedInSearch = true
    
    @objc dynamic var openInPlaceURLBookmark: Data?
    @objc dynamic var stateRaw = State.remote.rawValue
    @objc dynamic var downloadTotalBytesWritten: Int64 = 0
    @objc dynamic var downloadResumeData: Data?
    @objc dynamic var downloadErrorDescription: String?
    
    // MARK: -  computed properties
    
    var shortID: String { String(id.prefix(8)) }
    var state: State {
        get { return State(rawValue: stateRaw) ?? .remote }
        set { stateRaw = newValue.rawValue }
    }
    
    var category: Category {
        get { return Category(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    // MARK: - Overrides
    
    override static func primaryKey() -> String? {
        "id"
    }
    
    override static func indexedProperties() -> [String] {
        ["name", "title", "languageCode", "categoryRaw", "creationDate", "includedInSearch", "stateRaw"]
    }
    
    // MARK: - Descriptions
    
    override var description: String {
        [self.sizeDescription, self.creationDateShortDescription, self.articleCountLongDescription]
            .compactMap({ $0 })
            .joined(separator: ", ")
    }
    
    var articleCountDescription: String? {
        guard let articleCount = self.articleCount.value else { return nil }
        return ZimFile.countFormatter.string(from: NSNumber(value: articleCount))
    }
    
    var articleCountShortDescription: String? {
        guard let articleCount = self.articleCount.value else { return nil }
        return NumberAbbrevationFormatter.string(from: Int(articleCount))
    }
    
    var articleCountLongDescription: String? {
        guard let articleCount = self.articleCount.value else { return nil }
        return NumberAbbrevationFormatter.string(from: Int(articleCount)) + (articleCount > 1 ? " articles" : " article")
    }
    
    var creationDateDescription: String? {
        guard let creationDate = creationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.dateStyle = .long
        return formatter.string(from: creationDate)
    }
    
    var creationDateShortDescription: String? {
        guard let creationDate = creationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.dateStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var mediaCountDescription: String? {
        guard let mediaCount = mediaCount.value else { return nil }
        return ZimFile.countFormatter.string(from: NSNumber(value: mediaCount))
    }
    
    var languageDescription: String? { Locale.current.localizedString(forLanguageCode: languageCode) }
    
    var sizeDescription: String? {
        guard let size = size.value else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    // MARK: - Type Definition
    
    enum State: String {
        case remote, onDevice, retained, downloadQueued, downloadInProgress, downloadPaused, downloadError
    }
    
    enum Category: String, CaseIterable, Comparable, CustomStringConvertible, Identifiable {
        case wikipedia
        case wikibooks
        case wikinews
        case wikiquote
        case wikisource
        case wikiversity
        case wikivoyage
        case wiktionary
        
        case vikidia
        case ted
        case stackExchange = "stack_exchange"
        case other
        
        static func < (lhs: ZimFile.Category, rhs: ZimFile.Category) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
        
        var id: String { self.rawValue }
        var description: String {
            switch self {
            case .wikibooks:
                return NSLocalizedString("Wikibooks", comment: "Zim File Category")
            case .wikinews:
                return NSLocalizedString("Wikinews", comment: "Zim File Category")
            case .wikipedia:
                return NSLocalizedString("Wikipedia", comment: "Zim File Category")
            case .wikiquote:
                return NSLocalizedString("Wikiquote", comment: "Zim File Category")
            case .wikisource:
                return NSLocalizedString("Wikisource", comment: "Zim File Category")
            case .wikiversity:
                return NSLocalizedString("Wikiversity", comment: "Zim File Category")
            case .wikivoyage:
                return NSLocalizedString("Wikivoyage", comment: "Zim File Category")
            case .wiktionary:
                return NSLocalizedString("Wiktionary", comment: "Zim File Category")
            case .ted:
                return NSLocalizedString("TED", comment: "Zim File Category")
            case .vikidia:
                return NSLocalizedString("Vikidia", comment: "Zim File Category")
            case .stackExchange:
                return NSLocalizedString("StackExchange", comment: "Zim File Category")
            case .other:
                return NSLocalizedString("Other", comment: "Zim File Category")
            }
        }
        
        var icon: UIImage {
            switch self {
            case .wikibooks:
                return #imageLiteral(resourceName: "Wikibooks")
            case .wikinews:
                return #imageLiteral(resourceName: "Wikinews")
            case .wikipedia:
                return #imageLiteral(resourceName: "Wikipedia")
            case .wikiquote:
                return #imageLiteral(resourceName: "Wikiquote")
            case .wikisource:
                return #imageLiteral(resourceName: "Wikisource")
            case .wikiversity:
                return #imageLiteral(resourceName: "Wikiversity")
            case .wikivoyage:
                return #imageLiteral(resourceName: "Wikivoyage")
            case .wiktionary:
                return #imageLiteral(resourceName: "Wiktionary")
            case .ted:
                return #imageLiteral(resourceName: "TED")
            case .vikidia:
                return #imageLiteral(resourceName: "Vikidia")
            case .stackExchange:
                return #imageLiteral(resourceName: "StackExchange")
            case .other:
                return #imageLiteral(resourceName: "Book")
            }
        }
        
        private var sortOrder: Int {
            switch self {
            case .wikipedia:
                return 0
            case .wikibooks:
                return 1
            case .wikinews:
                return 2
            case .wikiquote:
                return 3
            case .wikisource:
                return 4
            case .wikiversity:
                return 5
            case .wikivoyage:
                return 6
            case .wiktionary:
                return 7
            case .vikidia:
                return 8
            case .ted:
                return 9
            case .stackExchange:
                return 10
            case .other:
                return 11
            }
        }
    }
    
    class NumberAbbrevationFormatter {
        static func string(from value: Int) -> String {
            let sign = ((value < 0) ? "-" : "" )
            let abs = Swift.abs(value)
            guard abs >= 1000 else {return "\(sign)\(abs)"}
            let exp = Int(log10(Double(abs)) / log10(1000))
            let units = ["K", "M", "G", "T", "P", "E"]
            let rounded = round(10 * Double(abs) / pow(1000.0,Double(exp))) / 10;
            return "\(sign)\(rounded)\(units[exp-1])"
        }
    }
    
    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}
