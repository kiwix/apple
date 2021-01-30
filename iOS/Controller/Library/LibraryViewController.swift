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
import RealmSwift

@available(iOS 13.0, *)
class LibraryViewController: UISplitViewController, UISplitViewControllerDelegate {
    private let sidebarViewController: UIViewController
    private let sidebarNavigationViewController: UINavigationController
    
    init() {
        let sidebarView = LibrarySidebarView()
        let sidebarViewController = UIHostingController(rootView: sidebarView)
        self.sidebarViewController = sidebarViewController
        self.sidebarNavigationViewController = UINavigationController(rootViewController: sidebarViewController)
        
        self.sidebarNavigationViewController.navigationBar.prefersLargeTitles = true

//        super.init(style: .doubleColumn)
//        preferredDisplayMode = .oneBesideSecondary
//        preferredSplitBehavior = .tile
//        presentsWithGesture = false
        
//        setViewController(self.sidebarViewController, for: .primary)
//        setViewController(UIHostingController(rootView: LibraryCategoryView(category: .wikipedia)), for: .secondary)
        
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
            UIBarButtonItem(image: UIImage(systemName: "info.circle"), style: .plain, target: nil, action: nil),
        ]
        showCategory(.wikipedia)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func dismissController() {
        dismiss(animated: true)
    }
    
    @objc func openInfoController() {
        
    }
    
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        true
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
    
    func showZimFile(_ metadata : ZimFile.Metadata) {
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
    var zimFileTapped: ((ZimFile.Metadata) -> Void) = { _ in }
    
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
                        Button(action: { zimFileTapped(metadata) }, label: { CompactZimFileView(metadata) })
                    }
                }
            }
            if let zimFiles = viewModel.downloadZimFiles, !zimFiles.isEmpty {
                Section(header: Text("Download")) {
                    ForEach(zimFiles) { metadata in
                        Button(action: { zimFileTapped(metadata) }, label: { CompactZimFileView(metadata) })
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
    @Published private(set) var onDeviceZimFiles: [ZimFile.Metadata]?
    @Published private(set) var downloadZimFiles: [ZimFile.Metadata]?
    @Published private(set) var downloadProgresses = [String: Progress]()
    
    private let queue = DispatchQueue(label: "org.kiwix.libraryUI.sidebar", qos: .userInitiated)
    private let database = try? Realm(configuration: Realm.defaultConfig)
    private var totalZimFileCountObserver: AnyCancellable? = nil
    private var onDeviceZimFilesObserver: AnyCancellable? = nil
    private var downloadZimFilesObserver: AnyCancellable? = nil
    
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
            .map { $0.map { ZimFile.Metadata($0) } }
            .receive(on: DispatchQueue.main)
            .catch { _ in Just([]) }
            .sink { [weak self] metadata in
                if self?.onDeviceZimFiles == nil {
                    self?.onDeviceZimFiles = metadata
                } else {
                    withAnimation { self?.onDeviceZimFiles = metadata }
                }
            }
        downloadZimFilesObserver = database?.objects(ZimFile.self)
            .filter(NSPredicate(format: "stateRaw IN %@", ZimFile.State.download.map({ $0.rawValue })))
            .sorted(byKeyPath: "size", ascending: false)
            .collectionPublisher
            .subscribe(on: queue)
            .freeze()
            .map { ( $0.map { ZimFile.Metadata($0) }, Array($0) ) }
            .receive(on: DispatchQueue.main)
            .catch { _ in Just(([], [])) }
            .sink { [weak self] (metadata: [ZimFile.Metadata], zimFiles: [ZimFile]) in
                if self?.downloadZimFiles == nil {
                    self?.downloadZimFiles = metadata
                } else {
                    withAnimation { self?.downloadZimFiles = metadata }
                }
                zimFiles.forEach { zimFile in
                    if let progress = self?.downloadProgresses[zimFile.id] {
                        progress.completedUnitCount = zimFile.downloadTotalBytesWritten
                    } else {
                        self?.downloadProgresses[zimFile.id] = zimFile.downloadProgress
                    }
                }
            }
    }
    
    func fetchOnlineCatalog() {
        let operation = OPDSRefreshOperation()
        LibraryOperationQueue.shared.addOperation(operation)
    }
}
