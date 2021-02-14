//
//  LibraryViewController.swift
//  Kiwix
//
//  Created by Chris Li on 1/16/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI
import UIKit

import Defaults
import RealmSwift

@available(iOS 13.0, *)
class LibraryViewController: UISplitViewController, UISplitViewControllerDelegate {
    private let sidebarViewController: UIHostingController<LibrarySidebarView>
    private let sidebarNavigationViewController: UINavigationController
    private let searchController: UISearchController
    private let searchResultsController: UIHostingController<LibrarySearchResultView>
    
    init() {
        self.sidebarViewController = UIHostingController(rootView: LibrarySidebarView())
        self.sidebarNavigationViewController = UINavigationController(rootViewController: sidebarViewController)
        self.sidebarNavigationViewController.navigationBar.prefersLargeTitles = true
        self.searchResultsController = UIHostingController(rootView: LibrarySearchResultView())
        self.searchController = UISearchController(searchResultsController: searchResultsController)

        super.init(nibName: nil, bundle: nil)
        preferredDisplayMode = .allVisible
        viewControllers = [sidebarNavigationViewController]
        delegate = self
        
        sidebarViewController.rootView.zimFileTapped = { [weak self] metadata in self?.showZimFile(metadata) }
        sidebarViewController.rootView.categoryTapped = { [weak self] category in self?.showCategory(category) }
        sidebarViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissController))
        sidebarViewController.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "info.circle"),
                            style: .plain,
                            target: self,
                            action: #selector(showInfo(sender:)))
        ]
        sidebarViewController.navigationItem.searchController = searchController
        sidebarViewController.definesPresentationContext = true
        
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.placeholder = "Search by Name"
        searchController.searchResultsUpdater = searchResultsController.rootView.viewModel
        searchResultsController.rootView.zimFileTapped = { [weak self] metadata in self?.showZimFile(metadata) }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass == .regular, viewControllers.count == 1 {
            showCategory(.wikipedia)
        }
    }
    
    @objc func dismissController() {
        dismiss(animated: true)
    }
    
    @objc func showInfo(sender: UIBarButtonItem) {
        let controller = UIHostingController(rootView: LibraryInfoView())
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.barButtonItem = sender
        controller.rootView.dismiss = { [weak controller] in controller?.dismiss(animated: true) }
        present(controller, animated: true)
    }
    
    func showCategory(_ category: ZimFile.Category) {
        let controller = UIHostingController(rootView: LibraryCategoryView(category: category))
        controller.navigationItem.title = category.description
        controller.navigationItem.largeTitleDisplayMode = .never
        let navigationController = UINavigationController(rootViewController: controller)
        controller.rootView.zimFileTapped = { metadata in
            let controller = UIHostingController(rootView: LibraryZimFileView(id: metadata.id))
            controller.rootView?.zimFileDeleted = { navigationController.popViewController(animated: true) }
            navigationController.pushViewController(controller, animated: true)
        }
        showDetailViewController(navigationController, sender: nil)
    }
    
    func showZimFile(_ metadata: ZimFileView.ViewModel) {
        let controller = UIHostingController(rootView: LibraryZimFileView(id: metadata.id))
        controller.navigationItem.title = metadata.title
        controller.navigationItem.largeTitleDisplayMode = .never
        showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
    }
}

@available(iOS 13.0, *)
private struct LibrarySidebarView: View {
    @ObservedObject private var viewModel = ViewModel()
    
    var categoryTapped: ((ZimFile.Category) -> Void) = { _ in }
    var zimFileTapped: ((ZimFileView.ViewModel) -> Void) = { _ in }
    
