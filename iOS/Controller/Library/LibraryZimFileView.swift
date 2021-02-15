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

/// Information about a single zim file in a list view.
@available(iOS 14.0, *)
struct LibraryZimFileView: View {
    @ObservedObject private var viewModel: ViewModel
    @State private var showingDeleteAlert = false
    
    private let zimFile: ZimFile
    private let downloadUsingCellular = Binding<Bool>(
        get: { UserDefaults.standard.downloadUsingCellular },
        set: { UserDefaults.standard.downloadUsingCellular = $0 }
    )
    var openMainPage: ((String) -> Void) = { _ in }
    var zimFileDeleted: (() -> Void) = {} { didSet { viewModel.zimFileDeleted = zimFileDeleted } }
    
    init?(id: String) {
        guard let database = try? Realm(configuration: Realm.defaultConfig),
              let zimFile = database.object(ofType: ZimFile.self, forPrimaryKey: id) else { return nil }
        self.zimFile = zimFile
        self.viewModel = ViewModel(zimFile)
    }
    
    var body: some View {
        List {
            Section {
                Text(zimFile.title)
                Text(zimFile.fileDescription)
            }
            Section {
                switch viewModel.state {
                case .remote:
                    if viewModel.hasEnoughDiskSpace {
                        Toggle("Cellular Data", isOn: downloadUsingCellular)
                        ActionButton(title: "Download") {
                            DownloadService.shared.start(
                                zimFileID: zimFile.id, allowsCellularAccess: UserDefaults.standard.downloadUsingCellular
                            )
                        }
                    } else {
                        ActionButton(title: "Download - Not Enough Space").disabled(true)
                    }
                case .onDevice:
                    ActionButton(title: "Open Main Page", isDestructive: false) {
                        openMainPage(zimFile.id)
                    }
                case .downloadQueued:
                    Text(viewModel.state.description)
                    cancelButton
                case .downloadInProgress:
                    if let progress = viewModel.downloadProgress {
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
                        Text(viewModel.state.description)
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
                    Text(viewModel.state.description)
                    if let errorDescription = zimFile.downloadErrorDescription {
                        Text(errorDescription)
                    }
                default:
                    cancelButton
                }
            }
            Section {
                Cell(title: "Language", detail: zimFile.languageDescription)
                Cell(title: "Size", detail: zimFile.sizeDescription)
                Cell(title: "Date", detail: zimFile.creationDateDescription)
            }
            Section {
                CheckmarkCell(title: "Pictures", isChecked: zimFile.hasPictures)
                CheckmarkCell(title: "Videos", isChecked: zimFile.hasVideos)
                CheckmarkCell(title: "Details", isChecked: zimFile.hasDetails)
            }
            Section {
                Cell(title: "Article Count", detail: zimFile.articleCountDescription)
                Cell(title: "Media Count", detail: zimFile.mediaCountDescription)
            }
            Section {
                Cell(title: "Creator", detail: zimFile.creator)
                Cell(title: "Publisher", detail: zimFile.publisher)
            }
            Section {
                Cell(title: "ID", detail: zimFile.shortID).contextMenu(ContextMenu(menuItems: {
                    Button("Copy") { UIPasteboard.general.string = zimFile.id }
                }))
            }
            if viewModel.state == .onDevice {
                Section {
                    ActionButton(title: "Delete", isDestructive: true) {
                        showingDeleteAlert = true
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
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
    
    struct Cell: View {
        let title: String
        let detail: String?
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Text(detail ?? "Unknown").foregroundColor(.secondary)
            }
        }
    }
    
    struct CheckmarkCell: View {
        let title: String
        let isChecked: Bool
        
        var body: some View {
            HStack {
                Text(title)
                Spacer()
                if isChecked{
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                } else {
                    Image(systemName: "multiply.circle.fill").foregroundColor(.secondary)
                }
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
    
    private class ViewModel: ObservableObject {
        @Published var state: ZimFile.State
        @Published var downloadProgress: Progress?
        
        let hasEnoughDiskSpace: Bool
        var zimFileDeleted: (() -> Void) = {}
        private var zimFileObserver: NotificationToken?
        
        init(_ zimFile: ZimFile) {
            state = zimFile.state
            downloadProgress = zimFile.downloadProgress
            hasEnoughDiskSpace = {
                guard let freeSpace = try? FileManager.default
                        .urls(for: .documentDirectory, in: .userDomainMask)
                        .first?.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                        .volumeAvailableCapacityForImportantUsage,
                      let fileSize = zimFile.size.value else { return false }
                return fileSize <= freeSpace
            }()
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
}
