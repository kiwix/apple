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
//    @ObservedObject private var viewModel: ViewModel
    private let zimFile: ZimFile
    
    init(_ zimFile: ZimFile) {
        self.zimFile = zimFile
//        self.viewModel = ViewModel(zimFileID: zimFile.id)
    }
    
    var body: some View {
        SwiftUI.List {
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

//@available(iOS 13.0, *)
//private class ViewModel: ObservableObject {
//
//
//    let id: String
//    let shortID: String
//    let language: String?
//    let creator: String?
//    let publisher: String?
//    let articleCount: String?
//    let mediaCount: String?
//
//    init(zimFileID: String) {
//        self.id = zimFileID
//        self.shortID = String(zimFileID.prefix(8))
//
//        if let database = try? Realm(configuration: Realm.defaultConfig),
//           let zimFile = database.object(ofType: ZimFile.self, forPrimaryKey: zimFileID) {
//            self.language = Locale.current.localizedString(forLanguageCode: zimFile.languageCode)
//            self.creator = zimFile.creator
//            self.publisher = zimFile.publisher
//            self.articleCount = ViewModel.numberFormatter.string(from: NSNumber(value: zimFile.articleCount.value ?? 0))
//            self.mediaCount = ViewModel.numberFormatter.string(from: NSNumber(value: zimFile.mediaCount.value ?? 0))
//        } else {
//            self.language = nil
//            self.creator = nil
//            self.publisher = nil
//            self.articleCount = nil
//            self.mediaCount = nil
//        }
//    }
//}



@available(iOS 13.0, *)
struct LibraryZimFileView_Previews: PreviewProvider {
    static var previews: some View {
        let zimFile = ZimFile()
        LibraryZimFileView(zimFile)
            .previewDevice("iPhone 12 Pro")
    }
}
