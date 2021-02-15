//
//  LibraryService.swift
//  Kiwix
//
//  Created by Chris Li on 4/25/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

import Combine
#if canImport(UIKit)
import UIKit
#endif

import Defaults
import RealmSwift

class LibraryService {
    func isFileInDocumentDirectory(zimFileID: String) -> Bool {
        if let fileName = ZimFileService.shared.getFileURL(zimFileID: zimFileID)?.lastPathComponent,
            let documentDirectoryURL = try? FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            let fileURL = documentDirectoryURL.appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: fileURL.path)
        } else {
            return false
        }
    }
    
    // MARK: - Settings

    #if canImport(UIKit)
    static let autoUpdateInterval: TimeInterval = 3600.0 * 6
    var isAutoUpdateEnabled: Bool {
        get {
            return Defaults[.libraryAutoRefresh]
        }
        set(newValue) {
            Defaults[.libraryAutoRefresh] = newValue
            applyAutoUpdateSetting()
        }
    }

    func applyAutoUpdateSetting() {
        UIApplication.shared.setMinimumBackgroundFetchInterval(
            isAutoUpdateEnabled ? LibraryService.autoUpdateInterval : UIApplication.backgroundFetchIntervalNever
        )
    }
    #endif
}

@available(iOS 13.0, *)
class LibraryService_iOS13: LibraryService {
    static let shared = LibraryService_iOS13()
    private var downloadFaviconsPipeline: AnyCancellable?
    
    private override init() {}
    
    func downloadFavicons(category: ZimFile.Category, languages: [Language]) {
        do {
            let database = try Realm(configuration: Realm.defaultConfig)
            let tasks = database.objects(ZimFile.self)
                .filter(NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "languageCode IN %@", languages.map({ $0.code })),
                    NSPredicate(format: "categoryRaw == %@", category.rawValue),
                    NSPredicate(format: "faviconURL != nil"),
                    NSPredicate(format: "faviconData == nil"),
                ]))
                .compactMap { $0.faviconURL }
                .compactMap { URL(string: $0) }
                .compactMap { URLSession.shared.dataTaskPublisher(for: $0) }
            downloadFaviconsPipeline = Publishers.MergeMany(tasks)
                .collect(5)
                .sink(receiveCompletion: { _ in }, receiveValue: { batch in
                    do {
                        let database = try Realm(configuration: Realm.defaultConfig)
                        try database.write {
                            batch.forEach { data, response in
                                guard let response = response as? HTTPURLResponse,
                                      response.statusCode >= 200,
                                      let url = response.url else { return }
                                let zimFiles = database.objects(ZimFile.self)
                                    .filter(NSPredicate(format: "faviconURL == %@", url.absoluteString))
                                zimFiles.forEach { zimFile in
                                    zimFile.faviconData = data
                                }
                            }
                        }
                    } catch {}
                })
        } catch {}
    }
}
