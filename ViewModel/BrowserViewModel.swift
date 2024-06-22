// This file is part of Kiwix for iOS & macOS.
//
// Kiwix is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// any later version.
//
// Kiwix is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kiwix; If not, see https://www.gnu.org/licenses/.

import Combine
import CoreData
import CoreLocation
import WebKit
import Defaults
import os

import OrderedCollections
import CoreKiwix
import PDFKit

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
final class BrowserViewModel: NSObject, ObservableObject,
                              WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate,
                              NSFetchedResultsControllerDelegate {
    private static var cache = OrderedDictionary<NSManagedObjectID, BrowserViewModel>()

    @MainActor
    static func getCached(tabID: NSManagedObjectID) -> BrowserViewModel {
        let viewModel = cache[tabID] ?? BrowserViewModel(tabID: tabID)
        cache.removeValue(forKey: tabID)
        cache[tabID] = viewModel
        return viewModel
    }

    static func purgeCache() {
        guard cache.count > 10 else { return }
        let range = 0 ..< cache.count - 5
        cache.values[range].forEach { viewModel in
            viewModel.persistState()
        }
        cache.removeSubrange(range)
    }

    // MARK: - Properties

    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var articleTitle: String = ""
    @Published private(set) var zimFileName: String = ""
    @Published private(set) var articleBookmarked = false
    @Published private(set) var outlineItems = [OutlineItem]()
    @Published private(set) var outlineItemTree = [OutlineItem]()
    @MainActor @Published private(set) var url: URL? {
        didSet {
            if !FeatureFlags.hasLibrary, url == nil {
                loadMainArticle()
            }
            if url != oldValue {
                bookmarkFetchedResultsController.fetchRequest.predicate = Self.bookmarksPredicateFor(url: url)
                try? bookmarkFetchedResultsController.performFetch()
            }
        }
    }
    @Published var externalURL: URL?
    private var metaData: URLContentMetaData?

    private(set) var tabID: NSManagedObjectID? {
        didSet {
#if os(macOS)
            if let tabID, tabID != oldValue {
                storeTabIDInCurrentWindow()
            }
#endif
        }
    }
#if os(macOS)
    private var windowURLs: [URL] {
        UserDefaults.standard[.windowURLs]
    }
#endif
    let webView: WKWebView
    private var canGoBackObserver: NSKeyValueObservation?
    private var canGoForwardObserver: NSKeyValueObservation?
    private var titleURLObserver: AnyCancellable?
    private let bookmarkFetchedResultsController: NSFetchedResultsController<Bookmark>
    /// A temporary placeholder for the url that should be opened in a new tab, set on macOS only
    static var urlForNewTab: URL?

    // MARK: - Lifecycle

    @MainActor
    init(tabID: NSManagedObjectID? = nil) {
        self.tabID = tabID
        webView = WKWebView(frame: .zero, configuration: WebViewConfiguration())
        if !Bundle.main.isProduction, #available(iOS 16.4, macOS 13.3, *) {
                webView.isInspectable = true
        }
        // Bookmark fetching:
        bookmarkFetchedResultsController = NSFetchedResultsController(
            fetchRequest: Bookmark.fetchRequest(), // initially empty
            managedObjectContext: Database.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        super.init()

        bookmarkFetchedResultsController.delegate = self

        // configure web view
        webView.allowsBackForwardNavigationGestures = true
        webView.configuration.defaultWebpagePreferences.preferredContentMode = .mobile // for font adjustment to work
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "headings")
        webView.configuration.userContentController.add(self, name: "headings")
        webView.navigationDelegate = self
        webView.uiDelegate = self

        if let tabID {
            restoreBy(tabID: tabID)
        }
        if let urlForNewTab = Self.urlForNewTab {
            url = urlForNewTab
            load(url: urlForNewTab)
        }

        // get outline items if something is already loaded
        if webView.url != nil {
            webView.evaluateJavaScript("getOutlineItems();")
        }

        // setup web view property observers
        canGoBackObserver = webView.observe(\.canGoBack, options: .initial) { [weak self] webView, _ in
            Task { [weak self] in
                await MainActor.run { [weak self] in
                    self?.canGoBack = webView.canGoBack
                }
            }
        }
        canGoForwardObserver = webView.observe(\.canGoForward, options: .initial) { [weak self] webView, _ in
            Task { [weak self] in
                await MainActor.run { [weak self] in
                    self?.canGoForward = webView.canGoForward
                }
            }
        }
        titleURLObserver = Publishers.CombineLatest(
            webView.publisher(for: \.title, options: .initial),
            webView.publisher(for: \.url, options: .initial)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] title, url in
            guard let title, let url else { return }
            self?.didUpdate(title: title, url: url)
        }
    }

    /// Get the webpage in a binary format
    /// - Returns: PDF of the current page (if text type) or binary data of the content
    func pdfData() async -> Data? {
        if metaData?.isTextType == true {
            return try? await webView.pdf()
        } else if let url = await webView.url {
            return ZimFileService.shared.getURLContent(url: url)?.data
        }
        return nil
    }

    private func didUpdate(title: String, url: URL) {
        let zimFile: ZimFile? = {
            guard let zimFileID = UUID(uuidString: url.host ?? "") else { return nil }
            return try? Database.viewContext.fetch(ZimFile.fetchRequest(fileID: zimFileID)).first
        }()

        metaData = ZimFileService.shared.getContentMetaData(url: url)
        // update view model
        if title.isEmpty {
            articleTitle = metaData?.zimTitle ?? ""
        } else {
            articleTitle = title
        }
        zimFileName = zimFile?.name ?? ""
        Task {
            await MainActor.run {
                self.url = url
            }
        }

        let currentTabID: NSManagedObjectID = tabID ?? createNewTabID()
        tabID = currentTabID

        // update tab data
        if let tab = try? Database.viewContext.existingObject(with: currentTabID) as? Tab {
            tab.title = articleTitle
            tab.zimFile = zimFile
        }
    }

    func updateLastOpened() {
        guard let tabID, let tab = try? Database.viewContext.existingObject(with: tabID) as? Tab else { return }
        tab.lastOpened = Date()
    }

    func onDisappear() {
        webView.pauseAllMediaPlayback()
    }

    func persistState() {
        guard let tabID,
              let tab = try? Database.viewContext.existingObject(with: tabID) as? Tab else {
            return
        }
        tab.interactionState = webView.interactionState as? Data
        try? Database.viewContext.save()
    }

    // MARK: - Content Loading
    @MainActor
    func load(url: URL) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
        self.url = url
    }

    @MainActor
    func loadRandomArticle(zimFileID: UUID? = nil) {
        let zimFileID = zimFileID ?? UUID(uuidString: webView.url?.host ?? "")
        guard let url = ZimFileService.shared.getRandomPageURL(zimFileID: zimFileID) else { return }
        load(url: url)
    }

    @MainActor
    func loadMainArticle(zimFileID: UUID? = nil) {
        let zimFileID = zimFileID ?? UUID(uuidString: webView.url?.host ?? "")
        guard let url = ZimFileService.shared.getMainPageURL(zimFileID: zimFileID) else { return }
        load(url: url)
    }

    private func restoreBy(tabID: NSManagedObjectID) {
        if let tab = try? Database.viewContext.existingObject(with: tabID) as? Tab {
            webView.interactionState = tab.interactionState
            Task {
                await MainActor.run {
                    url = webView.url
                }
            }
        }
    }

    // MARK: - Video fixes
    @MainActor
    func refreshVideoState() {
        Task {
            await MainActor.run {
                webView.evaluateJavaScript("refreshVideoState();")
            }
        }
    }

    // MARK: - New Tab Creation

