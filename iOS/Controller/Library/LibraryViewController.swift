//
//  LibraryViewController.swift
//  Kiwix
//
//  Created by Chris Li on 1/16/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 14.0, *)
class LibraryViewController: UISplitViewController {
    init() {
        super.init(style: .doubleColumn)
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        presentsWithGesture = false
        
        setViewController(UIHostingController(rootView: LibrarySidebarView()), for: .primary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 14.0, *)
struct LibrarySidebarView: View {
    @State private var isActive = false
    var body: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(ZimFile.Category.allCases) { category in
                    HStack {
                        Image(uiImage: category.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 20, maxHeight: 20)
                            .padding(2)
                            .background(Color(.white))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        Text(category.description)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(Font.footnote.weight(.bold))
                            .foregroundColor(.secondary)
                    }
                    NavigationLink(category.description, destination: EmptyView(), isActive: $isActive)
                }
            }
        }.listStyle(GroupedListStyle())
    }
}

@available(iOS 14.0, *)
struct LibraryCategoryView: View {
    let category: ZimFile.Category
    
    var body: some View {
        Text("category")
    }
}
