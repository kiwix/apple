// This file is part of Kiwix for iOS & macOS.
//
// Kiwix is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// any later version.
//
// Kiwix is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kiwix; If not, see https://www.gnu.org/licenses/.

import Combine
import CoreData

class Bookmark: NSManagedObject, Identifiable {
    var id: URL { articleURL }

    @NSManaged var articleURL: URL
    @NSManaged var thumbImageURL: URL?
    @NSManaged var title: String
    @NSManaged var snippet: String?
    @NSManaged var created: Date

    @NSManaged var zimFile: ZimFile?

    class func fetchRequest(
        predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []
    ) -> NSFetchRequest<Bookmark> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<Bookmark>
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }
}

class DownloadTask: NSManagedObject, Identifiable {
    var id: UUID { fileID }

    @NSManaged var created: Date
    @NSManaged var downloadedBytes: Int64
    @NSManaged var error: String?
    @NSManaged var fileID: UUID
    @NSManaged var resumeData: Data?
    @NSManaged var totalBytes: Int64

    @NSManaged var zimFile: ZimFile?

    class func fetchRequest(predicate: NSPredicate? = nil) -> NSFetchRequest<DownloadTask> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<DownloadTask>
        request.predicate = predicate
        return request
    }

    class func fetchRequest(fileID: UUID) -> NSFetchRequest<DownloadTask> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<DownloadTask>
        request.predicate = NSPredicate(format: "fileID == %@", fileID as CVarArg)
        return request
    }
}

struct Language: Identifiable, Comparable {
    var id: String { code }
    let code: String
    let name: String
    let count: Int

    init?(code: String, count: Int) {
        guard let name = Locale.current.localizedString(forIdentifier: code) else { return nil }
        self.code = code
        self.name = name
        self.count = count
    }

    static func < (lhs: Language, rhs: Language) -> Bool {
        switch lhs.name.caseInsensitiveCompare(rhs.name) {
        case .orderedAscending:
            return true
        case .orderedDescending:
            return false
        case .orderedSame:
            return lhs.count > rhs.count
        }
    }
}

class OutlineItem: ObservableObject, Identifiable {
    let id: String
    let index: Int
    let text: String
    let level: Int
    private(set) var children: [OutlineItem]?

    @Published var isExpanded = true

    init(id: String, index: Int, text: String, level: Int) {
        self.id = id
        self.index = index
        self.text = text
        self.level = level
    }

    convenience init(index: Int, text: String, level: Int) {
        self.init(id: String(index), index: index, text: text, level: level)
    }

    func addChild(_ item: OutlineItem) {
        if children != nil {
            children?.append(item)
        } else {
            children = [item]
        }
    }

    @discardableResult
    func removeAllChildren() -> [OutlineItem] {
        defer { children = nil }
        return children ?? []
    }
}

class Tab: NSManagedObject, Identifiable {
    @NSManaged var created: Date
    @NSManaged var interactionState: Data?
    @NSManaged var lastOpened: Date
    @NSManaged var title: String?

    @NSManaged var zimFile: ZimFile?

    class func fetchRequest(
        predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []
    ) -> NSFetchRequest<Tab> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<Tab>
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }

    class func fetchRequest(id: UUID) -> NSFetchRequest<Tab> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<Tab>
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return request
    }
}

struct URLContentMetaData {
    let mime: String
    let size: UInt
    let zimTitle: String
    let lastModified: Date?

    var httpContentType: String {
        if mime == "text/plain" {
            return "text/plain;charset=UTf-8"
        } else {
            return mime
        }
    }

    var isMediaType: Bool {
        mime.hasPrefix("video/") || mime.hasPrefix("audio/")
    }

    /// Currently using the same eTag value for everything that is the same ZIM file
    /// since all those resources were created and stored at file creation
    var eTag: String? {
        guard let lastModified else { return nil }
        return "\"\(lastModified.timeIntervalSince1970)\""
    }

    func contentRange(for requestedRange: ClosedRange<UInt>) -> String {
        "bytes \(requestedRange.lowerBound)-\(requestedRange.upperBound)/\(size)"
    }
}

extension ClosedRange<UInt> {
    var fullRangeSize: UInt {
        upperBound - lowerBound
    }
}

struct URLContent {
    let data: Data
    let start: UInt
    let end: UInt
}

struct DirectAccessInfo {
    let path: String
    let offset: UInt

    /// Optional init
    /// @see: ``zim::Item.getDirectAccessInformation()``
    /// - Parameters:
    ///   - path: filename path - cannot be empty
    ///   - offset: where the reading should start in the file
    init?(path: String, offset: UInt) {
        guard !path.isEmpty else {
            return nil
        }
        self.path = path
        self.offset = offset
    }
}

final class ZimFile: NSManagedObject, Identifiable {
    var id: UUID { fileID }

    @NSManaged var articleCount: Int64
    @NSManaged var category: String
    @NSManaged var created: Date
    @NSManaged var downloadURL: URL?
    @NSManaged var faviconData: Data?
    @NSManaged var faviconURL: URL?
    @NSManaged var fileDescription: String
    @NSManaged var fileID: UUID
    ///  System file URL, if not nil, it means it's downloaded
    @NSManaged var fileURLBookmark: Data?
    @NSManaged var flavor: String?
    @NSManaged var hasDetails: Bool
    @NSManaged var hasPictures: Bool
    @NSManaged var hasVideos: Bool
    @NSManaged var includedInSearch: Bool
    @NSManaged var isMissing: Bool
    @NSManaged var languageCode: String
    @NSManaged var mediaCount: Int64
    @NSManaged var name: String
    @NSManaged var persistentID: String
    @NSManaged var requiresServiceWorkers: Bool
    @NSManaged var size: Int64

    @NSManaged var bookmarks: Set<Bookmark>
    @NSManaged var downloadTask: DownloadTask?
    @NSManaged var tabs: Set<Tab>

    var languageCodesListed: String {
        return languageCode.split(separator: ",").compactMap { code -> String? in
            return Locale.current.localizedString(forIdentifier: String(code))
        }.joined(separator: ",")
    }

    enum Predicate {
        static let isDownloaded = NSPredicate(format: "fileURLBookmark != nil")
        static let notDownloaded = NSPredicate(format: "fileURLBookmark == nil")
        static let notMissing = NSPredicate(format: "isMissing == false")
    }

    static var openedPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
        Predicate.isDownloaded,
        Predicate.notMissing
    ])

    class func fetchRequest(
        predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor] = []
    ) -> NSFetchRequest<ZimFile> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<ZimFile>
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }

    class func fetchRequest(fileID: UUID) -> NSFetchRequest<ZimFile> {
        // swiftlint:disable:next force_cast
        let request = super.fetchRequest() as! NSFetchRequest<ZimFile>
        request.predicate = NSPredicate(format: "fileID == %@", fileID as CVarArg)
        return request
    }
}
