//
//  ZimFileCell.swift
//  Kiwix
//
//  Created by Chris Li on 9/5/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

import SwiftUI
import RealmSwift

@available(iOS 14.0, *)
struct ZimFileCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let zimFile: ZimFile
    let withIncludedInSearchIcon: Bool
    var tapped: (() -> Void)?
    
    init (_ zimFile: ZimFile, withIncludedInSearchIcon: Bool = false, tapped: (() -> Void)? = nil) {
        self.zimFile = zimFile
        self.withIncludedInSearchIcon = withIncludedInSearchIcon
        self.tapped = tapped
    }
    
    var body: some View {
        Button(action: {
            tapped?()
        }, label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Favicon(zimFile: zimFile)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zimFile.title).font(.headline).lineLimit(1)
                        if zimFile.fileDescription.count > 0 {
                            Text(zimFile.fileDescription).font(.caption).lineLimit(4)
                        }
                        Spacer(minLength: 0)
                    }
                    if withIncludedInSearchIcon {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .hidden(!zimFile.includedInSearch)
                    }
                }
                Divider()
                HStack {
                    Label(zimFile.sizeDescription ?? "Unknown", systemImage: "internaldrive")
                    Spacer()
                    Label(zimFile.articleCountShortDescription ?? "Unknown", systemImage: "doc.text")
                    Spacer()
                    Label(zimFile.creationDateShortDescription ?? "Unknown", systemImage: "calendar")
                }.font(.caption).foregroundColor(.secondary)
            }.padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        })
        .buttonStyle(Style(colorScheme: colorScheme))
    }
    
    private struct Style: ButtonStyle {
        let colorScheme: ColorScheme
        
        private func makeFillColor(_ configuration: Configuration) -> Color {
            switch (configuration.isPressed, colorScheme) {
            case (true, .light):
                return Color(.systemGray5)
            case (true, .dark):
                return Color(.tertiarySystemGroupedBackground)
            default:
                return Color(.secondarySystemGroupedBackground)
            }
        }
        
        func makeBody(configuration: Configuration) -> some View {
            let background = RoundedRectangle(cornerRadius: 10, style: .continuous).fill(makeFillColor(configuration))
            return configuration.label.background(background)
        }
    }
}

@available(iOS 14.0, *)
struct ZimFileCell_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                ForEach(1..<10) { _ in
                    ZimFileCell(ZimFile(value: [
                        "title": "ZimFile Title",
                        "fileDescription": "Lorem Ipsum is simply dummy text of the printing and typesetting industry.",
                        "size": 10000000000,
                        "articleCount": 500000,
                        "creationDate": Date(),
                    ]))
                }
            }
            .padding(.all, 10)
        }
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
        .environment(\.colorScheme, .dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 11"))
    }
}
