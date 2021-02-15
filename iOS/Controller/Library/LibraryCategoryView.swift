//
//  LibraryCategoryView.swift
//  Kiwix
//
//  Created by Chris Li on 1/17/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI

import RealmSwift

/// List all zim files under a category, of one or many languages
@available(iOS 13.0, *)
struct LibraryCategoryView: View {
    @ObservedObject private var viewModel: ViewModel
    
    private let category: ZimFile.Category
    var zimFileTapped: ((ZimFileView.ViewModel) -> Void) = { _ in }
    
    init(category: ZimFile.Category) {
        self.category = category
        self.viewModel = ViewModel(category: category)
    }
    
    var body: some View {
        List {
            ForEach(viewModel.languages) { language in
                if let zimFiles = viewModel.zimFiles[language.code] {
                    Section(header: viewModel.languages.count > 1 ? Text(language.name) : nil) {
                        ForEach(zimFiles) { metadata in
                            Button(action: { zimFileTapped(metadata) }, label: {
                                ZimFileView(metadata, accessory: .onDevice)
                            })
                        }
                    }
                }
            }
        }
    }
    
    class ViewModel: ObservableObject {
        @Published private(set) var languages = [Language]()
        @Published private(set) var zimFiles = [String: [ZimFileView.ViewModel]]()
        
        private let category: ZimFile.Category
        private let queue = DispatchQueue(label: "org.kiwix.libraryUI.category", qos: .userInitiated)
        private let database = try? Realm(configuration: Realm.defaultConfig)
        private var languageObserver: AnyCancellable?
        private var zimFilesObserver: AnyCancellable?
        
        init(category: ZimFile.Category) {
            self.category = category
            self.languageObserver = UserDefaults.standard.publisher(for: \.libraryLanguageCodes)
                .map { $0.compactMap({ Language(code: $0) }).sorted() }
                .sink { [weak self] languages in
                    self?.languages = languages
                    self?.load()
                    LibraryService_iOS13.shared.downloadFavicons(category: category, languages: languages)
                }
        }
        
        private func load() {
            zimFilesObserver = database?.objects(ZimFile.self)
                .filter(NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "languageCode IN %@", languages.map({ $0.code })),
                    NSPredicate(format: "categoryRaw == %@", category.rawValue),
                ]))
                .sorted(by: [
                    SortDescriptor(keyPath: "title", ascending: true),
                    SortDescriptor(keyPath: "size", ascending: false),
                ])
                .collectionPublisher
                .subscribe(on: queue)
                .freeze()
                .map { (results: Results<ZimFile>) in
                    var zimFiles = [String: [ZimFileView.ViewModel]]()
                    results.forEach { zimFile in
                        zimFiles[zimFile.languageCode, default: [ZimFileView.ViewModel]()]
                            .append(ZimFileView.ViewModel(zimFile))
                    }
                    return zimFiles
                }
                .receive(on: DispatchQueue.main)
                .catch { _ in Just([:]) }
                .assign(to: \.zimFiles, on: self)
        }
    }
}