#if os(macOS)
    private func createNewTab(url: URL) -> Bool {
        guard let currentWindow = NSApp.keyWindow else { return false }
        guard let windowController = currentWindow.windowController else { return false }
        // store the new url in a static way
        BrowserViewModel.urlForNewTab = url
        // this creates a new BrowserViewModel
        windowController.newWindowForTab(self)
        // now reset the static url to nil, as the new BrowserViewModel already has it
        BrowserViewModel.urlForNewTab = nil
        guard let newWindow = NSApp.keyWindow, currentWindow != newWindow else { return false }
        currentWindow.addTabbedWindow(newWindow, ordered: .above)
        return true
    }
#endif

    // MARK: - WKNavigationDelegate

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

#if os(macOS)
        // detect cmd + click event
        if navigationAction.modifierFlags.contains(.command) {
            if createNewTab(url: url) {
                decisionHandler(.cancel)
                return
            }
        }
#endif

        if url.isKiwixURL, let redirectedURL = ZimFileService.shared.getRedirectedURL(url: url) {
            if webView.url != redirectedURL {
                DispatchQueue.main.async { webView.load(URLRequest(url: redirectedURL)) }
            }
            decisionHandler(.cancel)
        } else if url.isKiwixURL {
            guard ZimFileService.shared.getContentSize(url: url) != nil else {
                os_log(
                    "Missing content at url: %@ => %@",
                    log: Log.URLSchemeHandler,
                    type: .error,
                    url.absoluteString,
                    url.contentPath
                )
                decisionHandler(.cancel)
                if navigationAction.request.mainDocumentURL == url {
                    // only show alerts for missing main document
                    NotificationCenter.default.post(
                        name: .alert,
                        object: nil,
                        userInfo: ["rawValue": ActiveAlert.articleFailedToLoad.rawValue]
                    )
                }
                return
            }
            decisionHandler(.allow)
        } else if url.isUnsupported {
            externalURL = url
            decisionHandler(.cancel)
        } else if url.isGeoURL {
            if FeatureFlags.map {
                let _: CLLocation? = {
                    let parts = url.absoluteString.replacingOccurrences(of: "geo:", with: "").split(separator: ",")
                    guard let latitudeString = parts.first,
                          let longitudeString = parts.last,
                          let latitude = Double(latitudeString),
                          let longitude = Double(longitudeString) else { return nil }
                    return CLLocation(latitude: latitude, longitude: longitude)
                }()
            } else {
                let coordinate = url.absoluteString.replacingOccurrences(of: "geo:", with: "")
                if let url = URL(string: "http://maps.apple.com/?ll=\(coordinate)") {
#if os(macOS)
                    NSWorkspace.shared.open(url)
#elseif os(iOS)
                    UIApplication.shared.open(url)
#endif
                }
            }
            decisionHandler(.cancel)
        } else {
            decisionHandler(.cancel)
        }
    }

    private var canShowMimeType = true

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        canShowMimeType = navigationResponse.canShowMIMEType
        guard canShowMimeType else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        webView.evaluateJavaScript("expandAllDetailTags(); getOutlineItems();")
