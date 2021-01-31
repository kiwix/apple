//
//  LibrarySearchResultView.swift
//  Kiwix
//
//  Created by Chris Li on 1/30/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI
import Defaults
import RealmSwift

@available(iOS 13.0, *)
struct LibrarySearchResultView: View {
    @ObservedObject var viewModel = ViewModel()
    
    var zimFileTapped: ((ZimFileView.ViewModel) -> Void) = { _ in }
    
    var body: some View {
        if viewModel.isLoading {
            if #available(iOS 14.0, *) {
                ProgressView().progressViewStyle(CircularProgressViewStyle())
            } else {
                Text("Search...")
            }
        } else if viewModel.zimFiles.isEmpty {
            Text("No Results")
        } else {
            List {
                ForEach(viewModel.zimFiles) { zimFile in
                    Button(action: { zimFileTapped(zimFile) }, label: {
                        ZimFileView(zimFile, accessory: .onDevice)
                    })
                }
            }
        }
    }
    
    class ViewModel: NSObject, ObservableObject, UISearchResultsUpdating {
        @Published private(set) var zimFiles = [ZimFileView.ViewModel]()
        @Published private(set) var isLoading = false
        
        private let queue = DispatchQueue(label: "org.kiwix.library.search", qos: .userInitiated)
        private let searchTextSubject = CurrentValueSubject<String?, Never>(nil)
        private var searchTextObserver: AnyCancellable? = nil
        
        override init() {
            super.init()
            self.searchTextObserver = searchTextSubject
                .debounce(for: .milliseconds(500), scheduler: queue)
                .replaceNil(with: "")
                .map({ searchText -> [ZimFileView.ViewModel] in
                    guard let database = try? Realm(configuration: Realm.defaultConfig) else { return [] }
                    return database.objects(ZimFile.self)
                        .filter(NSCompoundPredicate(andPredicateWithSubpredicates: [
                            NSPredicate(format: "languageCode IN %@", Defaults[.libraryFilterLanguageCodes]),
                            NSPredicate(format: "title CONTAINS[cd] %@", searchText)
                        ]))
                        .sorted(byKeyPath: "size", ascending: false)
                        .map { ZimFileView.ViewModel($0) }
                })
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { zimFiles in
                    self.zimFiles = zimFiles
                    self.isLoading = false
                })
        }
        
        func updateSearchResults(for searchController: UISearchController) {
            guard searchTextSubject.value != searchController.searchBar.text else { return }
            isLoading = true
            searchTextSubject.send(searchController.searchBar.text)
        }
    }
}