    var body: some View {
        List {
            if viewModel.totalZimFileCount == 0 {
                Section(header: Text("Add Files")) {
                    Button("Fetch Online Catalog", action: { viewModel.fetchOnlineCatalog() })
                    Button("From Files App", action: {})
                    Button("From Your Computer", action: {})
                }
            }
            if let zimFiles = viewModel.onDeviceZimFiles, !zimFiles.isEmpty {
                Section(header: Text("On Device")) {
                    ForEach(zimFiles) { metadata in
                        Button(action: { zimFileTapped(metadata) }, label: { ZimFileView(metadata) })
                    }
                }
            }
            if let zimFiles = viewModel.downloadZimFiles, !zimFiles.isEmpty {
                Section(header: Text("Download")) {
                    ForEach(zimFiles) { metadata in
                        Button(action: { zimFileTapped(metadata) }, label: { ZimFileView(metadata) })
                    }
                }
            }
            Section(header: Text("Categories")) {
                ForEach(ZimFile.Category.allCases) { category in
                    categoryView(category)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Library", displayMode: .large)
    }
    
    func categoryView(_ category: ZimFile.Category) -> some View {
        Button(action: {
            categoryTapped(category)
        }, label: {
            HStack {
                Image(uiImage: category.icon)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 18, maxHeight: 18)
                    .padding(3)
                    .background(Color(.white))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(category.description).foregroundColor(.primary)
                Spacer()
                DisclosureIndicator()
            }
        })
    }
}

@available(iOS 13.0, *)
private class ViewModel: ObservableObject {
    @Published private(set) var totalZimFileCount: Int?
    @Published private(set) var onDeviceZimFiles: [ZimFileView.ViewModel]?
    @Published private(set) var downloadZimFiles: [ZimFileView.ViewModel]?
    
    private let queue = DispatchQueue(label: "org.kiwix.libraryUI.sidebar", qos: .userInitiated)
    private let database = try? Realm(configuration: Realm.defaultConfig)
    private var totalZimFileCountObserver: AnyCancellable?
    private var onDeviceZimFilesObserver: AnyCancellable?
    private var downloadZimFilesObserver: AnyCancellable?
    
    init() {
        totalZimFileCountObserver = database?.objects(ZimFile.self)
            .collectionPublisher
            .subscribe(on: queue)
            .freeze()
            .map { $0.count }
            .receive(on: DispatchQueue.main)
            .catch { _ in Just(0) }
            .sink { [weak self] count in withAnimation { self?.totalZimFileCount = count } }
        onDeviceZimFilesObserver = database?.objects(ZimFile.self)
            .filter(NSPredicate(format: "stateRaw == %@", ZimFile.State.onDevice.rawValue))
            .sorted(byKeyPath: "size", ascending: false)
            .collectionPublisher
            .subscribe(on: queue)
            .freeze()
            .map { $0.map { ZimFileView.ViewModel($0) } }
            .receive(on: DispatchQueue.main)
            .catch { _ in Just([]) }
            .sink { [weak self] metadata in
                withAnimation(self?.onDeviceZimFiles == nil ? nil : .default) {
                    self?.onDeviceZimFiles = metadata
                }
            }
        downloadZimFilesObserver = database?.objects(ZimFile.self)
            .filter(NSPredicate(format: "stateRaw IN %@", ZimFile.State.download.map({ $0.rawValue })))
            .sorted(byKeyPath: "size", ascending: false)
            .collectionPublisher
            .subscribe(on: queue)
            .freeze()
            .map { $0.map { ZimFileView.ViewModel($0, withDownloadInfo: true) } }
            .receive(on: DispatchQueue.main)
            .catch { _ in Just([]) }
            .sink { [weak self] metadata in
                withAnimation(self?.downloadZimFiles == nil ? nil : .default) {
                    self?.downloadZimFiles = metadata
                }
            }
    }
    
    func fetchOnlineCatalog() {
        let operation = OPDSRefreshOperation()
        LibraryOperationQueue.shared.addOperation(operation)
    }
}

/// Info about the library, inlcluding info about enabled lanugage, catalog update and zim file update.
@available(iOS 13.0, *)
struct LibraryInfoView: View {
    @Default(.libraryLastRefreshTime) private var lastRefreshTime
    @Default(.libraryAutoRefresh) private var isAutoRefreshEnabled
    @Default(.backupDocumentDirectory) private var isBackingUpDocumentDirectory
    @Default(.libraryFilterLanguageCodes) private var languageCodes
    
    var dismiss: (() -> Void) = {}
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Language", destination: LibraryLanguageView())
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

/// List enabled and disabled languages in the library.
@available(iOS 13.0, *)
struct LibraryLanguageView: View {
    @Default(.libraryLanguageSortingMode) private var libraryLanguageSortingMode
    @ObservedObject private var viewModel = ViewModel()
    
    var body: some View {
        if #available(iOS 14.0, *) {
            list.toolbar {
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
        } else {
            list
        }
    }
    
    var list: some View {
        List {
            Section {
                ForEach(viewModel.enabledLanguages) { language in
                    HStack {
                        Text(language.name)
                        Spacer()
                    }
                }
            }
            Section {
                ForEach(viewModel.disabledLanguages) { language in
                    HStack {
                        Text(language.name)
                        Spacer()
                    }
                }
            }
        }
        .insetGroupedListStyle()
        .navigationBarTitle("Language", displayMode: .inline)
    }
    
    class ViewModel: ObservableObject {
        let counts: [Language: Int]
        @Published private(set) var enabledLanguages: [Language] = []
        @Published private(set) var disabledLanguages: [Language] = []
        
        private var observer: AnyCancellable?
        
        init() {
            do {
                let database = try Realm(configuration: Realm.defaultConfig)
                counts = database.objects(ZimFile.self)
                    .distinct(by: ["languageCode"])
                    .compactMap {
                        Language(
                            code: $0.languageCode,
                            count: database.objects(ZimFile.self).filter("languageCode = %@", $0.languageCode).count
                        )
                    }
                    .reduce(into: [Language: Int]()) { (result, language) in
                        result[language] = database.objects(ZimFile.self).filter("languageCode = %@", language.code).count
                    }
            } catch { counts = [:] }
            update(languageCodes: Defaults[.libraryFilterLanguageCodes], sortingMode: Defaults[.libraryLanguageSortingMode])
            
            observer = Publishers.CombineLatest(
                Defaults.publisher(.libraryFilterLanguageCodes),
                Defaults.publisher(.libraryLanguageSortingMode)
            ).sink { languageCodes, sortingMode in
                self.update(languageCodes: languageCodes.newValue, sortingMode: sortingMode.newValue)
            }
        }
        
        func update(languageCodes: [String], sortingMode: LibraryLanguageFilterSortingMode) {
            let languages = self.counts.keys.sorted { (lhs, rhs) -> Bool in
                switch sortingMode {
                case .alphabetically:
                    return lhs < rhs
                case .byCount:
                    guard let lhsCount = self.counts[lhs], let rhsCount = self.counts[rhs], lhsCount != rhsCount else { return lhs < rhs }
                    return lhsCount > rhsCount
                }
            }
            
            var enabledLanguages = [Language]()
            var disabledLanguages = [Language]()
            for language in languages {
                if languageCodes.contains(language.code) {
                    enabledLanguages.append(language)
                } else {
                    disabledLanguages.append(language)
                }
            }
            self.enabledLanguages = enabledLanguages
            self.disabledLanguages = disabledLanguages
        }
    }
}
