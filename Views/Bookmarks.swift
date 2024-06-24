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

import SwiftUI

struct Bookmarks: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.created, order: .reverse)],
        predicate: Bookmarks.buildPredicate(searchText: ""),
        animation: .easeInOut
    ) private var bookmarks: FetchedResults<Bookmark>
    @State private var searchText = ""

    var body: some View {
        LazyVGrid(columns: ([gridItem]), spacing: 12) {
            ForEach(bookmarks) { bookmark in
                Button {
                    NotificationCenter.openURL(bookmark.articleURL)
                    if horizontalSizeClass == .compact {
                        dismiss()
                    }
                } label: {
                    ArticleCell(bookmark: bookmark)
                }
                .buttonStyle(.plain)
                .modifier(BookmarkContextMenu(bookmark: bookmark))
            }
        }
        .modifier(GridCommon())
        .modifier(ToolbarRoleBrowser())
        .navigationTitle("bookmark.navigation.title".localized)
        .searchable(text: $searchText, prompt: "common.search".localized)
        .onChange(of: searchText) { searchText in
            bookmarks.nsPredicate = Bookmarks.buildPredicate(searchText: searchText)
        }
        .overlay {
            if bookmarks.isEmpty {
                Message(text: "bookmark.overlay.empty.title".localized)
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                if #unavailable(iOS 16), horizontalSizeClass == .regular {
                    Button {
                        NotificationCenter.toggleSidebar()
                    } label: {
                        Label("bookmark.toolbar.show_sidebar.label".localized, systemImage: "sidebar.left")
                    }
                }
            }
            #endif
        }
    }

    private var gridItem: GridItem {
        #if os(macOS)
        GridItem(.adaptive(minimum: 250, maximum: 500), spacing: 12)
        #elseif os(iOS)
        GridItem(.adaptive(minimum: 250, maximum: 500), spacing: 12)
        #endif
    }

    private static func buildPredicate(searchText: String) -> NSPredicate? {
        guard !searchText.isEmpty else { return nil }
        return NSPredicate(format: "title CONTAINS[cd] %@", searchText)
    }
}