#if os(iOS)
        webView.adjustTextSize()
#else
        persistState()
#endif
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError error: Error
    ) {
        let error = error as NSError
        webView.stopLoading()
        (webView.configuration
            .urlSchemeHandler(forURLScheme: KiwixURLSchemeHandler.KiwixScheme) as? KiwixURLSchemeHandler)?
            .didFailProvisionalNavigation()
        guard error.code != NSURLErrorCancelled else { return }
        guard canShowMimeType else {
            guard let kiwixURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL else {
                return
            }
            NotificationCenter.saveContent(url: kiwixURL)
            return
        }
        NotificationCenter.default.post(
            name: .alert, object: nil, userInfo: ["rawValue": ActiveAlert.articleFailedToLoad.rawValue]
        )
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "headings", let headings = message.body as? [[String: String]] {
            DispatchQueue.global(qos: .userInitiated).async {
                self.generateOutlineList(headings: headings)
                self.generateOutlineTree(headings: headings)
            }
        }
    }

    // MARK: - WKUIDelegate

#if os(macOS)
    func webView(
        _: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        guard let newUrl = navigationAction.request.url else { return nil }

        // open external link in default browser
        guard newUrl.isUnsupported == false else {
            externalURL = newUrl
            return nil
        }

        _ = createNewTab(url: newUrl)
        return nil
    }
#else
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let newURL = navigationAction.request.url else { return nil }
        if let frame = navigationAction.targetFrame, frame.isMainFrame {
            return nil
        }
        guard newURL.isUnsupported == false else {
            externalURL = newURL
            return nil
        }
        NotificationCenter.openURL(newURL, inNewTab: true)
        return nil
    }
#endif

