//
//  SearchNoTextController.swift
//  Kiwix
//
//  Created by Chris Li on 1/19/18.
//  Copyright © 2018 Chris Li. All rights reserved.
//

import UIKit
import RealmSwift
import SwiftyUserDefaults

class SearchNoTextController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDelegate, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    enum Sections { case recentSearch, searchFilter }
    private var sections: [Sections] = [.searchFilter]
    
    private var recentSearchTexts = Defaults[.recentSearchTexts] {
        didSet {
            Defaults[.recentSearchTexts] = recentSearchTexts
            if recentSearchTexts.count == 0, let index = sections.index(of: .recentSearch) {
                tableView.beginUpdates()
                sections.remove(at: index)
                tableView.deleteSections(IndexSet([index]), with: .fade)
                tableView.endUpdates()
            } else if recentSearchTexts.count > 0 && !sections.contains(.recentSearch) {
                tableView.beginUpdates()
                sections.insert(.recentSearch, at: 0)
                tableView.insertSections(IndexSet([0]), with: .none)
                tableView.endUpdates()
            } else if recentSearchTexts.count > 0, let index = sections.index(of: .recentSearch) {
                guard recentSearchTexts != oldValue else {return}
                tableView.reloadSections(IndexSet([index]), with: .none)
            }
        }
    }
    
    private var localZimFiles: Results<ZimFile>?
    private var token: NotificationToken?
    
    var localBookIDs: Set<ZimFileID> {
        let database = try! Realm()
        let predicate = NSPredicate(format: "stateRaw == %@", ZimFile.State.local.rawValue)
        return Set(database.objects(ZimFile.self).filter(predicate).map({$0.id}))
    }
    var includedInSearchBookIDs: Set<ZimFileID> {
        let database = try! Realm()
        let predicate = NSPredicate(format: "stateRaw == %@ AND includeInSearch == true", ZimFile.State.local.rawValue)
        return Set(database.objects(ZimFile.self).filter(predicate).map({$0.id}))
    }
    
    // MARK: - Functions
    
    override func loadView() {
        view = tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(RecentSearchTableViewCell.self, forCellReuseIdentifier: "RecentSearchCell")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if recentSearchTexts.count > 0 {
            sections.insert(.recentSearch, at: 0)
        }
        configureDatabase()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass else {return}
        switch traitCollection.horizontalSizeClass {
        case .compact:
            tableView.backgroundColor = .groupTableViewBackground
        case .regular:
            tableView.backgroundColor = .clear
        case .unspecified:
            break
        }
    }
    
    func configureDatabase() {
        do {
            let database = try Realm()
            let predicate = NSPredicate(format: "stateRaw == %@", ZimFile.State.local.rawValue)
            localZimFiles = database.objects(ZimFile.self).filter(predicate)
        } catch {}
        
        token = localZimFiles?.observe({ (changes) in
            print(changes)
            switch changes {
            case .initial:
                self.tableView.reloadData()
            case .update(_, let deletions, let insertions, let updates):
                guard let sectionIndex = self.sections.index(of: .searchFilter) else {return}
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: sectionIndex) }), with: .automatic)
                self.tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: sectionIndex) }), with: .automatic)
                updates.forEach({ (row) in
                    let indexPath = IndexPath(row: row, section: sectionIndex)
                    guard let cell = self.tableView.cellForRow(at: indexPath) as? TableViewCell else {return}
                    self.configure(cell: cell, indexPath: indexPath)
                })
                self.tableView.endUpdates()
            default:
                break
            }
        })
    }
    
    func add(recentSearchText newSearchText: String) {
        /* we make a local copy of `recentSearchTexts` to process search texts and save it back,
         so that we prevent tableView operations from being triggered too many times. */
        var searchTexts = recentSearchTexts
        if let index = searchTexts.index(of: newSearchText) {
            searchTexts.remove(at: index)
        }
        searchTexts.insert(newSearchText, at: 0)
        if searchTexts.count > 20 {
            searchTexts = Array(searchTexts[..<20])
        }
        recentSearchTexts = searchTexts
    }
    
    @objc private func buttonTapped(button: SectionHeaderButton) {
        guard let section = button.section else {return}
        switch section {
        case .recentSearch:
            recentSearchTexts.removeAll()
        case .searchFilter:
            do {
                let database = try Realm()
                try database.write {
                    localZimFiles?.forEach({ $0.includeInSearch = true })
                }
            } catch {}
        }
    }
    
    // MARK: - UITableViewDataSource & Delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sections[section] == .searchFilter {
            return localZimFiles?.count ?? 0
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if sections[indexPath.section] == .searchFilter {
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TableViewCell
            configure(cell: cell, indexPath: IndexPath(row: indexPath.row, section: 0))
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "RecentSearchCell", for: indexPath) as! RecentSearchTableViewCell
            return cell
        }
    }
    
    func configure(cell: TableViewCell, indexPath: IndexPath) {
        guard let zimFile = localZimFiles?[indexPath.row] else {return}
        cell.titleLabel.text = zimFile.title
        cell.detailLabel.text = [zimFile.fileSizeDescription, zimFile.creationDateDescription, zimFile.articleCountDescription].joined(separator: ", ")
        cell.thumbImageView.image = UIImage(data: zimFile.icon)
        cell.thumbImageView.contentMode = .scaleAspectFit
        cell.accessoryType = zimFile.includeInSearch ? .checkmark : .none
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if sections[indexPath.section] == .recentSearch {
            guard let cell = cell as? RecentSearchTableViewCell else {return}
            cell.collectionView.dataSource = self
            cell.collectionView.delegate = self
            cell.collectionView.tag = indexPath.section
            
            cell.collectionView.reloadData()
            cell.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        let labelText: String = {
            switch sections[section] {
            case .recentSearch:
                return NSLocalizedString("Recent Search", comment: "Search Interface")
            case .searchFilter:
                return NSLocalizedString("Search Filter", comment: "Search Interface")
            }
        }()
        label.text = labelText.uppercased()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor.darkGray
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)
        
        let button = SectionHeaderButton(section: sections[section])
        let buttonText: String = {
            switch sections[section] {
            case .recentSearch:
                return NSLocalizedString("Clear", comment: "Clear Recent Search Texts")
            case .searchFilter:
                return NSLocalizedString("All", comment: "Select All Books in Search Filter")
            }
        }()
        button.setTitle(buttonText, for: .normal)
        button.setTitleColor(UIColor.gray, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        button.addTarget(self, action: #selector(buttonTapped(button:)), for: .touchUpInside)
        
        let stackView = UIStackView()
        stackView.alignment = .bottom
        stackView.preservesSuperviewLayoutMargins = true
        stackView.isLayoutMarginsRelativeArrangement = true
        
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(button)
        label.heightAnchor.constraint(equalTo: button.heightAnchor).isActive = true
        
        return stackView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 50 : 30
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if sections[indexPath.section] == .searchFilter {
            guard let zimFile = localZimFiles?[indexPath.row], let token = token else {return}
            let includeInSearch = !zimFile.includeInSearch
            tableView.cellForRow(at: indexPath)?.accessoryType = includeInSearch ? .checkmark : .none
            do {
                let database = try Realm()
                database.beginWrite()
                zimFile.includeInSearch = includeInSearch
                try database.commitWrite(withoutNotifying: [token])
            } catch {}
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - UICollectionViewDataSource & Delegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return recentSearchTexts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! RecentSearchCollectionViewCell
        cell.label.text = recentSearchTexts[indexPath.row]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let string = recentSearchTexts[indexPath.row]
        let width = NSString(string: string).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 24),
                                                         options: .usesLineFragmentOrigin,
                                                         attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 12)],
                                                         context: nil).size.width
        return CGSize(width: width.rounded(.down) + 20, height: 24)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let searchText = recentSearchTexts[indexPath.row]
        if let main = presentingViewController as? MainController {
            main.searchController.searchBar.text = searchText
        }
    }
}

private class SectionHeaderButton: UIButton {
    private(set) var section: SearchNoTextController.Sections? = nil
    convenience init(section: SearchNoTextController.Sections) {
        self.init(frame: .zero)
        self.section = section
    }
}
