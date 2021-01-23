//
//  LibraryController.swift
//  Kiwix
//
//  Created by Chris Li on 10/10/17.
//  Copyright © 2017 Chris Li. All rights reserved.
//

import UIKit
import RealmSwift

/**
 Library controller.
 
 The master controller lists zim files that are on device or being downloaded, along with all available zim files grouped by categories.
 The detail controller could be detail of a zim file or all zim files belong to one category.
 */
class LibraryController: UISplitViewController, UISplitViewControllerDelegate {
    let onDismiss: (() -> Void)?
    
    init(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        
        let master = LibraryMasterController()
        viewControllers = [UINavigationController(rootViewController: master)]
        
        preferredDisplayMode = .allVisible
        delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismiss?()
    }
    
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        return true
    }
}

class TableViewCellConfigurator: UIViewController {
    class func configure(_ cell: TableViewCell, zimFile: ZimFile, tableView: UITableView, indexPath: IndexPath) {
        cell.titleLabel.text = zimFile.title
        cell.detailLabel.text = [
            zimFile.sizeDescription, zimFile.creationDateDescription, zimFile.articleCountLongDescription
        ].compactMap({ $0 }).joined(separator: ", ")
        cell.accessoryType = .disclosureIndicator
        cell.thumbImageView.contentMode = .scaleAspectFit

        let zimfileReference = ThreadSafeReference(to: zimFile)
        if let data = zimFile.faviconData, let image = UIImage(data: data) {
            cell.thumbImageView.image = image
        } else if let faviconURL = URL(string: zimFile.faviconURL ?? "") {
            cell.thumbImageView.image = #imageLiteral(resourceName: "GenericZimFile")
            let task = URLSession.shared.dataTask(with: faviconURL) { (data, _, _) in
                guard let data = data, let image = UIImage(data: data) else { return }
                do {
                    let database = try Realm(configuration: Realm.defaultConfig)
                    guard let zimFile = database.resolve(zimfileReference) else { return }
                    try database.write {
                        zimFile.faviconData = data
                    }
                } catch {}
                DispatchQueue.main.async {
                    guard let cell = tableView.cellForRow(at: indexPath) as? TableViewCell else { return }
                    cell.thumbImageView.image = image
                }
            }
            task.resume()
        }
    }
}