#if os(iOS)
    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
    ) {
        guard let url = elementInfo.linkURL, url.isKiwixURL else { completionHandler(nil); return }
        let configuration = UIContextMenuConfiguration(
            previewProvider: {
                let webView = WKWebView(frame: .zero, configuration: WebViewConfiguration())
                if !Bundle.main.isProduction, #available(iOS 16.4, *) {
                        webView.isInspectable = true
                }
                webView.load(URLRequest(url: url))
                return WebViewController(webView: webView)
            },
            actionProvider: { _ in
                var actions = [UIAction]()

                // open url
                actions.append(
                    UIAction(title: "common.dialog.button.open".localized,
                             image: UIImage(systemName: "doc.text")) { _ in
                        webView.load(URLRequest(url: url))
                    }
                )
                actions.append(
                    UIAction(title: "common.dialog.button.open_in_new_tab".localized,
                             image: UIImage(systemName: "doc.badge.plus")) { _ in
                        NotificationCenter.openURL(url, inNewTab: true)
                    }
                )

                // bookmark
                let bookmarkAction: UIAction = {
                    let context = Database.viewContext
                    let predicate = NSPredicate(format: "articleURL == %@", url as CVarArg)
                    let request = Bookmark.fetchRequest(predicate: predicate)

                    if let bookmarks = try? context.fetch(request),
                       !bookmarks.isEmpty {
                        return UIAction(title: "common.dialog.button.remove_bookmark".localized,
                                        image: UIImage(systemName: "star.slash.fill")) { [weak self] _ in
                            self?.deleteBookmark(url: url)
                        }
                    } else {
                        return UIAction(
                            title: "common.dialog.button.bookmark".localized,
                            image: UIImage(systemName: "star")
                        ) { [weak self] _ in
                            self?.createBookmark(url: url)
                        }
                    }
                }()
                actions.append(bookmarkAction)

                return UIMenu(children: actions)
            }
        )
        completionHandler(configuration)
    }
#endif

    // MARK: - TabID management via NSWindow for macOS

#if os(macOS)
    private (set) var windowNumber: Int?

    // RESTORATION
    func restoreByWindowNumber(
        windowNumber currentNumber: Int,
        urlToTabIdConverter: @MainActor @escaping (URL?) -> NSManagedObjectID
    ) {
        windowNumber = currentNumber
        let windows = NSApplication.shared.windows
        let tabURL: URL?

        guard let currentWindow = windowBy(number: currentNumber),
              let index = windows.firstIndex(of: currentWindow) else { return }

        // find the url for this window in user defaults, by pure index
        if 0 <= index,
           index < windowURLs.count {
            tabURL = windowURLs[index]
        } else {
            tabURL = nil
        }
        Task {
            await MainActor.run {
                let tabID = urlToTabIdConverter(tabURL) // if url is nil it will create a new tab
                self.tabID = tabID
                restoreBy(tabID: tabID)
            }
        }
    }

    private func indexOf(windowNumber number: Int, in windows: [NSWindow]) -> Int? {
        let windowNumbers = windows.map { $0.windowNumber }
        guard windowNumbers.contains(number),
              let index = windowNumbers.firstIndex(of: number) else {
            return nil
        }
        return index
    }

    // PERSISTENCE:
    func persistAllTabIdsFromWindows() {
        let urls = NSApplication.shared.windows.compactMap { window in
            window.accessibilityURL()
        }
        UserDefaults.standard[.windowURLs] = urls
    }

    private func storeTabIDInCurrentWindow() {
        guard let tabID,
              let windowNumber,
              let currentWindow = windowBy(number: windowNumber) else {
            return
        }
        let url = tabID.uriRepresentation()
        currentWindow.setAccessibilityURL(url)
    }

    private func windowBy(number: Int) -> NSWindow? {
        NSApplication.shared.windows.first { $0.windowNumber == number }
    }
