//
//  ZimFileList.swift
//  Kiwix
//
//  Created by Chris Li on 4/24/22.
//  Copyright © 2022 Chris Li. All rights reserved.
//

import SwiftUI

struct ZimFileList: View {
    @FetchRequest private var zimFiles: FetchedResults<ZimFile>
    @State private var searchText = ""
    @State private var selectedZimFile: ZimFile?
    
    let category: Category
    
    init(category: Category) {
        self.category = category
        self._zimFiles = {
            let request = ZimFile.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ZimFile.name, ascending: true)]
            request.predicate = ZimFileList.generatePredicate(category: category, searchText: "")
            return FetchRequest<ZimFile>(fetchRequest: request)
        }()
    }
    
    var body: some View {
        List(zimFiles) { zimFile in
            NavigationLink {
                Text("Detail about zim file: \(zimFile.name)")
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(zimFile.name).lineLimit(1)
                    Text([
                        Library.dateFormatter.string(from: zimFile.created),
                        Library.sizeFormatter.string(fromByteCount: zimFile.size)
                    ].joined(separator: ", ")).font(.caption)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(category.description)
        .modifier(Searchable(searchText: $searchText))
        .onChange(of: searchText) { _ in
            if #available(iOS 15.0, *) {
                zimFiles.nsPredicate = ZimFileList.generatePredicate(category: category, searchText: searchText)
            }
        }
    }
    
    private static func generatePredicate(category: Category, searchText: String) -> NSPredicate {
        var predicates = [
            NSPredicate(format: "languageCode == %@", "en"),
            NSPredicate(format: "category == %@", category.rawValue)
        ]
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", searchText))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
