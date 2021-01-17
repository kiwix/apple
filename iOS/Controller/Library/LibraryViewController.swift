//
//  LibraryViewController.swift
//  Kiwix
//
//  Created by Chris Li on 1/16/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, *)
class LibraryViewController: UISplitViewController, UISplitViewControllerDelegate {
    private let sidebarViewController: UIViewController
    private let sidebarNavigationViewController: UINavigationController
    
    init() {
        let sidebarView = LibrarySidebarView()
        let sidebarViewController = UIHostingController(rootView: sidebarView)
        self.sidebarViewController = sidebarViewController
        self.sidebarNavigationViewController = UINavigationController(rootViewController: sidebarViewController)
        
        self.sidebarNavigationViewController.navigationBar.prefersLargeTitles = true

//        super.init(style: .doubleColumn)
//        preferredDisplayMode = .oneBesideSecondary
//        preferredSplitBehavior = .tile
//        presentsWithGesture = false
        
//        setViewController(self.sidebarViewController, for: .primary)
//        setViewController(UIHostingController(rootView: LibraryCategoryView(category: .wikipedia)), for: .secondary)
        
        super.init(nibName: nil, bundle: nil)
        preferredDisplayMode = .allVisible
        viewControllers = [sidebarNavigationViewController]
        delegate = self
        
        sidebarViewController.rootView.categoryTapped = { [weak self] category in self?.showCategory(category) }
        sidebarViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissController))
        showCategory(.wikipedia)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func dismissController() {
        dismiss(animated: true)
    }
    
    func showCategory(_ category: ZimFile.Category) {
        let controller = UIHostingController(rootView: LibraryCategoryView(category: category))
        controller.navigationItem.title = category.description
        controller.navigationItem.largeTitleDisplayMode = .never
        showDetailViewController(UINavigationController(rootViewController: controller), sender: nil)
    }
    
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        true
    }
}

@available(iOS 13.0, *)
private struct LibrarySidebarView: View {
    var categoryTapped: ((ZimFile.Category) -> Void) = { _ in }
    
    var body: some View {
        List {
            Section(header: Text("Categories")) {
                ForEach(ZimFile.Category.allCases) { category in
                    categoryView(category)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Library", displayMode: .large)
    }
    
    func categoryView(_ category: ZimFile.Category) -> some View {
        Button(action: {
            categoryTapped(category)
        }, label: {
            HStack {
                Image(uiImage: category.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 18, maxHeight: 18)
                    .padding(3)
                    .background(Color(.white))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text(category.description).foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.forward")
                    .font(Font.footnote.weight(.bold))
                    .foregroundColor(Color(.systemFill))
            }
        })
    }
}
