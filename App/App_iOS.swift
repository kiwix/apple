//  Copyright © 2023 Kiwix.

import SwiftUI
import UserNotifications

#if os(iOS)
@main
struct Kiwix: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = LibraryViewModel()
    @StateObject private var navigation = NavigationViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    private let fileMonitor: DirectoryMonitor
    
    init() {
        fileMonitor = DirectoryMonitor(url: URL.documentDirectory) { LibraryOperations.scanDirectory($0) }
        LibraryOperations.registerBackgroundTask()
        UNUserNotificationCenter.current().delegate = appDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .ignoresSafeArea()
                .environment(\.managedObjectContext, Database.viewContext)
                .environmentObject(library)
                .environmentObject(navigation)
                .modifier(AlertHandler())
                .modifier(OpenFileHandler())
                .onChange(of: scenePhase) { newValue in
                    guard newValue == .inactive else { return }
                    try? Database.viewContext.save()
                }
                .onOpenURL { url in
                    if url.isFileURL {
                        NotificationCenter.openFiles([url], context: .file)
                    } else if url.scheme == "kiwix" {
                        NotificationCenter.openURL(url)
                    }
                }
                .task {
                    if FeatureFlags.hasLibrary {
                        fileMonitor.start()
                        LibraryOperations.reopen {
                            navigation.navigateToMostRecentTab()
                        }
                        LibraryOperations.scanDirectory(URL.documentDirectory)
                        LibraryOperations.applyFileBackupSetting()
                        LibraryOperations.applyLibraryAutoRefreshSetting()
                        DownloadService.shared.restartHeartbeatIfNeeded()
                    } else if let url = Brand.mainZimFileURL {
                        LibraryOperations.open(url: url) {
                            navigation.navigateToMostRecentTab()
                        }
                    } else {
                        assertionFailure("App should support library, or should have a main zip file")
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                NavigationCommands()
            }
            CommandGroup(replacing: .textFormatting) {
                PageZoomCommands()
            }
        }
    }
    
    private class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
        /// Storing background download completion handler sent to application delegate
        func application(_ application: UIApplication,
                         handleEventsForBackgroundURLSession identifier: String,
                         completionHandler: @escaping () -> Void) {
            DownloadService.shared.backgroundCompletionHandler = completionHandler
        }

        /// Handling file download complete notification
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            if let zimFileID = UUID(uuidString: response.notification.request.identifier),
               let mainPageURL = ZimFileService.shared.getMainPageURL(zimFileID: zimFileID) {
                NotificationCenter.openURL(mainPageURL, inNewTab: true)
            }
            completionHandler()
        }
        
        /// Purge some cached browser view models when receiving memory warning
        func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
            BrowserViewModel.purgeCache()
        }
    }
}

private struct RootView: UIViewControllerRepresentable {
    @EnvironmentObject private var navigation: NavigationViewModel
    
    func makeUIViewController(context: Context) -> SplitViewController {
        SplitViewController(navigationViewModel: navigation)
    }
    
    func updateUIViewController(_ controller: SplitViewController, context: Context) {
    }
}
#endif
