//
//  LibraryLanguageController.swift
//  Kiwix
//
//  Created by Chris Li on 5/8/18.
//  Copyright © 2018 Chris Li. All rights reserved.
//

import UIKit
import Defaults
import RealmSwift

class LibraryLanguageController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    typealias LanguageCode = String
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let sortBy: UISegmentedControl
    private let sortingModes: [LibraryLanguageFilterSortingMode] = [.alphabetically, .byCount]

    private var visible: [Language] = []
    private var hidden: [Language] = []
    
    var dismissCallback: (() -> Void)?
    
    // MARK: - Overrides
    
    init() {
        sortBy = UISegmentedControl(items: Array(sortingModes.map({ $0.description }) ))
        sortBy.selectedSegmentIndex = sortingModes.firstIndex(of: Defaults[.libraryLanguageSortingMode]) ?? 0
        
        super.init(nibName: nil, bundle: nil)

        let zimFileCount: [String: Int] = {
            do {
                let database = try Realm(configuration: Realm.defaultConfig)
                let codes = database.objects(ZimFile.self).distinct(by: ["languageCode"]).map({ $0.languageCode })
                return codes.reduce(into: [LanguageCode: Int]()) { (counts, code) in
                    counts[code] = database.objects(ZimFile.self).filter("languageCode = %@", code).count
                }
            } catch { return [String: Int]() }
        }()

        let visibleLanguageCodes = Defaults[.libraryFilterLanguageCodes]
        for (languageCode, zimFileCount) in zimFileCount {
            guard let languageName = Locale.current.localizedString(forLanguageCode: languageCode) else { continue }
            let language = Language(code: languageCode, name: languageName, count: zimFileCount)
            if visibleLanguageCodes.contains(languageCode) {
                visible.append(language)
            } else {
                hidden.append(language)
            }
        }
        sort()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = tableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UIRightDetailTableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        if navigationController?.topViewController === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissController))
        }
        
        navigationItem.titleView = sortBy
        sortBy.addTarget(self, action: #selector(sortByValueChanged(segmentedControl:)), for: .valueChanged)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Defaults[.libraryFilterLanguageCodes] = visible.map({$0.code})
        dismissCallback?()
    }
    
    // MARK: - Actions
    
    @objc func dismissController() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func sortByValueChanged(segmentedControl: UISegmentedControl) {
        Defaults[.libraryLanguageSortingMode] = sortingModes[segmentedControl.selectedSegmentIndex]
        sort()
        tableView.reloadData()
    }

    private func sort() {
        let compare = { (language0: Language, language1: Language) -> Bool in
            switch self.sortingModes[self.sortBy.selectedSegmentIndex] {
            case .alphabetically:
                return language0.name < language1.name
            case .byCount:
                if language0.count == language1.count {
                    return language0.name < language1.name
                } else {
                    return language0.count > language1.count
                }
            }
        }
        visible.sort(by: compare)
        hidden.sort(by: compare)
    }
    
    // MARK: - UITableViewDataSource & Delegates
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return visible.count
        } else {
            return hidden.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") as! UIRightDetailTableViewCell
        let language: Language = {
            if indexPath.section == 0 {
                return visible[indexPath.row]
            } else {
                return hidden[indexPath.row]
            }
        }()
        cell.textLabel?.text = language.name
        cell.detailTextLabel?.text = "\(language.count)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if visible.count == 0 {
            return section == 0 ? "" : NSLocalizedString("All", comment: "Library: Language Filter Section Header") + "        "
        } else {
            return section == 0 ? NSLocalizedString("Showing", comment: "Library Language Filter Section Header")
                : NSLocalizedString("Hiding", comment: "Library Language Filter Section Header")
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        func animateUpdates(deleted: IndexPath, inserted: IndexPath) {
            tableView.beginUpdates()
            tableView.deleteRows(at: [deleted], with: .right)
            tableView.insertRows(at: [inserted], with: .right)
            tableView.headerView(forSection: 0)?.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: 0)?.uppercased()
            tableView.headerView(forSection: 1)?.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: 1)?.uppercased()
            tableView.endUpdates()
        }
        
        if indexPath.section == 0 {
            let language = visible[indexPath.row]
            hidden.append(language)
            visible.remove(at: indexPath.row)
            sort()
            
            guard let insertedRowIndex = hidden.firstIndex(of: language) else {tableView.reloadData(); return}
            let insertedIndexPath = IndexPath(row: insertedRowIndex, section: 1)
            animateUpdates(deleted: indexPath, inserted: insertedIndexPath)
        } else {
            let language = hidden[indexPath.row]
            visible.append(language)
            hidden.remove(at: indexPath.row)
            sort()
            
            guard let insertedRowIndex = visible.firstIndex(of: language) else {tableView.reloadData(); return}
            let insertedIndexPath = IndexPath(row: insertedRowIndex, section: 0)
            animateUpdates(deleted: indexPath, inserted: insertedIndexPath)
        }
    }
    
    // MARK: - Type Definition

    private struct Language: Equatable {
        let code: String
        let name: String
        let count: Int
    }
}
