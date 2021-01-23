//
//  LibraryZimFileDetailController.swift
//  iOS
//
//  Created by Chris Li on 5/15/18.
//  Copyright © 2018 Chris Li. All rights reserved.
//

import UIKit
import RealmSwift

class LibraryZimFileDetailController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let zimFile: ZimFile
    private var zimFileObserver: NotificationToken?
    private var zimFileStateRawObserver:  NSKeyValueObservation?
    private let documentDirectoryURL = try! FileManager.default.url(
        for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

    private let tableView = UITableView(frame: .zero, style: {
        if #available(iOS 13, *) {
            return .insetGrouped
        } else {
            return .grouped
        }
    }())
    var actions = (top: [[Action]](), bottom: [[Action]]()) {
        didSet(oldValue) {
            /*
             Docs: Batch Insertion, Deletion, and Reloading of Rows and Sections
             https://developer.apple.com/library/etc/redirect/xcode/content/1189/documentation/UserExperience/Conceptual/TableView_iPhone/ManageInsertDeleteRow/ManageInsertDeleteRow.html#//apple_ref/doc/uid/TP40007451-CH10-SW9
             */
            tableView.beginUpdates()
            if actions.top.count > oldValue.top.count {
                tableView.insertSections(IndexSet(integersIn: oldValue.top.count..<actions.top.count), with: .fade)
            } else if oldValue.top.count > actions.top.count {
                tableView.deleteSections(IndexSet(integersIn: actions.top.count..<oldValue.top.count), with: .fade)
            } else {
                tableView.reloadSections(IndexSet(integersIn: 0..<actions.top.count), with: .automatic)
            }
            if actions.bottom.count > oldValue.bottom.count {
                tableView.insertSections(IndexSet(integersIn: actions.top.count + metas.count + oldValue.bottom.count..<actions.top.count + metas.count + actions.bottom.count), with: .fade)
            } else if oldValue.bottom.count > actions.bottom.count {
                tableView.deleteSections(IndexSet(integersIn: oldValue.top.count + metas.count + actions.bottom.count..<oldValue.top.count + metas.count + oldValue.bottom.count), with: .fade)
            } else {
                tableView.reloadSections(IndexSet(integersIn: actions.top.count + metas.count..<actions.top.count + metas.count + actions.bottom.count), with: .automatic)
            }
            tableView.endUpdates()
        }
    }
    private let metas: [[Meta]] = [
        [.language, .size, .date],
        [.hasPicture, .hasIndex, .hasVideo, .hasDetail],
        [.articleCount, .mediaCount],
        [.creator, .publisher],
        [.id]
    ]
    private let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    // MARK: - Overrides

    init(zimFile: ZimFile) {
        self.zimFile = zimFile
        super.init(nibName: nil, bundle: nil)
        title = zimFile.title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.register(UIRightDetailTableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(UIActionTableViewCell.self, forCellReuseIdentifier: "ActionCell")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureZimFileObservers()
    }

    // MARK: -

    private func configureZimFileObservers() {
        zimFileObserver = zimFile.observe { [unowned self] change in
            switch change {
            case .deleted:
                guard let splitViewController = self.splitViewController,
                    let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController else {return}
                if splitViewController.isCollapsed {
                    masterNavigationController.popViewController(animated: true)
                } else {
                    if self.navigationController?.topViewController == self {
                        // current controller is the top controller in the navigtion stack, cannot pop
                        (masterNavigationController.topViewController as? LibraryMasterController)?.selectFirstCategory()
                    } else {
                        self.navigationController?.popViewController(animated: true)
                    }
                }
            default:
                break
            }
        }
        zimFileStateRawObserver = zimFile.observe(\.stateRaw,
                                                  options: [.initial, .old],
                                                  changeHandler: { (zimFile, change) in
            guard let state = ZimFile.State(rawValue: zimFile.stateRaw) else {
                self.actions = ([[]], [[]])
                return
            }
            switch state {
            case .remote:
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                let freespace: Int64 = {
                    if let free = (((try? url?.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])) as URLResourceValues??))??.volumeAvailableCapacityForImportantUsage {
                        return free
                    } else {
                        return 0
                    }
                }()
                self.actions = ((zimFile.size.value ?? 0) <= freespace ? [[.downloadWifiOnly, .downloadWifiAndCellular]] : [[.downloadSpaceNotEnough]], [])

                // when state changed from onDevice to remote, and when split view controller is collapsed
                // pop this view controller
                if let oldState = ZimFile.State(rawValue: change.oldValue ?? ""),
                    oldState == .onDevice,
                    let splitViewController = self.splitViewController,
                    splitViewController.isCollapsed,
                    let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController {
                    masterNavigationController.popViewController(animated: true)
                }
            case .onDevice:
                if LibraryService().isFileInDocumentDirectory(zimFileID: zimFile.id) {
                    self.actions = ([[.openMainPage]], [[.deleteFile]])
                } else {
                    self.actions = ([[.openMainPage]], [[.unlink]])
                }
            case .retained:
                self.actions = ([], [[.deleteBookmarks]])
            case .downloadQueued:
                self.actions = ([[.cancel]], [])
            case .downloadInProgress:
                self.actions = ([[.pause, .cancel]], [])
            case .downloadPaused:
                self.actions = ([[.resume, .cancel]], [])
            case .downloadError:
                self.actions = ([[.cancel]], [])
            }
        })
    }

    // MARK: - UITableViewDataSource & Delagates

    func numberOfSections(in tableView: UITableView) -> Int {
        return actions.top.count + metas.count + actions.bottom.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < actions.top.count {
            return actions.top[section].count
        } else if section < actions.top.count + metas.count {
            return metas[section - actions.top.count].count
        } else {
            return actions.bottom[section - metas.count - actions.top.count].count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section < actions.top.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! UIActionTableViewCell
            let action = actions.top[indexPath.section][indexPath.row]
            configure(cell: cell, action: action)
            return cell
        } else if indexPath.section >= actions.top.count + metas.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ActionCell", for: indexPath) as! UIActionTableViewCell
            let action = actions.bottom[indexPath.section - actions.top.count - metas.count][indexPath.row]
            configure(cell: cell, action: action)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! UIRightDetailTableViewCell
            let meta = metas[indexPath.section - actions.top.count][indexPath.row]
            configure(cell: cell, meta: meta)
            return cell
        }
    }

    func configure(cell: UIActionTableViewCell, action: Action) {
        cell.textLabel?.text = action.description
        cell.isDisabled = action.isDisabled
        cell.isDestructive = action.isDestructive
    }

    func configure(cell: UIRightDetailTableViewCell, meta: Meta) {
        switch meta {
        case .language:
            cell.textLabel?.text = NSLocalizedString("Language", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = Locale.current.localizedString(forLanguageCode: zimFile.languageCode)
        case .size:
            cell.textLabel?.text = NSLocalizedString("Size", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.sizeDescription
        case .date:
            cell.textLabel?.text = NSLocalizedString("Date", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.creationDateDescription
        case .hasIndex:
            cell.textLabel?.text = NSLocalizedString("Index", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = {
                if zimFile.hasIndex {
                    return NSLocalizedString("Yes", comment: "Book Detail Cell, has index")
                } else {
                    return NSLocalizedString("No", comment: "Book Detail Cell, has index")
                }
            }()
        case .hasPicture:
            cell.textLabel?.text = NSLocalizedString("Pictures", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.hasPictures ? NSLocalizedString("Yes", comment: "Book Detail Cell, has picture") : NSLocalizedString("No", comment: "Book Detail Cell, does not have picture")
        case .hasVideo:
            cell.textLabel?.text = NSLocalizedString("Videos", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.hasVideos ? NSLocalizedString("Yes", comment: "Book Detail Cell, has videos") : NSLocalizedString("No", comment: "Book Detail Cell, does not have videos")
        case .hasDetail:
            cell.textLabel?.text = NSLocalizedString("Details", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.hasDetails ? NSLocalizedString("Yes", comment: "Book Detail Cell, has details") : NSLocalizedString("No", comment: "Book Detail Cell, does not have details")
        case .articleCount:
            cell.textLabel?.text = NSLocalizedString("Article Count", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = countFormatter.string(from: NSNumber(value: zimFile.articleCount.value ?? 0))
        case .mediaCount:
            cell.textLabel?.text = NSLocalizedString("Media Count", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = countFormatter.string(from: NSNumber(value: zimFile.mediaCount.value ?? 0))
        case .creator:
            cell.textLabel?.text = NSLocalizedString("Creator", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.creator
        case .publisher:
            cell.textLabel?.text = NSLocalizedString("Publisher", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.publisher
        case .id:
            cell.textLabel?.text = NSLocalizedString("ID", comment: "Book Detail Cell")
            cell.detailTextLabel?.text = zimFile.shortID
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        func handle(action: Action) {
            switch action {
            case .downloadWifiOnly:
                DownloadService.shared.start(zimFileID: zimFile.id, allowsCellularAccess: false)
            case .downloadWifiAndCellular:
                DownloadService.shared.start(zimFileID: zimFile.id, allowsCellularAccess: true)
            case .downloadSpaceNotEnough:
                break
            case .cancel:
                DownloadService.shared.cancel(zimFileID: zimFile.id)
            case .pause:
                DownloadService.shared.pause(zimFileID: zimFile.id)
            case .resume:
                DownloadService.shared.resume(zimFileID: zimFile.id)
            case .deleteFile, .deleteBookmarks, .deleteFileAndBookmarks, .unlink:
                present(ActionConfirmationController(zimFile: zimFile, action: action), animated: true)
            case .openMainPage:
                guard let navigationController = presentingViewController as? UINavigationController,
                      let rootViewController = navigationController.topViewController as? RootViewController else { break }
                rootViewController.openMainPage(zimFileID: zimFile.id)
                dismiss(animated: true, completion: nil)
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section < actions.top.count {
            let action = actions.top[indexPath.section][indexPath.row]
            handle(action: action)
        } else if indexPath.section >= actions.top.count + metas.count {
            let action = actions.bottom[indexPath.section - actions.top.count - metas.count][indexPath.row]
            handle(action: action)
        }
    }

    // MARK: - Type Definition

    enum Meta: String {
        case language, size, date
        case hasIndex, hasPicture, hasVideo, hasDetail
        case articleCount, mediaCount
        case creator, publisher, id
    }

    enum Action: CustomStringConvertible {
        case downloadWifiOnly, downloadWifiAndCellular, downloadSpaceNotEnough
        case cancel, resume, pause
        case deleteFile, deleteBookmarks, deleteFileAndBookmarks
        case unlink
        case openMainPage

        static let destructives: [Action] = [.cancel, .deleteFile, .deleteBookmarks, .deleteFileAndBookmarks, .unlink]

        var isDestructive: Bool {
            return Action.destructives.contains(self)
        }

        var isDisabled: Bool {
            return self == .downloadSpaceNotEnough
        }

        var description: String {
            switch self {
            case .downloadWifiOnly:
                return NSLocalizedString("Download - Wifi Only", comment: "Book Detail Cell")
            case .downloadWifiAndCellular:
                return NSLocalizedString("Download - Wifi & Cellular", comment: "Book Detail Cell")
            case .downloadSpaceNotEnough:
                return NSLocalizedString("Download - Not Enough Space", comment: "Book Detail Cell")
            case .cancel:
                return NSLocalizedString("Cancel", comment: "Book Detail Cell")
            case .resume:
                return NSLocalizedString("Resume", comment: "Book Detail Cell")
            case .pause:
                return NSLocalizedString("Pause", comment: "Book Detail Cell")
            case .deleteFile:
                return NSLocalizedString("Delete File", comment: "Book Detail Cell")
            case .deleteBookmarks:
                return NSLocalizedString("Delete Bookmarks", comment: "Book Detail Cell")
            case .deleteFileAndBookmarks:
                return NSLocalizedString("Delete File and Bookmarks", comment: "Book Detail Cell")
            case .unlink:
                return NSLocalizedString("Unlink", comment: "Book Detail Cell")
            case .openMainPage:
                return NSLocalizedString("Open Main Page", comment: "Book Detail Cell")
            }
        }
    }

    class ActionConfirmationController: UIAlertController {
        convenience init(zimFile: ZimFile, action: Action) {
            let message: String? = {
                switch action {
                case .deleteFile:
                    return NSLocalizedString("This will delete the zim file but keep the bookmarks.", comment: "Book deletion message")
                case .deleteBookmarks:
                    return NSLocalizedString("This will delete all bookmarks related to that zim file, but the zim file will remain on disk.", comment: "Book deletion message")
                case .deleteFileAndBookmarks:
                    return NSLocalizedString("This will delete both the zim file and all its bookmarks.", comment: "Book deletion message")
                default:
                    return nil
                }
            }()
            self.init(title: action.description, message: message, preferredStyle: .alert)
            addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Book deletion confirmation"), style: .destructive, handler: { _ in
                if action == .deleteFile || action == .deleteFileAndBookmarks {
                    guard let url = ZimFileService.shared.getFileURL(zimFileID: zimFile.id) else {return}
                    let directoryURL = url.deletingLastPathComponent()
                    let fileName = url.deletingPathExtension().lastPathComponent

                    let urls = try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.isExcludedFromBackupKey],
                                                                            options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants])
                    urls?.filter({ $0.lastPathComponent.contains(fileName) }).forEach({ try? FileManager.default.removeItem(at: $0) })
                }
                if action == .unlink {
                    do {
                        ZimFileService.shared.close(id: zimFile.id)
                        let database = try Realm(configuration: Realm.defaultConfig)
                        try database.write {
                            if zimFile.downloadURL != nil {
                                zimFile.state = .remote
                                zimFile.openInPlaceURLBookmark = nil
                            } else {
                                database.delete(zimFile)
                            }
                        }
                    } catch {}
                }
            }))
            addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Book deletion confirmation"), style: .cancel))
        }
    }
}
