//
//  RootView_macOS.swift
//  Kiwix for macOS
//
//  Created by Chris Li on 8/2/22.
//  Copyright © 2022 Chris Li. All rights reserved.
//

import SwiftUI

struct RootView_macOS: View {
    @State private var navigationItem: NavigationItem? = .reading
    @State private var url: URL?
    @State private var searchText = ""
    @StateObject private var readingViewModel = ReadingViewModel()
    
    private let primaryNavigationItems: [NavigationItem] = [.reading, .bookmarks, .map]
    private let libraryNavigationItems: [NavigationItem] = [.opened, .categories, .new, .downloads]
        
    var body: some View {
        NavigationView {
            List(selection: $navigationItem) {
                ForEach(primaryNavigationItems, id: \.self) { navigationLink($0) }
                Section {
                    ForEach(libraryNavigationItems, id: \.self) { navigationLink($0) }
                } header: { Text("Library") }
            }
            .frame(minWidth: 150)
            .toolbar { SidebarButton() }
            EmptyView()  // required so the UI does not look broken on macOS
        }
        .environment(\.managedObjectContext, Database.shared.container.viewContext)
        .onOpenURL { url in
            if url.isFileURL {
                guard let metadata = ZimFileService.getMetaData(url: url) else { return }
                LibraryViewModel.open(url: url)
                self.url = ZimFileService.shared.getMainPageURL(zimFileID: metadata.fileID)
            } else if url.scheme == "kiwix" {
                self.url = url
            }
        }
    }
    
    @ViewBuilder
    private func navigationLink(_ navigationItem: NavigationItem) -> some View {
        NavigationLink(tag: navigationItem, selection: $navigationItem) {
            destination(navigationItem)
        } label: {
            Label(navigationItem.name, systemImage: navigationItem.icon)
        }
    }
    
    @ViewBuilder
    private func destination(_ navigationItem: NavigationItem) -> some View {
        switch navigationItem {
        case .reading:
            ReadingView(url: $url).searchable(text: $searchText).environmentObject(readingViewModel)
        case .bookmarks:
            Text(navigationItem.name)
        case .map:
            MapView()
        case .opened:
            ZimFilesOpened()
        case .categories:
            Text(navigationItem.name)
        case .new:
            Text(navigationItem.name)
        case .downloads:
            Text(navigationItem.name)
        default:
            EmptyView()
        }
    }
}

private enum NavigationItem: String, Identifiable, CaseIterable {
    var id: String { rawValue }

    case reading, bookmarks, map, opened, categories, new, downloads, settings

    var name: String {
        switch self {
        case .reading:
            return "Reading"
        case .bookmarks:
            return "Bookmarks"
        case .map:
            return "Map"
        case .settings:
            return "Settings"
        case .opened:
            return "Opened"
        case .categories:
            return "Categories"
        case .new:
            return "New"
        case .downloads:
            return "Downloads"
        }
    }
    
    var icon: String {
        switch self {
        case .reading:
            return "book"
        case .bookmarks:
            return "star"
        case .map:
            return "map"
        case .settings:
            return "gear"
        case .opened:
            return "folder"
        case .categories:
            return "books.vertical"
        case .new:
            return "newspaper"
        case .downloads:
            return "tray.and.arrow.down"
        }
    }
}