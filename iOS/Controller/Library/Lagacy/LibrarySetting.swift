//
//  LibrarySetting.swift
//  Kiwix
//
//  Created by Chris Li on 4/23/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//


import SwiftUI

@available(iOS 13.0, *)
struct LibrarySettingList: View {
    @State var isOn = true // toggle state
    var body: some View {
        List {
            Section(header: Text("Catalog")) {
                HStack {
                    Spacer()
                    Button("Update now") {
                        print("tapped")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    Spacer()
                }
                HStack() {
                    Text("Last update")
                    Spacer()
                    Text("5 mins ago").foregroundColor(.secondary)
                }
                Toggle("Auto update", isOn: $isOn)
            }
            Section(header: Text("Backup")) {
                Toggle("zim files", isOn: $isOn)
            }
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, .regular)
    }
}

@available(iOS 13.0, *)
struct LibrarySetting_Previews: PreviewProvider {
    static var previews: some View {
        LibrarySettingList()
            .environment(\.colorScheme, .dark)
            .previewDevice(PreviewDevice(rawValue: "iPhone X"))
    }
}

@available(iOS 13.0, *)
class LibrarySetttingController: UIHostingController<NavigationView<LibrarySettingList>> {
    convenience init() {
        self.init(rootView: NavigationView {
            LibrarySettingList()
        })
    }
}
