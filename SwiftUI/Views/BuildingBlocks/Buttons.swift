//
//  Buttons.swift
//  Kiwix
//
//  Created by Chris Li on 2/13/22.
//  Copyright © 2022 Chris Li. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

import Defaults

struct BookmarkToggleButton: View {
    @FetchRequest private var bookmarks: FetchedResults<Bookmark>
    
    private let url: URL?
    private var isBookmarked: Bool { !bookmarks.isEmpty }
    
    init(url: URL?) {
        self._bookmarks = FetchRequest<Bookmark>(sortDescriptors: [], predicate: {
            if let url = url {
                return NSPredicate(format: "articleURL == %@", url as CVarArg)
            } else {
                return NSPredicate(format: "articleURL == nil")
            }
        }())
        self.url = url
    }
    
    var body: some View {
        Button {
            if isBookmarked {
                BookmarkOperations.delete(url)
            } else {
                BookmarkOperations.create(url)
            }
        } label: {
            Label {
                Text(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
            } icon: {
                Image(systemName: isBookmarked ? "star.fill" : "star")
                    .renderingMode(isBookmarked ? .original : .template)
            }
        }
        .disabled(url == nil)
        .help(isBookmarked ? "Remove bookmark" : "Bookmark the current article")
    }
}

struct BookmarkMultiButton: View {
    @EnvironmentObject var viewModel: ViewModel
    @FetchRequest private var bookmarks: FetchedResults<Bookmark>
    
    private let url: URL?
    private var isBookmarked: Bool { !bookmarks.isEmpty }
    
    init(url: URL?) {
        self._bookmarks = FetchRequest<Bookmark>(sortDescriptors: [], predicate: {
            if let url = url {
                return NSPredicate(format: "articleURL == %@", url as CVarArg)
            } else {
                return NSPredicate(format: "articleURL == nil")
            }
        }())
        self.url = url
    }
    
    var body: some View {
        Button { } label: {
            Image(systemName: isBookmarked ? "star.fill" : "star")
                .renderingMode(isBookmarked ? .original : .template)
        }
        .simultaneousGesture(TapGesture().onEnded {
            viewModel.activeSheet = .bookmarks
        })
        .simultaneousGesture(LongPressGesture().onEnded { _ in
            if isBookmarked {
                BookmarkOperations.delete(url)
            } else {
                BookmarkOperations.create(url)
            }
        })
        .help("Show bookmarks. Long press to bookmark or unbookmark the current article.")
    }
}

struct FileImportButton<Label: View>: View {
    @State private var isPresented: Bool = false
    
    let label: Label
    
    init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }
    
    var body: some View {
        Button {
            // On iOS 14 & 15, fileimporter's isPresented binding is not reset to false if user swipe to dismiss
            // the sheet. In order to mitigate the issue, the binding is set to false then true with a 0.1s delay.
            isPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                isPresented = true
            }
        } label: { label }
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: [UTType.zimFile],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(urls) = result else { return }
            for url in urls {
                LibraryOperations.open(url: url)
            }
        }
        .help("Open a zim file")
        .keyboardShortcut("o")
    }
}

struct LibraryButton: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        Button {
            viewModel.activeSheet = .library()
        } label: {
            Label("Library", systemImage: "folder")
        }
    }
}

struct MoreActionMenu: View {
    @Binding var url: URL?
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ZimFile.size, ascending: false)],
        predicate: ZimFile.openedPredicate
    ) private var zimFiles: FetchedResults<ZimFile>
    
    var body: some View {
        Menu {
            Section {
                ForEach(zimFiles) { zimFile in
                    Button {
                        url = ZimFileService.shared.getMainPageURL(zimFileID: zimFile.id)
                    } label: {
                        Label(zimFile.name, systemImage: "house")
                    }
                }
            }
            LibraryButton()
            SettingsButton()
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

struct NavigateBackButton: View {
    @EnvironmentObject var viewModel: ReadingViewModel
    
    var body: some View {
        Button {
            viewModel.goBack()
        } label: {
            Label("Go Back", systemImage: "chevron.backward")
        }
        .disabled(!viewModel.canGoBack)
        .help("Show the previous page")
    }
}

struct NavigateForwardButton: View {
    @EnvironmentObject var viewModel: ReadingViewModel
    
    var body: some View {
        Button {
            viewModel.goForward()
        } label: {
            Label("Go Forward", systemImage: "chevron.forward")
        }
        .disabled(!viewModel.canGoForward)
        .help("Show the next page")
    }
}

struct NavigationCommandButtons: View {
    @FocusedValue(\.canGoBack) var canGoBack: Bool?
    @FocusedValue(\.canGoForward) var canGoForward: Bool?
    @FocusedValue(\.readingViewModel) var viewModel: ReadingViewModel?
    
    var body: some View {
        Button("Go Back") { viewModel?.goBack() }
            .keyboardShortcut("[")
            .disabled(!(canGoBack ?? false))
        Button("Go Forward") { viewModel?.goForward() }
            .keyboardShortcut("]")
            .disabled(!(canGoForward ?? false))
    }
}

struct PageZoomButtons: View {
    @Default(.webViewPageZoom) var webViewPageZoom
    @FocusedBinding(\.navigationItem) var navigationItem: NavigationItem??
    @FocusedValue(\.url) var url: URL??
    
    var body: some View {
        Button("Actual Size") { webViewPageZoom = 1 }
            .keyboardShortcut("0")
            .disabled(webViewPageZoom == 1)
        Button("Zoom In") { webViewPageZoom += 0.1 }
            .keyboardShortcut("+")
            .disabled(navigationItem != .reading || (url ?? nil) == nil)
        Button("Zoom Out") { webViewPageZoom -= 0.1 }
            .keyboardShortcut("-")
            .disabled(navigationItem != .reading || (url ?? nil) == nil)
    }
}

struct SettingsButton: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        Button {
            viewModel.activeSheet = .settings
        } label: {
            Label("Settings", systemImage: "gear")
        }
    }
}

#if os(macOS)
struct SidebarButton: View {
    var body: some View {
        Button {
            guard let responder = NSApp.keyWindow?.firstResponder else { return }
            responder.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        } label: {
            Image(systemName: "sidebar.leading")
        }
        .help("Show sidebar")
    }
}
#endif

struct SidebarNavigationItemButtons: View {
    @FocusedBinding(\.navigationItem) var navigationItem: NavigationItem??
    
    var body: some View {
        buildButtons([.reading, .bookmarks], modifiers: [.command])
        Divider()
        buildButtons([.opened, .categories, .downloads, .new], modifiers: [.command, .control])
    }
    
    private func buildButtons(_ navigationItems: [NavigationItem], modifiers: EventModifiers = []) -> some View {
        ForEach(Array(navigationItems.enumerated()), id: \.element) { index, item in
            Button(item.name) {
                navigationItem = item
            }
            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: modifiers)
            .disabled(navigationItem == nil)
        }
    }
}
