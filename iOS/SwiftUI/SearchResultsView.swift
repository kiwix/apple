//
//  SearchResultsView.swift
//  Kiwix
//
//  Created by Chris Li on 5/14/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI
import RealmSwift

@available(iOS 14.0, *)
class SearchResultsHostingController: UIViewController, UISearchResultsUpdating {
    private var viewModel = ViewModel()
    private var queue = OperationQueue()
    private var bottomConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        
        let controller = UIHostingController(rootView: SearchResultsView().environmentObject(viewModel))
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: controller.view.topAnchor),
            view.leftAnchor.constraint(equalTo: controller.view.leftAnchor),
            view.rightAnchor.constraint(equalTo: controller.view.rightAnchor),
        ])
        bottomConstraint = view.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
        bottomConstraint?.isActive = true
        controller.didMove(toParent: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardEvent(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardEvent(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: Keyboard Events
    // These section of code is necessary because SwiftUI keyboard avoidance does not work as expected on iPadOS 14
    
    @objc func handleKeyboardEvent(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardEndFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
              let animationCurveValue = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue else {return}
        let height = view.convert(keyboardEndFrame, from: nil).intersection(view.bounds).height
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: animationCurveValue)) {
            self.bottomConstraint?.constant = height
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: UISearchResultsUpdating
    
    func updateSearchResults(for searchController: UISearchController) {
        guard searchController.isActive else { return }
        viewModel.searchTextPublisher.send(searchController.searchBar.text ?? "")
    }
}

@available(iOS 14.0, *)
private class ViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var inProgress = false
    @Published var results = [SearchResult]()
    @ObservedResults(
        ZimFile.self,
        configuration: Realm.defaultConfig,
        filter: NSPredicate(format: "stateRaw == %@", ZimFile.State.onDevice.rawValue),
        sortDescriptor: SortDescriptor(keyPath: "size", ascending: false)
    ) var zimFiles
    
    var searchTextPublisher = CurrentValueSubject<String, Never>("")
    private var searchObserver: AnyCancellable?
    private var queue = OperationQueue()
    
    init() {
        queue.maxConcurrentOperationCount = 1
        do {
            let database = try Realm(configuration: Realm.defaultConfig)
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "stateRaw == %@", ZimFile.State.onDevice.rawValue),
                NSPredicate(format: "includedInSearch == true"),
            ])
            searchObserver = database.objects(ZimFile.self).filter(predicate)
                .collectionPublisher
                .freeze()
                .map { zimFiles in return Array(zimFiles.map({ $0.fileID })) }
                .catch { _ in Just([]) }
                .combineLatest(searchTextPublisher)
                .sink { zimFileIDs, searchText in
                    self.updateSearchResults(searchText, Set(zimFileIDs))
                }
        } catch { }
    }
    
    func toggleZimFileIncludedInSearch(_ zimFileID: String) {
        do {
            let database = try Realm()
            guard let zimFile = database.object(ofType: ZimFile.self, forPrimaryKey: zimFileID) else { return }
            try database.write {
                zimFile.includedInSearch = !zimFile.includedInSearch
            }
        } catch {}
    }
    
    func includeAllZimFilesInSearch() {
        do {
            let database = try Realm()
            try database.write {
                for zimFile in database.objects(ZimFile.self) {
                    zimFile.includedInSearch = true
                }
            }
        } catch {}
    }
    
    func excludeAllZimFilesInSearch() {
        do {
            let database = try Realm()
            try database.write {
                for zimFile in database.objects(ZimFile.self) {
                    zimFile.includedInSearch = false
                }
            }
        } catch {}
    }
    
    private func updateSearchResults(_ searchText: String, _ zimFileIDs: Set<String>) {
        self.searchText = searchText
        inProgress = true
        
        queue.cancelAllOperations()
        let operation = SearchOperation(searchText: searchText, zimFileIDs: zimFileIDs)
        operation.completionBlock = { [weak self] in
            guard !operation.isCancelled else { return }
            DispatchQueue.main.sync {
                self?.results = operation.results
                self?.inProgress = false
            }
        }
        queue.addOperation(operation)
    }
}

