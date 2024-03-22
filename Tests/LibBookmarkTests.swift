//
//  LibBookmarkTests.swift
//  UnitTests

import XCTest
@testable import Kiwix

final class LibBookmarkTests: XCTestCase {

    private let testZimURL: URL = Bundle(for: LibBookmarkTests.self).url(forResource: "test_small", withExtension: "zim")!
    private let testTitle: String = "Dionysius of Halicarnassus On Literary Composition"
    private let bookmarkURL = URL(string: "kiwix://FF7D59DE-0FD8-F486-09FA-C57904646707/A/Dionysius%20of%20Halicarnassus%20On%20Literary%20Composition.50212.html")!

    func testIfZimFileExists() throws {
        XCTAssertNotNil(testZimURL)
    }

    func testAddingBookmark() {
        let fileURLData = ZimFileService.getFileURLBookmarkData(for: testZimURL)!
        try! ZimFileService.shared.open(fileURLBookmark: fileURLData)
        let bookmarks = LibBookmarks.shared
        XCTAssertFalse(bookmarks.isBookmarked(url: bookmarkURL))

        let bookmark = LibBookmark(withUrl: bookmarkURL, withTitle: testTitle)!
        bookmarks.addBookmark(bookmark)
        
        XCTAssertTrue(bookmarks.isBookmarked(url: bookmarkURL))
    }

}
