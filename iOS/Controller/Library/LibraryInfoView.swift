//
//  LibraryInfoView.swift
//  Kiwix
//
//  Created by Chris Li on 2/1/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import SwiftUI
import Defaults

@available(iOS 13.0, *)
struct LibraryInfoView: View {
    @Default(.libraryLastRefreshTime) private var lastRefreshTime
    @Default(.libraryAutoRefresh) private var isAutoRefreshEnabled
    @Default(.backupDocumentDirectory) private var isBackingUpDocumentDirectory
    @Default(.libraryFilterLanguageCodes) private var languageCodes
    
    var dismiss: (() -> Void) = {}
    private let updateFooter = """
        With auto update enabled, the catalog will be updated both when library \
        is opened and utilizing iOS's Background App Refresh feature.
        """
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink("Language", destination: Text("Languages"))
                }
                Section(header: Text("Update"), footer: Text(updateFooter)) {
                    HStack {
                        Text("Last updated")
                        Spacer()
                        lastUpdatedTime.foregroundColor(.secondary)
                    }
                    Toggle("Auto update", isOn: $isAutoRefreshEnabled)
                    HStack {
                        Spacer()
                        Button("Update now") { }
                        Spacer()
                    }
                }
                Section(header: Text("Backup"), footer: Text("Does not apply to files that were opened in place.")) {
                    Toggle("Include files in backup", isOn: $isBackingUpDocumentDirectory)
                }
            }
            .insetGroupedListStyle()
            .navigationBarTitle("Info", displayMode: .inline)
            .navigationBarItems(leading: Button("Done", action: dismiss))
        }.navigationViewStyle(StackNavigationViewStyle())
    }
    
    var lastUpdatedTime: some View {
        if let refreshTime = Defaults[.libraryLastRefreshTime] {
            if Date().timeIntervalSince(refreshTime) < 120 {
                return Text("Just now")
            } else {
                return Text(RelativeDateTimeFormatter().localizedString(for: refreshTime, relativeTo: Date()))
            }
        } else {
            return Text("Never")
        }
    }
}

