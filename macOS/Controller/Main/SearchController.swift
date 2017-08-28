//
//  SearchController.swift
//  macOS
//
//  Created by Chris Li on 8/22/17.
//  Copyright © 2017 Chris Li. All rights reserved.
//

import Cocoa

class SearchResultWindowController: NSWindowController {
    override func windowDidLoad() {
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.standardWindowButton(NSWindowButton.closeButton)?.isHidden = true
        window?.standardWindowButton(NSWindowButton.miniaturizeButton)?.isHidden = true
        window?.standardWindowButton(NSWindowButton.fullScreenButton)?.isHidden = true
        window?.standardWindowButton(NSWindowButton.zoomButton)?.isHidden = true
    }
}

class SearchResultContainerController: NSViewController {
    @IBOutlet weak var visiualEffect: NSVisualEffectView!
    override func viewDidLoad() {
        super.viewDidLoad()
        configureVisiualEffectView()
    }
    
    func configureVisiualEffectView() {
        visiualEffect.blendingMode = .behindWindow
        visiualEffect.state = .active
        if #available(OSX 10.11, *) {
            visiualEffect.material = .menu
        } else {
            visiualEffect.material = .light
        }
        visiualEffect.wantsLayer = true
        visiualEffect.layer?.cornerRadius = 4.0
    }
}

class SearchController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    let searchMenu = NSMenu()
    var searchResults: [(id: String, title: String, path: String, snippet: NSAttributedString)] = []
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBAction func searchFieldChanged(_ sender: NSSearchField) {
        guard let controller = view.window?.windowController as? MainWindowController else {return}
        controller.loadingView.startAnimation(sender)
        searchResults = ZimManager.shared.getSearchResults(searchTerm: sender.stringValue)
        tableView.reloadData()
        controller.loadingView.stopAnimation(sender)
    }
    @IBAction func tableViewClicked(_ sender: NSTableView) {
        guard tableView.selectedRow >= 0 else {return}
        let result = searchResults[tableView.selectedRow]
        guard let url = URL(bookID: result.id, contentPath: result.path) else {return}
        guard let split = view.window?.contentViewController as? NSSplitViewController,
            let controller = split.splitViewItems.last?.viewController as? WebViewController else {return}
        controller.load(url: url)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configSearchMenu()
    }
    
    func configSearchMenu() {
        let clear = NSMenuItem(title: "Clear", action: nil, keyEquivalent: "")
        clear.tag = Int(NSSearchFieldClearRecentsMenuItemTag)
        searchMenu.insertItem(clear, at: 0)
        
        searchMenu.insertItem(NSMenuItem.separator(), at: 0)
        
        let recents = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        recents.tag = Int(NSSearchFieldRecentsMenuItemTag)
        searchMenu.insertItem(recents, at: 0)
        
        let recentHeader = NSMenuItem(title: "Recent Search", action: nil, keyEquivalent: "")
        recentHeader.tag = Int(NSSearchFieldRecentsTitleMenuItemTag)
        searchMenu.insertItem(recentHeader, at: 0)
        
        let noRecent = NSMenuItem(title: "No Recent Search", action: nil, keyEquivalent: "")
        noRecent.tag = Int(NSSearchFieldNoRecentsMenuItemTag)
        searchMenu.insertItem(noRecent, at: 0)
        
        searchField.searchMenuTemplate = searchMenu
    }
    
    func clearSearch() {
        searchField.stringValue = ""
        searchResults = []
        tableView.reloadData()
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        if let row = tableView.make(withIdentifier: "ResultRow", owner: self) as? SearchResultTableRowView {
            return row
        } else {
            let row = SearchResultTableRowView()
            row.identifier = "ResultRow"
            return row
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.make(withIdentifier: "Result", owner: self) as! SearchResultTableCellView
        cell.titleField.stringValue = searchResults[row].title
        cell.snippetField.attributedStringValue = searchResults[row].snippet
        return cell
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 92
    }
}
