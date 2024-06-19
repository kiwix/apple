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

/// A service to interact with zim files
extension ZimFileService {
    /// Shared ZimFileService instance
    static let shared = ZimFileService.__sharedInstance()

    /// IDs of currently opened zim files
    private var fileIDs: [UUID] { __getReaderIdentifiers().compactMap({ $0 as? UUID }) }

    // MARK: - Reader Management

    /// Open a zim file from system file URL bookmark data
    /// - Parameter bookmark: url bookmark data of the zim file to open
    /// - Returns: new url bookmark data if the one used to open the zim file is stale
    @discardableResult
    func open(fileURLBookmark data: Data) throws -> Data? {
        // resolve url
        var isStale: Bool = false
        #if os(macOS)
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            bookmarkDataIsStale: &isStale
        ) else { throw ZimFileOpenError.missing }
        #else
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale) else {
            throw ZimFileOpenError.missing
        }
        #endif

        __open(url)
        return isStale ? ZimFileService.getFileURLBookmarkData(for: url) : nil
    }

    /// Close a zim file
    /// - Parameter fileID: ID of the zim file to close
    func close(fileID: UUID) { __close(fileID) }

    // MARK: - Metadata

    static func getMetaData(url: URL) -> ZimFileMetaData? {
        __getMetaData(withFileURL: url)
    }

    // MARK: - URL System Bookmark

    /// System URL bookmark for the ZIM file itself
    /// "bookmark data that can later be resolved into a URL object for a file
    /// even if the user moves or renames it"
    /// Not to be confused with the article bookmarks
    /// - Parameter url: file system URL
    /// - Returns: data that can later be resolved into a URL object
    static func getFileURLBookmarkData(for url: URL) -> Data? {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        #if os(macOS)
        return try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        return try? url.bookmarkData(options: .minimalBookmark)
        #endif
    }

    // MARK: - URL Retrieve

    func getFileURL(zimFileID: UUID) -> URL? {
        return __getFileURL(zimFileID)
    }

    func getRedirectedURL(url: URL) -> URL? {
        guard let zimFileID = url.host,
              let zimFileID = UUID(uuidString: zimFileID),
              let redirectedPath = __getRedirectedPath(zimFileID, contentPath: url.contentPath) else { return nil }
        return URL(zimFileID: zimFileID.uuidString, contentPath: redirectedPath)
    }

    func getMainPageURL(zimFileID: UUID? = nil) -> URL? {
        guard let zimFileID = zimFileID ?? fileIDs.randomElement(),
              let path = __getMainPagePath(zimFileID) else { return nil }
        return URL(zimFileID: zimFileID.uuidString, contentPath: path)
    }

    func getRandomPageURL(zimFileID: UUID? = nil) -> URL? {
        guard let zimFileID = zimFileID ?? fileIDs.randomElement(),
              let path = __getRandomPagePath(zimFileID) else { return nil }
        return URL(zimFileID: zimFileID.uuidString, contentPath: path)
    }

    // MARK: - URL Response

    func getURLContent(url: URL) -> URLContent? {
        guard let zimFileID = url.host else { return nil }
        return getURLContent(zimFileID: zimFileID, contentPath: url.contentPath)
    }

    func getURLContent(url: URL, start: UInt, end: UInt) -> URLContent? {
        guard let zimFileID = url.host else { return nil }
        return getURLContent(zimFileID: zimFileID, contentPath: url.contentPath, start: start, end: end)
    }

    func getContentSize(url: URL) -> NSNumber? {
        guard let zimFileID = url.host,
              let zimFileUUID = UUID(uuidString: zimFileID) else { return nil }
        return __getContentSize(zimFileUUID, contentPath: url.contentPath)
    }

    func getDirectAccessInfo(url: URL) -> DirectAccessInfo? {
        guard let zimFileID = url.host,
              let zimFileUUID = UUID(uuidString: zimFileID),
              let directAccess = __getDirectAccess(zimFileUUID, contentPath: url.contentPath),
              let path: String = directAccess["path"] as? String,
              let offset: UInt = directAccess["offset"] as? UInt
        else {
            return nil
        }
        return DirectAccessInfo(path: path, offset: offset)
    }

    func getContentMetaData(url: URL) -> URLContentMetaData? {
        guard let zimFileID = url.host,
              let zimFileUUID = UUID(uuidString: zimFileID),
              let content = __getMetaData(zimFileUUID, contentPath: url.contentPath),
              let mime = content["mime"] as? String,
              let size = content["size"] as? UInt,
              let title = content["title"] as? String else { return nil }
        let zimFileModificationDate = content["zimFileDate"] as? Date
        return URLContentMetaData(
            mime: mime,
            size: size,
            zimTitle: title,
            lastModified: zimFileModificationDate
        )
    }

    func getURLContent(zimFileID: String, contentPath: String, start: UInt = 0, end: UInt = 0) -> URLContent? {
        guard let zimFileID = UUID(uuidString: zimFileID),
              let content = __getContent(zimFileID, contentPath: contentPath, start: start, end: end),
              let data = content["data"] as? Data,
              let start = content["start"] as? UInt,
              let end = content["end"] as? UInt else { return nil }
        return URLContent(data: data, start: start, end: end)
    }
}

enum ZimFileOpenError: Error {
    case missing
}
