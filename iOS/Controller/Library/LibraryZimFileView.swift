//
//  LibraryZimFileView.swift
//  Kiwix
//
//  Created by Chris Li on 1/23/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import SwiftUI
import RealmSwift

@available(iOS 13.0, *)
struct LibraryZimFileView: View {
    @ObservedObject private var viewModel: ViewModel
    private let zimFile: ZimFile
    
    init(_ zimFile: ZimFile) {
        self.zimFile = zimFile
        self.viewModel = ViewModel(zimFile)
    }
    
    var body: some View {
        SwiftUI.List {
            Section {
                Text(zimFile.title)
                Text(zimFile.fileDescription)
            }
            Section {
                switch viewModel.state {
                case ZimFile.State.remote:
                    Button(action: {}, label: { row(action: "Download")} )
                default:
                    Button(action: {}, label: { row(action: "Cancel") })
                }
                
//                Button(action: {}, label: { row(action: "Pause") })
//                Button(action: {}, label: { row(action: "Cancel") })
//                Button(action: {}, label: { row(action: "Delete", isDestructive: true) })
//                Button(action: {}, label: { row(action: "Unlink", isDestructive: true) })
            }
            Section {
                row(title: "Language", detail: zimFile.languageDescription)
                row(title: "Size", detail: zimFile.sizeDescription)
                row(title: "Date", detail: zimFile.creationDateDescription)
            }
            Section {
                row(title: "Pictures", isEnabled: zimFile.hasPictures)
                row(title: "Videos", isEnabled: zimFile.hasVideos)
                row(title: "Details", isEnabled: zimFile.hasDetails)
            }
            Section {
                row(title: "Article Count", detail: zimFile.articleCountDescription)
                row(title: "Media Count", detail: zimFile.mediaCountDescription)
            }
            Section {
                row(title: "Creator", detail: zimFile.creator)
                row(title: "Publisher", detail: zimFile.publisher)
            }
            Section {
                row(title: "ID", detail: zimFile.shortID)
            }
        }
        .insetGroupedListStyle()
        .navigationBarTitle(zimFile.title)
    }
    
    func row(action: String, isDestructive: Bool = false) -> some View {
        HStack {
            Spacer()
            if isDestructive {
                Text(action).fontWeight(.medium).foregroundColor(.red)
            } else {
                Text(action).fontWeight(.medium)
            }
            Spacer()
        }
    }
    
    func row(title: String, detail: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(detail ?? "Unknown").foregroundColor(.secondary)
        }
    }
    
    func row(title: String, isEnabled: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isEnabled{
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            } else {
                Image(systemName: "multiply.circle.fill").foregroundColor(.secondary)
            }
        }
    }
}

@available(iOS 13.0, *)
private class ViewModel: ObservableObject {
    @Published var state: ZimFile.State
    private var notificationToken : NotificationToken?
    
    init(_ zimFile: ZimFile) {
        self.state = zimFile.state
        self.notificationToken = zimFile.observe { change in
            switch change {
                case .change(let object, let properties):
                    guard let zimFile = object as? ZimFile else { return }
                    for property in properties {
                        if property.name == "stateRaw" {
                            self.state = zimFile.state
                        }
                    }
                case .deleted:
                    print("The object was deleted.")
                default:
                    break
                }
        }
    }
}

@available(iOS 13.0, *)
struct LibraryZimFileView_Previews: PreviewProvider {
    static var previews: some View {
        let zimFile = ZimFile()
        LibraryZimFileView(zimFile)
            .previewDevice("iPhone 12 Pro")
    }
}
