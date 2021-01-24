//
//  LibraryZimFileView.swift
//  Kiwix
//
//  Created by Chris Li on 1/23/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import Combine
import SwiftUI
import Defaults
import RealmSwift

@available(iOS 13.0, *)
struct LibraryZimFileView: View {
    private let zimFile: ZimFile
    @Default(.downloadUsingCellular) private var downloadUsingCellular
    @State private var showingDeleteAlert = false
    @ObservedObject private var viewModel: ViewModel
    var zimFileDeleted: (() -> Void) = {} {
        didSet {
            viewModel.zimFileDeleted = zimFileDeleted
        }
    }
    
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
                    if viewModel.hasEnoughDiskSpace {
                        Toggle("Cellular Data", isOn: $downloadUsingCellular)
                        ActionButton(title: "Download") {
                            DownloadService.shared.start(
                                zimFileID: zimFile.id, allowsCellularAccess: downloadUsingCellular
                            )
                        }
                    } else {
                        ActionButton(title: "Download - Not Enough Space").disabled(true)
                    }
                case .onDevice:
                    ActionButton(title: "Delete", isDestructive: true) {
                        showingDeleteAlert = true
                    }
                case .downloadQueued:
                    Text("Queued")
                    cancelButton
                case .downloadInProgress:
                    if #available(iOS 14.0, *), let progress = viewModel.downloadProgress {
                        ProgressView(progress)
                    } else {
                        Text("Downloading...")
                    }
                    ActionButton(title: "Pause") {
                        DownloadService.shared.pause(zimFileID: zimFile.id)
                    }
                    cancelButton
                case .downloadPaused:
                    HStack {
                        Text("Paused")
                        if let progress = viewModel.downloadProgress {
                            Spacer()
                            Text(progress.localizedAdditionalDescription)
                        }
                    }
                    ActionButton(title: "Resume") {
                        DownloadService.shared.resume(zimFileID: zimFile.id)
                    }
                    cancelButton
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
        .alert(isPresented: $showingDeleteAlert) {
            let message: String = {
                if LibraryService().isFileInDocumentDirectory(zimFileID: zimFile.id) {
                    return "The zim file will be deleted from the app's document directory."
                } else {
                    return """
                           The zim file will be unlinked from the app, but not deleted, since it was opened in-place.
                           """
                }
            }()
            let deleteButton = Alert.Button.destructive(
                Text("Delete"), action: { ZimFileService.shared.deleteZimFile(zimFileID: zimFile.id) })
            return Alert(title: Text("Delete Zim File"),
                         message: Text(message),
                         primaryButton: deleteButton,
                         secondaryButton: .cancel())
        }
    }
    
    var cancelButton: some View {
        ActionButton(title: "Cancel", isDestructive: true) {
            DownloadService.shared.cancel(zimFileID: zimFile.id)
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
    
    struct ActionButton: View {
        let title: String
        let isDestructive: Bool
        let action: (() -> Void)
        
        init(title: String, isDestructive: Bool = false, action: @escaping (() -> Void) = {}) {
            self.title = title
            self.isDestructive = isDestructive
            self.action = action
        }
        
        var body: some View {
            Button(action: action, label: {
                HStack {
                    Spacer()
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : nil)
                    Spacer()
                }
            })
        }
    }
}

@available(iOS 13.0, *)
private class ViewModel: ObservableObject {
    @Published var state: ZimFile.State
    @Published var downloadProgress: Progress?
    let hasEnoughDiskSpace: Bool
    var zimFileDeleted: (() -> Void) = {}
    private var zimFileObserver: NotificationToken?
    
    init(_ zimFile: ZimFile) {
        self.state = zimFile.state
        self.downloadProgress = {
            guard let fileSize = zimFile.size.value else { return nil }
            let progress = Progress(totalUnitCount: fileSize)
            progress.completedUnitCount = zimFile.downloadTotalBytesWritten
            progress.kind = .file
            progress.fileOperationKind = .downloading
            progress.fileTotalCount = 1
            return progress
        }()
        self.hasEnoughDiskSpace = {
            guard let freeSpace = try? FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)
                    .first?.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                    .volumeAvailableCapacityForImportantUsage,
                  let fileSize = zimFile.size.value else { return false }
            return fileSize <= freeSpace
        }()
        
        guard let database = try? Realm(configuration: Realm.defaultConfig),
              let zimFile = database.object(ofType: ZimFile.self, forPrimaryKey: zimFile.id) else { return }
        zimFileObserver = zimFile.observe { [weak self] change in
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
                    self?.zimFileDeleted()
                default:
                    break
                }
        }
    }
}