@available(iOS 14.0, *)
private struct SearchResultsView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        if viewModel.zimFiles.isEmpty {
            InfoView(
                imageSystemName: "magnifyingglass",
                title: "Nothing to search",
                help: "Add some zim files first, then start a search again."
            )
        } else if horizontalSizeClass == .regular {
            SplitView().edgesIgnoringSafeArea(.all)
        } else if viewModel.searchText.isEmpty {
            FilterView()
        } else if viewModel.inProgress {
            ProgressView().progressViewStyle(CircularProgressViewStyle())
        } else if viewModel.results.isEmpty {
            InfoView(
                imageSystemName: "magnifyingglass",
                title: "No results",
                help: "Change the search text or include more zim files in search."
            )
        } else {
            List {
                ForEach(viewModel.results) { result in
                    Text(result.title)
                }
            }
        }
    }
}

@available(iOS 14.0, *)
private struct SplitView: UIViewControllerRepresentable {
    @EnvironmentObject var viewModel: ViewModel
    
    func makeUIViewController(context: Context) -> UISplitViewController {
        let controller = UISplitViewController()
        controller.preferredDisplayMode = .allVisible
        controller.presentsWithGesture = false
        controller.viewControllers = [UIHostingController(rootView: FilterView())]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UISplitViewController, context: Context) {
        uiViewController.showDetailViewController(UIHostingController(rootView: content), sender: nil)
    }
    
    @ViewBuilder
    var content: some View {
        if viewModel.searchText.isEmpty {
            InfoView(
                imageSystemName: "magnifyingglass",
                title: "No results",
                help: "Start typing some text to initiate a search."
            )
        } else if viewModel.inProgress  {
            ProgressView().progressViewStyle(CircularProgressViewStyle())
        } else if viewModel.results.isEmpty {
            InfoView(
                imageSystemName: "magnifyingglass",
                title: "No results",
                help: "Change the search text or include more zim files in search."
            )
        } else {
            List {
                ForEach(viewModel.results) { result in
                    Text(result.title)
                }
            }
        }
   }
}

@available(iOS 14.0, *)
private struct FilterView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        List {
            if viewModel.zimFiles.count > 0 {
                Section(header: HStack {
                    Text("Search Filter")
                    Spacer()
                    if viewModel.zimFiles.count == viewModel.zimFiles.filter({ $0.includedInSearch }).count {
                        Button("None", action: { viewModel.excludeAllZimFilesInSearch() }).foregroundColor(.secondary)
                    } else {
                        Button("All", action: { viewModel.includeAllZimFilesInSearch() }).foregroundColor(.secondary)
                    }
                }) {
                    ForEach(viewModel.zimFiles) { zimFile in
                        Button {
                            viewModel.toggleZimFileIncludedInSearch(zimFile.fileID)
                        } label: {
                            ZimFileCell(zimFile, accessories: [.includedInSearch])
                        }
                    }
                }
            }
        }.listStyle(GroupedListStyle())
    }
}

@available(iOS 14.0, *)
private struct InfoView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    let imageSystemName: String
    let title: String
    let help: String
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer(minLength: geometry.size.height * 0.3)
                if verticalSizeClass == .regular {
                    VStack {
                        makeImage(geometry)
                        text
                    }
                } else {
                    HStack {
                        makeImage(geometry)
                        text
                    }
                }
                Spacer()
                Spacer()
            }.frame(width: geometry.size.width)
        }
    }
    
    private func makeImage(_ geometry: GeometryProxy) -> some View {
        ZStack {
            GeometryReader { geometry in
                Image(systemName: imageSystemName)
                    .resizable()
                    .padding(geometry.size.height * 0.25)
                    .foregroundColor(.secondary)
            }
            Circle().foregroundColor(.secondary).opacity(0.2)
        }.frame(
            width: max(60, min(geometry.size.height * 0.2, geometry.size.width * 0.2, 100)),
            height: max(60, min(geometry.size.height * 0.2, geometry.size.width * 0.2, 100))
        )
    }
    
    var text: some View {
        VStack(spacing: 10) {
            Text(title).font(.title2).fontWeight(.medium)
            Text(help).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }.padding()
    }
}

@available(iOS 14.0, *)
struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        InfoView(
            imageSystemName: "magnifyingglass",
            title: "Nothing to search",
            help: "Add some zim files first, then start a search."
        )
        .previewDevice(PreviewDevice(rawValue: "iPhone 12 Pro"))
        .previewDisplayName("iPhone 12 Pro")
    }
}
