//
//  LibBookmarks.swift
//  Kiwix

import Foundation

struct LibBookmarks {

    static let shared = LibBookmarks()
    private let bridge = LibBookmarksBridge()

    private init() {}

    func isBookmarked(url: URL) -> Bool {
        guard let zimID = UUID(fromZimURL: url) else { return false }
        return bridge.__isBookmarked(url, inZIM: zimID)
    }

    func addBookmark(_ bookmark: LibBookmark) {
        bridge.__add(bookmark)
    }

    func removeBookmark(_ bookmark: LibBookmark) {
        bridge.__remove(bookmark)
    }
}

extension LibBookmark {
    convenience init?(withUrl url: URL, withTitle title: String) {
        guard let zimFileID = UUID(fromZimURL: url) else { return nil }
        self.init(url, inZIM: zimFileID, withTitle: title)
    }
}

extension UUID {
    init?(fromZimURL url: URL) {
        guard let uuid = UUID(uuidString: url.host ?? "") else {
            return nil
        }
        self = uuid
    }
}
