//
//  App_macOS.swift
//  Kiwix
//
//  Created by Chris Li on 8/13/23.
//  Copyright © 2023 Chris Li. All rights reserved.
//

import SwiftUI
import UserNotifications
import Combine
import Defaults
import CoreKiwix

#if os(macOS)
@main
struct Kiwix: App {
    @StateObject private var libraryRefreshViewModel = LibraryViewModel()
    private let notificationCenterDelegate = NotificationCenterDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, Database.shared.container.viewContext)
                .environmentObject(libraryRefreshViewModel)
        }.commands {
            SidebarCommands()
            CommandGroup(replacing: .importExport) {
                OpenFileButton(context: .command) { Text("app_macos_commands.open_file".localized) }
            }
            CommandGroup(replacing: .newItem) {
                Button("app_macos_commands.new".localized) {
                    guard let currentWindow = NSApp.keyWindow,
                          let controller = currentWindow.windowController else { return }
                    controller.newWindowForTab(nil)
                    guard let newWindow = NSApp.keyWindow, currentWindow != newWindow else { return }
                    currentWindow.addTabbedWindow(newWindow, ordered: .above)
                }.keyboardShortcut("t")
                Divider()
            }
            CommandGroup(after: .toolbar) {
                NavigationCommands()
                Divider()
                PageZoomCommands()
                Divider()
                SidebarNavigationCommands()
                Divider()
            }
        }
        Settings {
            TabView {
                ReadingSettings()
                if FeatureFlags.hasLibrary {
                    LibrarySettings()
                        .environmentObject(libraryRefreshViewModel)
                }
                About()
            }
            .frame(width: 550, height: 400)
        }
    }

    private class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
        /// Handling file download complete notification
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            if let zimFileID = UUID(uuidString: response.notification.request.identifier),
               let mainPageURL = ZimFileService.shared.getMainPageURL(zimFileID: zimFileID) {
                NSWorkspace.shared.open(mainPageURL)
            }
            completionHandler()
        }
    }
}

struct RootView: View {
    @Environment(\.controlActiveState) var controlActiveState
    @StateObject private var browser = BrowserViewModel()
    @StateObject private var navigation = NavigationViewModel()
    
    private let primaryItems: [NavigationItem] = [.reading, .bookmarks]
    private let libraryItems: [NavigationItem] = [.opened, .categories, .downloads, .new]
    private let openURL = NotificationCenter.default.publisher(for: .openURL)
    private let appTerminates = NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)

    var body: some View {
        NavigationView {
            List(selection: $navigation.currentItem) {
                ForEach(primaryItems, id: \.self) { navigationItem in
                    Label(navigationItem.name, systemImage: navigationItem.icon)
                }
                if FeatureFlags.hasLibrary {
                    Section("app_macos_navigation.button.library".localized) {
                        ForEach(libraryItems, id: \.self) { navigationItem in
                            Label(navigationItem.name, systemImage: navigationItem.icon)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Link(destination: URL(string: "donations.url".localized)!) {
                    HStack {
                        Image(systemName: "heart")
                        Text("enum.navigation_item.donations".localized)
                            .foregroundColor(.primary)
                    }
                    .padding()}
            }
            .frame(minWidth: 150)
            .toolbar {
                Button {
                    guard let responder = NSApp.keyWindow?.firstResponder else { return }
                    responder.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                } label: {
                    Image(systemName: "sidebar.leading")
                }.help("app_macos_navigation.show_sidebar".localized)
            }
            switch navigation.currentItem {
            case .loading:
                LoadingView()
            case .reading:
                BrowserTab().environmentObject(browser)
                    .withHostingWindow { window in
                        if let windowNumber = window?.windowNumber {
                            browser.restoreByWindowNumber(windowNumber: windowNumber,
                                                          urlToTabIdConverter: navigation.tabIDFor(url:))
                        } else {
                            if FeatureFlags.hasLibrary == false {
                                browser.loadMainArticle()
                            }
                        }
                    }
            case .bookmarks:
                Bookmarks()
            case .opened:
                ZimFilesOpened().modifier(LibraryZimFileDetailSidePanel())
            case .categories:
                ZimFilesCategories().modifier(LibraryZimFileDetailSidePanel())
            case .downloads:
                ZimFilesDownloads().modifier(LibraryZimFileDetailSidePanel())
            case .new:
                ZimFilesNew().modifier(LibraryZimFileDetailSidePanel())
            default:
                EmptyView()
            }
        }
        .frame(minWidth: 650, minHeight: 500)
        .focusedSceneValue(\.navigationItem, $navigation.currentItem)
        .environmentObject(navigation)
        .modifier(AlertHandler())
        .modifier(OpenFileHandler())
        .onOpenURL { url in
            if url.isFileURL {
                NotificationCenter.openFiles([url], context: .file)
            } else if url.scheme == "kiwix" {
                NotificationCenter.openURL(url)
            }
        }
        .onReceive(openURL) { notification in
            guard controlActiveState == .key, let url = notification.userInfo?["url"] as? URL else { return }
            navigation.currentItem = .reading
            browser.load(url: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification), perform: { output in
            guard let window = output.object as? NSWindow else { return }
            if window.isKeyWindow && window.isMainWindow { // if this is the very last window, close the app
                NSApp.terminate(nil)
            }
        })
        .onReceive(appTerminates) { _ in
            browser.persistAllTabIdsFromWindows()
        }.task {
            switch AppType.current {
            case .kiwix:
                LibraryOperations.reopen {
                    navigation.currentItem = .reading
                }
                LibraryOperations.scanDirectory(URL.documentDirectory)
                LibraryOperations.applyFileBackupSetting()
                DownloadService.shared.restartHeartbeatIfNeeded()
            case let .custom(zimFileURL):
                LibraryOperations.open(url: zimFileURL) {
                    Task {
                        await ZimMigration.forCustomApps()
                        navigation.currentItem = .reading
                    }
                }
            }
        }
    }
}

// MARK: helpers to capture the window

extension View {
    func withHostingWindow(_ callback: @escaping (NSWindow?) -> Void) -> some View {
        self.background(HostingWindowFinder(callback: callback))
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    typealias NSViewType = NSView
    var callback: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            self.callback(view?.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

#endif
