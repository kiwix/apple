//
//  LibraryCategoryView.swift
//  Kiwix
//
//  Created by Chris Li on 1/17/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI
import UIKit
import Defaults
import RealmSwift

struct Language: Comparable, Equatable, Identifiable, Hashable {
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
    @ObservedObject private var viewModel: ViewModel
    private let category: ZimFile.Category
    
    init(category: ZimFile.Category) {
        self.category = category
        self.viewModel = ViewModel(category: category)
    }
    
    var body: some View {
        List {
            ForEach(viewModel.languages) { language in
                if let zimFiles = viewModel.zimFiles[language.code] {
                    Section(header: viewModel.languages.count > 1 ? Text(language.name) : nil) {
                        ForEach(zimFiles) { zimFile in
                            zimFileView(zimFile)
                        }
                    }
                }
            }
        }
    }
    
    func zimFileView(_ zimFile: ZimFile) -> some View {
        Button {
            
        } label: {
            HStack {
                Favicon(zimFile: zimFile)
                VStack(alignment: .leading) {
                    Text(zimFile.title)
                    Text([
                        zimFile.sizeDescription,
                        zimFile.creationDateDescription,
                        zimFile.articleCountShortDescription,
                    ].compactMap({ $0 }).joined(separator: ", ")).font(.footnote)
                }
                Spacer()
                DisclosureIndicator()
            }
        }
    }
}

@available(iOS 13.0, *)
private class ViewModel: ObservableObject {
    @Published private(set) var languages = [Language]()
    @Published private(set) var zimFiles = [String: [ZimFile]]()
    
    private let category: ZimFile.Category
    private var languageObserver: Defaults.Observation?
    private let queue = DispatchQueue(label: "org.kiwix.libraryUI.category", qos: .userInitiated)
    private let database = try? Realm(configuration: Realm.defaultConfig)
    private var pipeline: AnyCancellable? = nil
    
    init(category: ZimFile.Category) {
        self.category = category
        self.languageObserver = Defaults.observe(.libraryFilterLanguageCodes) { [weak self] change in
            self?.configure(languageCodes: change.newValue)
        }
    }
    
    private func configure(languageCodes: [String]) {
        languages = languageCodes.compactMap({ Language(code: $0) }).sorted()
        pipeline = database?.objects(ZimFile.self)
            .filter(NSPredicate(format: "languageCode IN %@ AND categoryRaw == %@",
                                languages.map({ $0.code }),
                                category.rawValue)
            )
            .sorted(byKeyPath: "title", ascending: true)
            .sorted(by: [
                SortDescriptor(keyPath: "title", ascending: true),
                SortDescriptor(keyPath: "size", ascending: false),
            ])
            .collectionPublisher
            .subscribe(on: queue)
            .freeze()
            .map { (results: Results<ZimFile>) in
                var zimFiles = [String: [ZimFile]]()
                results.forEach { zimFile in
                    zimFiles[zimFile.languageCode, default: [ZimFile]()].append(zimFile)
                }
                return zimFiles
            }
            .receive(on: DispatchQueue.main)
            .catch { _ in Just([:]) }
            .assign(to: \.zimFiles, on: self)
    }
}