#endif

    private func createNewTabID() -> NSManagedObjectID {
        if let tabID { return tabID }
        let context = Database.viewContext
        let tab = Tab(context: context)
        tab.created = Date()
        tab.lastOpened = Date()
        try? context.obtainPermanentIDs(for: [tab])
        try? context.save()
        return tab.objectID
    }

    // MARK: - Bookmark

    func controller(_: NSFetchedResultsController<NSFetchRequestResult>,
                    didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        articleBookmarked = !snapshot.itemIdentifiers.isEmpty
    }

    func createBookmark(url: URL? = nil) {
        guard let url = url ?? webView.url else { return }
        Database.performBackgroundTask { context in
            let bookmark = Bookmark(context: context)
            bookmark.articleURL = url
            bookmark.created = Date()
            guard let zimFileID = UUID(uuidString: url.host ?? ""),
                  let zimFile = try? context.fetch(ZimFile.fetchRequest(fileID: zimFileID)).first,
                  let metaData = ZimFileService.shared.getContentMetaData(url: url) else { return }

            bookmark.zimFile = zimFile
            if metaData.isTextType,
               let parser = try? HTMLParser(url: url) {
                bookmark.title = parser.title ?? metaData.zimTitle
                if let imagePath = parser.getFirstImagePath() {
                    bookmark.thumbImageURL = URL(zimFileID: zimFileID.uuidString, contentPath: imagePath)
                }
                bookmark.snippet = parser.getFirstSentence(languageCode: nil)?.string
            } else if metaData.isPDFType,
                      let pdfData = ZimFileService.shared.getURLContent(url: url)?.data,
                      let parser = PDFDocument(data: pdfData) {

                let pdfTitle = parser.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
                bookmark.title = pdfTitle ?? metaData.zimTitle

                if let firstPage = parser.page(at: 0),
                   let pdfSnippetSubString = firstPage.string?.split(separator: ".").first {
                    bookmark.snippet = String(pdfSnippetSubString)
                }
            } else {
                bookmark.title = metaData.zimTitle
            }
            try? context.save()
        }
    }

    func deleteBookmark(url: URL? = nil) {
        guard let url = url ?? webView.url else { return }
        Database.performBackgroundTask { context in
            let request = Bookmark.fetchRequest(predicate: NSPredicate(format: "articleURL == %@", url as CVarArg))
            guard let bookmark = try? context.fetch(request).first else { return }
            context.delete(bookmark)
            try? context.save()
        }
    }

    // MARK: - Outline

    /// Scroll to an outline item
    /// - Parameter outlineItemID: ID of the outline item to scroll to
    func scrollTo(outlineItemID: String) {
        webView.evaluateJavaScript("scrollToHeading('\(outlineItemID)')")
    }

    /// Convert flattened heading element data to a list of OutlineItems.
    /// - Parameter headings: list of heading element data retrieved from webview
    private func generateOutlineList(headings: [[String: String]]) {
        let allLevels = headings.compactMap { Int($0["tag"]?.suffix(1) ?? "") }
        let offset = allLevels.filter { $0 == 1 }.count == 1 ? 2 : allLevels.min() ?? 0
        let outlineItems: [OutlineItem] = headings.enumerated().compactMap { index, heading in
            guard let id = heading["id"],
                  let text = heading["text"],
                  let tag = heading["tag"],
                  let level = Int(tag.suffix(1)) else { return nil }
            return OutlineItem(id: id, index: index, text: text, level: max(level - offset, 0))
        }
        DispatchQueue.main.async {
            self.outlineItems = outlineItems
        }
    }

    /// Convert flattened heading element data to a tree of OutlineItems.
    /// - Parameter headings: list of heading element data retrieved from webview
    private func generateOutlineTree(headings: [[String: String]]) {
        let root = OutlineItem(index: -1, text: "", level: 0)
        var stack: [OutlineItem] = [root]
        var all = [String: OutlineItem]()

        headings.enumerated().forEach { index, heading in
            guard let id = heading["id"],
                  let text = heading["text"],
                  let tag = heading["tag"], let level = Int(tag.suffix(1)) else { return }
            let item = OutlineItem(id: id, index: index, text: text, level: level)
            all[item.id] = item

            // get last item in stack
            // if last item is child of item's sibling, unwind stack until a sibling is found
            guard var lastItem = stack.last else { return }
            while lastItem.level > item.level {
                stack.removeLast()
                lastItem = stack[stack.count - 1]
            }

            // if item is last item's sibling, add item to parent and replace last item with itself in stack
            // if item is last item's child, add item to parent and add item to stack
            if lastItem.level == item.level {
                stack[stack.count - 2].addChild(item)
                stack[stack.count - 1] = item
            } else if lastItem.level < item.level {
                stack[stack.count - 1].addChild(item)
                stack.append(item)
            }
        }

        // if there is only one h1, flatten one level
        if let rootChildren = root.children, rootChildren.count == 1, let rootFirstChild = rootChildren.first {
            let children = rootFirstChild.removeAllChildren()
            DispatchQueue.main.async {
                self.outlineItemTree = [rootFirstChild] + children
            }
        } else {
            DispatchQueue.main.async {
                self.outlineItemTree = root.children ?? []
            }
        }
    }

    private static func bookmarksPredicateFor(url: URL?) -> NSPredicate? {
        guard let url else { return nil }
        return NSPredicate(format: "articleURL == %@", url as CVarArg)
    }
}
