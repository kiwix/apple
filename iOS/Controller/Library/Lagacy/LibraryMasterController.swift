//
//  LibraryMasterController.swift
//  Kiwix
//
//  Created by Chris Li on 10/12/17.
//  Copyright © 2017 Chris Li. All rights reserved.
//

import UIKit
import MobileCoreServices
import Defaults
import RealmSwift

class LibraryMasterController: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let searchController = UISearchController(searchResultsController: LibrarySearchController())

    private var sections: [Section] = [.category]
    private let categories: [ZimFile.Category] = [
        .wikipedia, .wikibooks, .wikinews, .wikiquote, .wikisource, .wikiversity,
        .wikivoyage, .wiktionary, .vikidia, .ted, .stackExchange, .other
    ]

    // MARK: - Database

    /*
     Note: localZimFilesCount & downloadZimFilesCount are kept here as a cache of the row count of each section,
     since tableview update for each section is submitted separately.
     */

    private var localZimFilesCount: Int = 0
    private var downloadZimFilesCount: Int = 0
    private let localZimFiles: Results<ZimFile>? = {
        do {
            let database = try Realm(configuration: Realm.defaultConfig)
            let predicate = NSPredicate(format: "stateRaw == %@", ZimFile.State.onDevice.rawValue)
            return database.objects(ZimFile.self).filter(predicate)
        } catch { return nil }
    }()
    private let downloadZimFiles: Results<ZimFile>? = {
        do {
            let database = try Realm(configuration: Realm.defaultConfig)
            let states: [ZimFile.State] = [.downloadQueued, .downloadInProgress, .downloadPaused, .downloadError]
            let predicate = NSPredicate(format: "stateRaw IN %@", states.map({ $0.rawValue }))
            return database.objects(ZimFile.self).filter(predicate)
        } catch { return nil }
    }()
    private var localZimFilesChangeToken: NotificationToken?
    private var downloadZimFilesChangeToken: NotificationToken?

    // MARK: - Overrides

    override func loadView() {
        view = tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "CategoryCell")
        tableView.separatorInsetReference = .fromAutomaticInsets
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Library", comment: "Library title")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(dismissController)
        )
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(openDocumentPicker)),
            UIBarButtonItem(customView: {
                let button = UIButton(type: .infoLight)
                button.addTarget(self, action: #selector(openInfoController), for: .touchUpInside)
                return button
            }())
        ]
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.placeholder = NSLocalizedString("Search by Name", comment: "Library: search placeholder")
        searchController.searchResultsUpdater = searchController.searchResultsController as? LibrarySearchController
        definesPresentationContext = true
        
        if splitViewController?.traitCollection.horizontalSizeClass == .regular {
            let firstIndexPath = IndexPath(row: 0, section: 0)
            tableView.delegate?.tableView?(tableView, didSelectRowAt: firstIndexPath)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSections()
        configureChangeToken()
        
        if let refreshTime = Defaults[.libraryLastRefreshTime],
            Date().timeIntervalSince(refreshTime) > LibraryService.autoUpdateInterval,
            LibraryOperationQueue.shared.currentOPDSRefreshOperation == nil {
            LibraryOperationQueue.shared.addOperation(OPDSRefreshOperation())
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        localZimFilesChangeToken = nil
        downloadZimFilesChangeToken = nil
    }

    // MARK: - Utilities

    func selectFirstCategory() {
        guard let index = sections.firstIndex(of: .category) else {return}
        let indexPath = IndexPath(row: 0, section: index)
        tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
    }

    // MARK: - UIControl Actions

    @objc func dismissController() {
        dismiss(animated: true, completion: nil)
    }

    @objc func openDocumentPicker() {
        let controller = UIDocumentPickerViewController(documentTypes: ["org.openzim.zim"], in: .open)
        controller.delegate = self
        present(controller, animated: true)
    }
    
    @objc func openInfoController(sender: UIButton) {
        let controller = UINavigationController(rootViewController: SettingLibraryController())
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.sourceView = sender
        present(controller, animated: true)
    }

    // MARK: - Configurations

    private func configureSections() {
        if let localZimFiles = localZimFiles {
            localZimFilesCount = localZimFiles.count
            if localZimFiles.count > 0, sections.firstIndex(of: .local) == nil {
                sections.insert(.local, at: 0)
            } else if localZimFiles.count == 0, let sectionIndex = sections.firstIndex(of: .local) {
                sections.remove(at: sectionIndex)
            }
        }
        if let downlaodZimFiles = downloadZimFiles {
            downloadZimFilesCount = downlaodZimFiles.count
            if downlaodZimFiles.count > 0, !sections.contains(.download) {
                let sectionIndex = self.sections.contains(.local) ? 1 : 0
                sections.insert(.download, at: sectionIndex)
            } else if downlaodZimFiles.count == 0, let sectionIndex = sections.firstIndex(of: .download) {
                sections.remove(at: sectionIndex)
            }
        }
        tableView.reloadData()
    }

    private func configureChangeToken() {
        localZimFilesChangeToken = localZimFiles?.observe({ [unowned self] changes in
            guard case let .update(results, deletions, insertions, updates) = changes else {return}
            self.localZimFilesCount = results.count
            self.tableView.performBatchUpdates({
                if results.count > 0, self.sections.firstIndex(of: .local) == nil {
                    self.sections.insert(.local, at: 0)
                    self.tableView.insertSections(IndexSet([0]), with: .automatic)
                }

                if results.count == 0, let sectionIndex = self.sections.firstIndex(of: .local) {
                    self.sections.remove(at: sectionIndex)
                    self.tableView.deleteSections(IndexSet([sectionIndex]), with: .automatic)
                }

                if let sectionIndex = self.sections.firstIndex(of: .local) {
                    if deletions.isEmpty, insertions.isEmpty {
                        updates.forEach({ row in
                            let indexPath = IndexPath(row: row, section: sectionIndex)
                            guard let cell = self.tableView.cellForRow(at: indexPath) as? TableViewCell else {return}
                            self.configure(localCell: cell, row: row)
                        })
                    } else {
                        self.tableView.reloadSections([sectionIndex], with: .automatic)
                    }
                }
            })
        })
        downloadZimFilesChangeToken = downloadZimFiles?.observe({ [unowned self] changes in
            guard case let .update(results, deletions, insertions, updates) = changes else {return}
            self.downloadZimFilesCount = results.count
            self.tableView.performBatchUpdates({
                if results.count > 0, !self.sections.contains(.download) {
                    let sectionIndex = self.sections.contains(.local) ? 1 : 0
                    self.sections.insert(.download, at: sectionIndex)
                    self.tableView.insertSections(IndexSet([sectionIndex]), with: .automatic)
                }

                if results.count == 0, let sectionIndex = self.sections.firstIndex(of: .download) {
                    self.sections.remove(at: sectionIndex)
                    self.tableView.deleteSections(IndexSet([sectionIndex]), with: .automatic)
                }
                
                if let sectionIndex = self.sections.firstIndex(of: .download) {
                    if deletions.isEmpty, insertions.isEmpty {
                        updates.forEach({ row in
                            let indexPath = IndexPath(row: row, section: sectionIndex)
                            guard let cell = self.tableView.cellForRow(at: indexPath) as? TableViewCell else {return}
                            self.configure(downloadCell: cell, row: row)
                        })
                    } else {
                        self.tableView.reloadSections([sectionIndex], with: .automatic)
                    }
                }
            })
        })
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        if let _ = ZimFileService.getMetaData(url: url) {
            present(FileImportController(fileURL: url), animated: true)
        } else {
            present(FileImportAlertController(fileName: url.lastPathComponent), animated: true)
        }
    }

    // MARK: - UITableViewDataSource & Delegates

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .local:
            return localZimFilesCount
        case .download:
            return downloadZimFilesCount
        case .category:
            return categories.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .local:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
            configure(localCell: cell, row: indexPath.row)
            return cell
        case .download:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
            configure(downloadCell: cell, row: indexPath.row)
            return cell
        case .category:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath) as! TableViewCell
            let category = categories[indexPath.row]
            cell.accessoryType = .disclosureIndicator
            cell.titleLabel.text = category.description
            cell.thumbImageView.image = category.icon
            cell.thumbImageView.contentMode = .scaleAspectFit
            return cell
        }
    }

    func configure(localCell cell: TableViewCell, row: Int, animated: Bool = false) {
        guard let zimFile = localZimFiles?[row] else {return}
        cell.titleLabel.text = zimFile.title
        cell.detailLabel.text = [
            zimFile.sizeDescription, zimFile.creationDateShortDescription, zimFile.articleCountLongDescription
        ].compactMap({ $0 }).joined(separator: ", ")
        cell.thumbImageView.image = UIImage(data: zimFile.faviconData ?? Data()) ?? #imageLiteral(resourceName: "GenericZimFile")
        cell.thumbImageView.contentMode = .scaleAspectFit
        cell.accessoryType = .disclosureIndicator
    }

    func configure(downloadCell cell: TableViewCell, row: Int, animated: Bool = false) {
        guard let zimFile = downloadZimFiles?[row] else {return}
        cell.titleLabel.text = zimFile.title
        cell.detailLabel.text = {
            switch zimFile.state {
            case .downloadQueued:
                return NSLocalizedString("Queued", comment: "Zim file download state")
            case .downloadInProgress:
                let bytesWrittenFormatted = ByteCountFormatter.string(fromByteCount: zimFile.downloadTotalBytesWritten,
                                                                      countStyle: .file)
                guard let fileSize = zimFile.size.value, let sizeDescription = zimFile.sizeDescription else {
                    return bytesWrittenFormatted
                }
                let percent = NSNumber(value: Double(zimFile.downloadTotalBytesWritten) / Double(fileSize))
                let percentFormatted = NumberFormatter.localizedString(from: percent, number: .percent)
                return "\(bytesWrittenFormatted) / \(sizeDescription), \(percentFormatted)"
            case .downloadPaused:
                return NSLocalizedString("Paused", comment: "Zim file download state")
            case .downloadError:
                return NSLocalizedString("Error", comment: "Zim file download state")
            default:
                return nil
            }
        }()
        cell.thumbImageView.image = UIImage(data: zimFile.faviconData ?? Data()) ?? #imageLiteral(resourceName: "GenericZimFile")
        cell.thumbImageView.contentMode = .scaleAspectFit
        cell.accessoryType = .disclosureIndicator
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .local:
            return NSLocalizedString("On Device", comment: "Library section headers")
        case .download:
            return NSLocalizedString("Downloads", comment: "Library section headers")
        case .category:
            return NSLocalizedString("Categories", comment: "Library section headers")
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .local:
            guard let zimFile = localZimFiles?[indexPath.row] else {return}
            let controller = LibraryZimFileDetailController(zimFile: zimFile)
            showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
        case .download:
            guard let zimFile = downloadZimFiles?[indexPath.row] else {return}
            let controller = LibraryZimFileDetailController(zimFile: zimFile)
            showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
        case .category:
            let controller = LibraryCategoryController(category: categories[indexPath.row])
            showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
        }
    }

    // MARK: - Type Definition

    enum Section { case local, download, category }
}
