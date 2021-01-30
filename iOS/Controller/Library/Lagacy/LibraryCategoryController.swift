//
//  LibraryCategoryController.swift
//  Kiwix
//
//  Created by Chris Li on 10/12/17.
//  Copyright © 2017 Chris Li. All rights reserved.
//

import UIKit
import Defaults
import RealmSwift

class LibraryCategoryController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView()
    private var backgroundView = LibraryCategoryBackgroundView()
    private let category: ZimFile.Category

    private var languageCodes = [String]()
    private var results = [String: Results<ZimFile>]()
    private var notificationTokens = [String: NotificationToken]()
    private var refreshOperationFinishedObserver: NSKeyValueObservation?
    private var selectedLanguageCodeObserver: DefaultsObservation?

    // MARK: - Override

    init(category: ZimFile.Category) {
        self.category = category
        super.init(nibName: nil, bundle: nil)
        title = category.description
        self.selectedLanguageCodeObserver = Defaults.observe(.libraryFilterLanguageCodes) { [unowned self] update in
            self.configure(selectedLanguages: update.newValue)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.separatorInsetReference = .fromAutomaticInsets
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNotificationTokens()

        if let operation = LibraryOperationQueue.shared.currentOPDSRefreshOperation, languageCodes.count == 0 {
            configureBackgroundView(operation: operation)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        notificationTokens.removeAll()
    }

    // MARK: - Configurations

    private func configure(selectedLanguages: [String]) {
        notificationTokens.removeAll()
        results.removeAll()

        do {
            let database = try Realm(configuration: Realm.defaultConfig)

            // select lanuages
            if selectedLanguages.count > 0 {
                languageCodes = selectedLanguages
            } else {
                let zimFiles = database.objects(ZimFile.self).filter("categoryRaw = %@", category.rawValue)
                languageCodes = zimFiles.distinct(by: ["languageCode"]).map({ $0.languageCode })
            }
            languageCodes.sort { (code0, code1) -> Bool in
                guard let name0 = Locale.current.localizedString(forLanguageCode: code0),
                    let name1 = Locale.current.localizedString(forLanguageCode: code1) else {return code0 < code1}
                return name0 < name1
            }

            // fetch results or show empty view
            if languageCodes.count > 0 {
                for languageCode in languageCodes {
                    let zimFiles = database.objects(ZimFile.self)
                        .filter("categoryRaw = %@ AND languageCode == %@", category.rawValue, languageCode)
                        .sorted(byKeyPath: "title")
                    results[languageCode] = zimFiles
                }
                configureNotificationTokens()

                navigationItem.rightBarButtonItem = UIBarButtonItem(
                    image: #imageLiteral(resourceName: "Globe"), style: .plain, target: self, action: #selector(languageFilterBottonTapped(sender:)))
                tableView.backgroundView = nil
                tableView.separatorStyle = .singleLine
                showAdditionalLanguageAlertIfNeeded()
            } else {
                backgroundView.button.addTarget(
                    self, action: #selector(refreshLibraryButtonTapped(sender:)), for: .touchUpInside
                )
                navigationItem.rightBarButtonItem = nil
                tableView.backgroundView = backgroundView
                tableView.separatorStyle = .none
            }

            tableView.reloadData()
        } catch {}
    }

    private func configureNotificationTokens() {
        notificationTokens.removeAll()
        for (languageCode, result) in results {
            let notification = result.observe { [unowned self] changes in
                guard let sectionIndex = self.languageCodes.firstIndex(of: languageCode) else { return }
                switch changes {
                case .initial:
                    self.tableView.reloadSections([sectionIndex], with: .none)
                case .update(_, let deletions, let insertions, let updates):
                    if deletions.isEmpty, insertions.isEmpty {
                        let indexPaths = updates.map { IndexPath(row: $0, section: sectionIndex) }
                        self.tableView.reloadRows(at: indexPaths, with: .automatic)
                    } else {
                        self.tableView.reloadSections([sectionIndex], with: .automatic)
                    }
                default:
                    break
                }
            }
            notificationTokens[languageCode] = notification
        }
    }

    private func configureBackgroundView(operation: OPDSRefreshOperation) {
        backgroundView.button.isEnabled = false
        backgroundView.statusLabel.text = nil
        backgroundView.activityIndicator.startAnimating()

        refreshOperationFinishedObserver = operation.observe(
            \.isFinished, options: .new
        ) { [weak self] (operation, _) in
            DispatchQueue.main.sync {
                guard let error = operation.error else { return }
                self?.backgroundView.activityIndicator.stopAnimating()
                self?.backgroundView.statusLabel.text = error.errorDescription
                self?.backgroundView.button.isEnabled = true
            }
        }
    }

    private func showAdditionalLanguageAlertIfNeeded() {
        guard !Defaults[.libraryShownLanguageFilterAlert] else { return }
        let title = NSLocalizedString("More Languages", comment: "Library: Additional Language Alert")
        let message = NSLocalizedString(
            """
            Contents in other languages are also available.
            Visit language filter at the top of the screen to enable them.
            """, comment: "Library: Additional Language Alert")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        Defaults[.libraryShownLanguageFilterAlert] = true
    }

    // MARK: - UIControl Actions

    @objc func languageFilterBottonTapped(sender: UIBarButtonItem) {
        let navigation = UINavigationController(rootViewController: LibraryLanguageController())
        navigation.modalPresentationStyle = .popover
        navigation.popoverPresentationController?.barButtonItem = sender
        present(navigation, animated: true, completion: nil)
    }

    @objc func refreshLibraryButtonTapped(sender: RoundedButton) {
        let operation: OPDSRefreshOperation = {
            if let operation = LibraryOperationQueue.shared.currentOPDSRefreshOperation {
                return operation
            } else {
                let operation = OPDSRefreshOperation()
                LibraryOperationQueue.shared.addOperation(operation)
                return operation
            }
        }()
        configureBackgroundView(operation: operation)
    }

    // MARK: - UITableViewDataSource & Delagates

    func numberOfSections(in tableView: UITableView) -> Int {
        return languageCodes.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let result = results[languageCodes[section]] else { return 0 }
        return result.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let cell = cell as? TableViewCell, let result = results[languageCodes[indexPath.section]] {
            TableViewCellConfigurator.configure(
                cell, zimFile: result[indexPath.row], tableView: tableView, indexPath: indexPath
            )
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Locale.current.localizedString(forLanguageCode: languageCodes[section])
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let result = results[languageCodes[indexPath.section]] else { return }
        let controller = LibraryZimFileDetailController(zimFile: result[indexPath.row])
        navigationController?.pushViewController(controller, animated: true)
    }
}
