//
//  LibraryZimFileView.swift
//  Kiwix
//
//  Created by Chris Li on 1/23/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
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
                case .remote:
                    Button(action: {
                        DownloadService.shared.start(zimFileID: zimFile.id, allowsCellularAccess: false)
                    }, label: { row(action: "Download")} )
                case .onDevice:
                    Button(action: {}, label: { row(action: "Delete", isDestructive: true) })
                case .downloadQueued:
                    Text("Queued")
                    cancelButton
                case .downloadInProgress:
                    if #available(iOS 14.0, *), let progress = viewModel.downloadProgress {
                        ProgressView(progress)
                    } else {
                        Text("Downloading...")
                    }
                    pauseButton
                    cancelButton
                case .downloadPaused:
                    HStack {
                        Text("Paused")
                        if let progress = viewModel.downloadProgress {
                            Spacer()
                            Text(progress.localizedAdditionalDescription)
                        }
                    }
                    resumeButton
                case .downloadError:
                    Text("Error")
                    if let errorDescription = zimFile.downloadErrorDescription {
                        Text(errorDescription)
                    }
                default:
                    cancelButton
                }
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
                    .contextMenu(ContextMenu(menuItems: {
                        Button("Copy") { UIPasteboard.general.string = zimFile.id }
                    }))
            }
        }
        .insetGroupedListStyle()
        .navigationBarTitle(zimFile.title)
    }
    
    var pauseButton: some View {
        Button(action: {
            DownloadService.shared.pause(zimFileID: zimFile.id)
        }, label: { row(action: "Pause") })
    }
    
    var cancelButton: some View {
        Button(action: {
            DownloadService.shared.cancel(zimFileID: zimFile.id)
        }, label: { row(action: "Cancel") })
    }
    
    var resumeButton: some View {
        Button(action: {
            DownloadService.shared.resume(zimFileID: zimFile.id)
        }, label: { row(action: "Resume") })
    }
    
    func row(action: String, isDestructive: Bool = false) -> some View {
        HStack {
            Spacer()
            Text(action)
                .fontWeight(.medium)
                .foregroundColor(isDestructive ? .red : nil)
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
    @Published var downloadProgress: Progress?
    private var stateObserver: NotificationToken?
    
    init(_ zimFile: ZimFile) {
        self.state = zimFile.state
        if let fileSize = zimFile.size.value {
            self.downloadProgress = Progress(totalUnitCount: fileSize)
            self.downloadProgress?.completedUnitCount = zimFile.downloadTotalBytesWritten
            self.downloadProgress?.kind = .file
            self.downloadProgress?.fileOperationKind = .downloading
            self.downloadProgress?.fileTotalCount = 1
        } else {
            self.downloadProgress = nil
        }
        
        guard let database = try? Realm(configuration: Realm.defaultConfig),
              let zimFile = database.object(ofType: ZimFile.self, forPrimaryKey: zimFile.id) else { return }
        stateObserver = zimFile.observe { [weak self] change in
            switch change {
                case .change(let object, let properties):
                    guard let zimFile = object as? ZimFile else { return }
                    for property in properties {
                        if property.name == "stateRaw" { self?.state = zimFile.state }
                        if property.name == "downloadTotalBytesWritten" {
                            withAnimation {
                                self?.downloadProgress?.completedUnitCount = zimFile.downloadTotalBytesWritten
                            }
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
