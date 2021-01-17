//
//  LibraryCategoryView.swift
//  Kiwix
//
//  Created by Chris Li on 1/17/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import SwiftUI
import UIKit
import Defaults

struct Language: Comparable, Equatable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let count: Int?
    
    init?(code: String, count: Int? = nil) {
        if let name = Locale.current.localizedString(forLanguageCode: code) {
            self.code = code
            self.name = name
            self.count = count
        } else {
            return nil
        }
    }
    
    static func < (lhs: Language, rhs: Language) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

@available(iOS 13.0, *)
struct LibraryCategoryView: View {
    private let category: ZimFile.Category
    private let viewModel: ViewModel
    
    init(category: ZimFile.Category) {
        self.category = category
        self.viewModel = ViewModel(category: category)
    }
    
    var body: some View {
        List {
            ForEach(viewModel.languages) { language in
                Section(header: Text(language.name)) {
                    
                }
            }
        }
    }
}

@available(iOS 13.0, *)
private class ViewModel: ObservableObject {
    @Published private(set) var languages = [Language]()
//        @Published private(set) var zimFiles = [ZimFile]()
    
    private var languageObserver: Defaults.Observation?
    private let queue = DispatchQueue(label: "org.kiwix.libraryUI.categoryGeneric", qos: .userInitiated)
//        private let database = try? Realm(configuration: Realm.defaultConfig)
//        private var pipeline: AnyCancellable? = nil
    
    
    init(category: ZimFile.Category) {
        configure(languageCodes: Defaults[.libraryFilterLanguageCodes])
        
//        self.languageObserver = Defaults.observe(.libraryFilterLanguageCodes) { [weak self] change in
//            self?.configure(languageCodes: change.newValue)
//        }
//            let predicate = NSPredicate(format: "languageCode == %@ AND categoryRaw == %@", "en", category.rawValue)
//            pipeline = database?.objects(ZimFile.self)
//                .filter(predicate)
//                .sorted(byKeyPath: "title", ascending: true)
//                .collectionPublisher
//                .subscribe(on: queue)
//                .freeze()
//                .map { Array($0) }
//                .receive(on: DispatchQueue.main)
//                .catch { _ in Just([]) }
//                .assign(to: \.zimFiles, on: self)
    }
    
    private func configure(languageCodes: [String]) {
        languages = languageCodes.compactMap({ Language(code: $0) }).sorted()
        
    }
}
