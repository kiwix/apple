//
//  Settings.swift
//  Kiwix
//
//  Created by Chris Li on 6/20/18.
//  Copyright © 2018 Chris Li. All rights reserved.
//

import Defaults

extension Defaults.Keys {
    // reading
    static let externalLinkLoadingPolicy = Key<ExternalLinkLoadingPolicy>(
        "externalLinkLoadingPolicy", default: .alwaysAsk
    )
    static let webViewTextSizeAdjustFactor = Key<Double>("webViewZoomScale", default: 1)
    
    // UI
    static let sideBarDisplayMode = Key<SideBarDisplayMode>("sideBarDisplayMode", default: .automatic)
    
    // search
    static let recentSearchTexts = Key<[String]>("recentSearchTexts", default: [])
    static let searchResultSnippetMode = Key<SearchResultSnippetMode>(
        "searchResultSnippetMode", default: .firstSentence
    )
    
    // library
    static let libraryFilterLanguageCodes = Key<[String]>("libraryFilterLanguageCodes", default: [])
    static let libraryShownLanguageFilterAlert = Key<Bool>("libraryHasShownLanguageFilterAlert", default: false)
    static let libraryLanguageSortingMode = Key<LibraryLanguageFilterSortingMode>(
        "libraryLanguageSortingMode", default: LibraryLanguageFilterSortingMode.alphabetically
    )
    static let libraryAutoRefresh = Key<Bool>("libraryAutoRefresh", default: true)
    static let libraryLastRefreshTime = Key<Date?>("libraryLastRefreshTime")
    static let backupDocumentDirectory = Key<Bool>("backupDocumentDirectory", default: false)
    static let downloadUsingCellular = Key<Bool>("downloadUsingCellular", default: false)
}

extension Defaults {
    static subscript(key: Key<[String]>) -> [String] {
        get { (key.suite.array(forKey: key.name) as? [String]) ?? key.defaultValue }
        set { key.suite.set(newValue, forKey: key.name) }
    }
    
    static subscript(key: Key<LibraryLanguageFilterSortingMode>) -> LibraryLanguageFilterSortingMode {
        get { LibraryLanguageFilterSortingMode(rawValue: key.suite.string(forKey: key.name) ?? "") ?? key.defaultValue }
        set { key.suite.set(newValue.rawValue, forKey: key.name) }
    }
}

extension UserDefaults {
    @objc var recentSearchTexts: [String] {
        get { return stringArray(forKey: "recentSearchTexts") ?? [] }
    }
}
