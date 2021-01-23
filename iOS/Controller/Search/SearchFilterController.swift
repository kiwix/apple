//
//  SearchFilterController.swift
//  Kiwix
//
//  Created by Chris Li on 7/31/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

import UIKit
import Defaults
import RealmSwift

class SearchFilterController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    enum Section { case recentSearch, searchFilter }
    
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var sections: [Section] = [.searchFilter]
    private let zimFiles: Results<ZimFile>? = {
        do {
            let database = try Realm(configuration: Realm.defaultConfig)
            let predicate = NSPredicate(format: "stateRaw == %@", ZimFile.State.onDevice.rawValue)
            return database.objects(ZimFile.self).filter(predicate)
        } catch { return nil }
    }()
    private var changeToken: NotificationToken?

    // MARK: - Overrides
    
    override func loadView() {
        view = tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.register(TableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(StackViewTableViewCell.self, forCellReuseIdentifier: "StackViewCell")
        tableView.separatorInsetReference = .fromAutomaticInsets
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if Defaults[.recentSearchTexts].count > 0, !sections.contains(.recentSearch) {
            sections.insert(.recentSearch, at: 0)
        }
        changeToken = zimFiles?.observe({ [unowned self] changes in
            guard case let .update(_, deletions, insertions, updates) = changes,
                  let sectionIndex = self.sections.firstIndex(of: .searchFilter) else { return }
            self.tableView.performBatchUpdates({
                self.tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: sectionIndex) }), with: .fade)
                self.tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: sectionIndex) }), with: .fade)
                updates.forEach({ (row) in
                    let indexPath = IndexPath(row: row, section: sectionIndex)
                    guard let cell = self.tableView.cellForRow(at: indexPath) as? TableViewCell else {return}
                    self.configure(cell: cell, indexPath: indexPath)
                })
            })
        })
        tableView.reloadData()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        changeToken = nil
    }
    
    // MARK: - Actions
    
    @objc func didSelectRecentSearchItem(button: UIButton) {
        guard let searchText = button.title(for: .normal),
              let controller = presentingViewController as? RootViewController else { return }
        controller.searchController.searchBar.text = searchText
    }
    
    @objc func clearRecentSearchItems() {
        let title = NSLocalizedString("Clear Search History", comment: "Clear search history")
        let message = NSLocalizedString("All search history will be wiped clean.", comment: "Clear search history")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive, handler: { _ in
            self.tableView.performBatchUpdates({
                guard let index = self.sections.firstIndex(of: .recentSearch) else { return }
                Defaults[.recentSearchTexts].removeAll()
                self.sections.remove(at: index)
                self.tableView.deleteSections([index], with: .automatic)
            })
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    @objc func inlcudeAllZimFilesInSearch() {
        let database = try? Realm(configuration: Realm.defaultConfig)
        try? database?.write {
            zimFiles?.forEach({ (zimFile) in
                guard !zimFile.includedInSearch else {return}
                zimFile.includedInSearch = true
            })
        }
    }

    // MARK: - UITableViewDataSource & Delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if sections[section] == .searchFilter {
            return zimFiles?.count ?? 0
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
            let cell = tableView.dequeueReusableCell(withIdentifier: "StackViewCell", for: indexPath) as! StackViewTableViewCell
            for text in Defaults[.recentSearchTexts] {
                let button = Button()
                button.setTitle(text, for: .normal)
                button.addTarget(self, action: #selector(didSelectRecentSearchItem), for: .touchUpInside)
                cell.stackView.addArrangedSubview(button)
            }
            return cell
        }
    }
    
    func configure(cell: TableViewCell, indexPath: IndexPath) {
        guard let zimFile = zimFiles?[indexPath.row] else { return }
        cell.titleLabel.text = zimFile.title
        cell.detailLabel.text = [
            zimFile.sizeDescription, zimFile.creationDateShortDescription, zimFile.articleCountLongDescription
        ].compactMap({ $0 }).joined(separator: ", ")
        cell.thumbImageView.image = UIImage(data: zimFile.faviconData ?? Data()) ?? #imageLiteral(resourceName: "GenericZimFile")
        cell.thumbImageView.contentMode = .scaleAspectFit
        cell.accessoryType = zimFile.includedInSearch ? .checkmark : .none
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        guard sections[indexPath.section] == .searchFilter,
              let zimFile = zimFiles?[indexPath.row],
              let token = changeToken
        else { return }
        
        let includedInSearch = !zimFile.includedInSearch
        tableView.cellForRow(at: indexPath)?.accessoryType = includedInSearch ? .checkmark : .none
        
        do {
            let database = try Realm(configuration: Realm.defaultConfig)
            database.beginWrite()
            zimFile.includedInSearch = includedInSearch
            try database.commitWrite(withoutNotifying: [token])
        } catch {}
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.setContentHuggingPriority(UILayoutPriority(rawValue: 250), for: .horizontal)
        switch sections[section] {
        case .recentSearch:
            label.text = NSLocalizedString("Recent Search", comment: "Search Interface")
        case .searchFilter:
            label.text = NSLocalizedString("Search Filter", comment: "Search Interface")
        }

        let button = UIButton()
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        switch sections[section] {
        case .recentSearch:
            button.setTitle(NSLocalizedString("Clear", comment: "Clear Recent Search Texts"), for: .normal)
            button.addTarget(self, action: #selector(clearRecentSearchItems), for: .touchUpInside)
        case .searchFilter:
            button.setTitle(NSLocalizedString("All", comment: "Select All Books in Search Filter"), for: .normal)
            button.addTarget(self, action: #selector(inlcudeAllZimFilesInSearch), for: .touchUpInside)
        }
        
        if #available(iOS 13.0, *) {
            label.textColor = .secondaryLabel
            button.setTitleColor(.secondaryLabel, for: .normal)
        } else {
            label.textColor = .darkGray
            button.setTitleColor(.gray, for: .normal)
        }
        
        let stackView = UIStackView(arrangedSubviews: [label, button])
        stackView.alignment = .firstBaseline
        stackView.preservesSuperviewLayoutMargins = true
        stackView.isLayoutMarginsRelativeArrangement = true
        
        return stackView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 50 : 30
    }
}

fileprivate class StackViewTableViewCell: UITableViewCell {
    let stackView = UIStackView()
    let scrollView = UIScrollView()
    private var configuredConstraints = false
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stackView.arrangedSubviews.forEach({ $0 .removeFromSuperview() })
    }
    
    override func updateConstraints() {
        defer { super.updateConstraints() }
        guard !configuredConstraints else { return }
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        configuredConstraints = true
    }
    
    private func configure() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        contentView.addSubview(scrollView)
        scrollView.showsHorizontalScrollIndicator = false
        stackView.axis = .horizontal
        stackView.spacing = UIStackView.spacingUseSystem
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        setNeedsUpdateConstraints()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentInset = UIEdgeInsets(top: 0, left: layoutMargins.left, bottom: 0, right: layoutMargins.right)
    }
}

fileprivate class Button: UIButton {
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1.0 } }
    
    init() {
        super.init(frame: .zero)
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }
    
    private func configure() {
        setTitleColor(.white, for: .normal)
        setTitleColor(.lightText, for: .highlighted)
        titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        backgroundColor = .systemBlue
        layer.masksToBounds = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.height / 2
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + size.height * 0.85, height: size.height * 0.85)
    }
}
