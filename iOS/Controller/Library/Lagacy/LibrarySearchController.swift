//
//  LibrarySearchController.swift
//  iOS
//
//  Created by Chris Li on 8/14/18.
//  Copyright © 2018 Chris Li. All rights reserved.
//

import UIKit
import Defaults
import RealmSwift

class LibrarySearchController: UITableViewController, UISearchResultsUpdating {
    private var database: Realm?
    private var languageCodes = [String]()
    private var zimFiles: Results<ZimFile>?
    
    init() {
        self.database = try? Realm(configuration: Realm.defaultConfig)
        super.init(style: .plain)
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.keyboardDismissMode = .onDrag
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UISearchResultsUpdating

    func updateSearchResults(for searchController: UISearchController) {
        let previousSearchText = searchController.searchBar.text
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25) {
            guard previousSearchText == searchController.searchBar.text else {return}
            guard let searchText = searchController.searchBar.text, searchText.count > 0 else {
                self.languageCodes = []
                self.zimFiles = nil
                self.tableView.reloadData()
                return
            }
            
            var zimFiles = self.database?.objects(ZimFile.self)
            if Defaults[.libraryFilterLanguageCodes].count > 0 {
                zimFiles = zimFiles?.filter("languageCode IN %@", Defaults[.libraryFilterLanguageCodes])
            }
            zimFiles = zimFiles?.filter("title CONTAINS[cd] %@", searchText)
            
            self.languageCodes = zimFiles?.distinct(by: ["languageCode"]).map({ $0.languageCode }) ?? []
            self.zimFiles = zimFiles
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return languageCodes.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let zimFiles = zimFiles?.filter("languageCode == %@", languageCodes[section]) else {return 0}
        return zimFiles.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
        if let zimFile = zimFiles?.filter("languageCode == %@", languageCodes[indexPath.section])[indexPath.row] {
            TableViewCellConfigurator.configure(cell, zimFile: zimFile, tableView: tableView, indexPath: indexPath)
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Locale.current.localizedString(forLanguageCode: languageCodes[section])
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let zimFiles = zimFiles?.filter("languageCode == %@", languageCodes[indexPath.section]) else {return}
        let zimFile = zimFiles[indexPath.row]
        let controller = LibraryZimFileDetailController(zimFile: zimFile)
        presentingViewController?.showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
    }
}
