//
//  LibraryInfoView.swift
//  Kiwix
//
//  Created by Chris Li on 2/14/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI

import Defaults
import RealmSwift

/// Info about the library, inlcluding info about enabled lanugage, catalog update and zim file update.
@available(iOS 14.0, *)
struct LibraryInfoView: View {
    @Default(.libraryLastRefreshTime) private var lastRefreshTime
    @Default(.libraryAutoRefresh) private var isAutoRefreshEnabled
    @Default(.backupDocumentDirectory) private var isBackingUpDocumentDirectory
    @Default(.libraryFilterLanguageCodes) private var languageCodes
    
    private let languageView = LibraryLanguageView()
    var dismiss: (() -> Void) = {}
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Language", destination: languageView)
                }
                Section(
                    header: Text("Update"),
                    footer: Text("""
                        With auto update enabled, the catalog will be updated both when library \
                        is opened and utilizing iOS's Background App Refresh feature.
                        """
                    )
                ) {
                    HStack {
                        Text("Last updated")
                        Spacer()
                        lastUpdatedTime.foregroundColor(.secondary)
                    }
                    Toggle("Auto update", isOn: $isAutoRefreshEnabled)
                    HStack {
                        Spacer()
                        Button("Update now") { }
                        Spacer()
                    }
                }
                Section(header: Text("Backup"), footer: Text("Does not apply to files that were opened in place.")) {
                    Toggle("Include files in backup", isOn: $isBackingUpDocumentDirectory)
                }
            }
            .insetGroupedListStyle()
            .navigationBarTitle("Info", displayMode: .inline)
            .navigationBarItems(leading: Button("Done", action: dismiss))
        }.navigationViewStyle(StackNavigationViewStyle())
    }
    
    var lastUpdatedTime: some View {
        if let refreshTime = Defaults[.libraryLastRefreshTime] {
            if Date().timeIntervalSince(refreshTime) < 120 {
                return Text("Just now")
            } else {
                return Text(RelativeDateTimeFormatter().localizedString(for: refreshTime, relativeTo: Date()))
            }
        } else {
            return Text("Never")
        }
    }
}

/// List and update enabled and disabled languages in the library.
@available(iOS 14.0, *)
struct LibraryLanguageView: View {
    @Default(.libraryLanguageSortingMode) private var libraryLanguageSortingMode
    @ObservedObject private var viewModel = ViewModel()
    
    var body: some View {
        List {
            if !viewModel.enabledLanguages.isEmpty {
                Section(header: Text("Showing")) {
                    ForEach(viewModel.enabledLanguages) { language in
                        Button(action: { viewModel.disable(language) }, label: {
                            Cell(language: language, isEnabled: true)
                        })
                    }
                }
            }
            Section(header: Text(viewModel.enabledLanguages.isEmpty ? "All" : "Hiding")) {
                ForEach(viewModel.disabledLanguages) { language in
                    Button(action: { viewModel.enable(language) }, label: {
                        Cell(language: language, isEnabled: false)
                    })
                }
            }
        }
        .insetGroupedListStyle()
        .navigationBarTitle("Language", displayMode: .inline)
        .onAppear {
            viewModel.load()
            viewModel.update(
                languageCodes: Defaults[.libraryFilterLanguageCodes],
                sortingMode: Defaults[.libraryLanguageSortingMode]
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sorting options", selection: $libraryLanguageSortingMode) {
                        Text("Alphabetically").tag(LibraryLanguageFilterSortingMode.alphabetically)
                        Text("By Count").tag(LibraryLanguageFilterSortingMode.byCount)
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }
    
    struct Cell: View {
        let language: Language
        let isEnabled: Bool
        
        var body: some View {
            HStack {
                Image(systemName: isEnabled ? "checkmark.circle" : "circle")
                    .foregroundColor(isEnabled ? .green : .secondary)
                Text(language.name).foregroundColor(.primary)
                Spacer()
                if let count = language.count { Text("\(count)").foregroundColor(.secondary) }
            }
        }
    }
    
    class ViewModel: ObservableObject {
        @Published private(set) var enabledLanguages: [Language] = []
        @Published private(set) var disabledLanguages: [Language] = []
        
        private var allLanguages = [Language]()
        private var observer: AnyCancellable?
        
        init() {
            observer = Publishers.CombineLatest(
                Defaults.publisher(.libraryFilterLanguageCodes),
                Defaults.publisher(.libraryLanguageSortingMode)
            ).sink { [weak self] languageCodes, sortingMode in
                self?.update(languageCodes: languageCodes.newValue, sortingMode: sortingMode.newValue)
            }
        }
        
        /// Prepares all language data when view appears.
        func load() {
            do {
                let database = try Realm(configuration: Realm.defaultConfig)
                allLanguages = database.objects(ZimFile.self)
                    .distinct(by: ["languageCode"])
                    .compactMap {
                        Language(
                            code: $0.languageCode,
                            count: database.objects(ZimFile.self).filter("languageCode = %@", $0.languageCode).count
                        )
                    }
            } catch { allLanguages = [] }
        }
        
        /// Update enabled and disabled languages.
        /// - Parameters:
        ///   - languageCodes: enabled language codes
        ///   - sortingMode: how both enabled and disabled languages should be sorted
        func update(languageCodes: [String], sortingMode: LibraryLanguageFilterSortingMode) {
            // sort all the languages
            let languages = allLanguages.sorted { (lhs, rhs) -> Bool in
                switch sortingMode {
                case .alphabetically:
                    return lhs < rhs
                case .byCount:
                    guard lhs.count != rhs.count else { return lhs < rhs }
                    return lhs.count ?? 0 > rhs.count ?? 0
                }
            }
            
            // separate sorted languages into enabled and disabled
            var enabledLanguages = [Language]()
            var disabledLanguages = [Language]()
            for language in languages {
                if languageCodes.contains(language.code) {
                    enabledLanguages.append(language)
                } else {
                    disabledLanguages.append(language)
                }
            }
            withAnimation {
                self.enabledLanguages = enabledLanguages
                self.disabledLanguages = disabledLanguages
            }
        }
        
        func enable(_ language: Language) {
            Defaults[.libraryFilterLanguageCodes] += [language.code]
        }
        
        func disable(_ language: Language) {
            Defaults[.libraryFilterLanguageCodes].removeAll(where: { $0 == language.code })
        }
    }
}
