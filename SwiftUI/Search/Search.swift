//
//  Search.swift
//  Kiwix
//
//  Created by Chris Li on 5/30/22.
//  Copyright © 2022 Chris Li. All rights reserved.
//

import SwiftUI

#if os(macOS)
struct Search: View {
    @State var searchText = ""
    
    var body: some View {
        ZStack {
            List {}.searchable(text: $searchText, placement: .sidebar, prompt: Text("Search")) {
                Text("result 1")
                Text("result 2")
                Text("result 3")
            }
            List {
                Text("result 1")
                Text("result 2")
                Text("result 3")
            }
            .padding(.top, 34)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SearchFilter().frame(height: 200)
        }
    }
}
#elseif os(iOS)
struct Search: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                SearchFilter().listStyle(.grouped).frame(width: 320)
                Divider().ignoresSafeArea(.container, edges: .bottom)
                List {
                    Text("result 1")
                    Text("result 2")
                    Text("result 3")
                }
                .listStyle(.plain)
            }
        } else {
            SearchFilter()
        }
    }
}
#endif
