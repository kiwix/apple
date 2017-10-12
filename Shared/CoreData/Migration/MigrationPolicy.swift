//
//  MigrationPolicy.swift
//  Kiwix
//
//  Created by Chris Li on 4/12/16.
//  Copyright © 2016 Chris Li. All rights reserved.
//

import CoreData

class MigrationPolicy1_5: NSEntityMigrationPolicy {
    @objc func negateBool(_ bool: NSNumber) -> NSNumber {
        let bool = bool.boolValue
        return !bool as NSNumber
    }
}

class MigrationPolicy1_8: NSEntityMigrationPolicy {
    @objc func bookState(_ bool: NSNumber?) -> NSNumber {
        if let bool = bool?.boolValue {
            return bool ? NSNumber(value: 2 as Int) : NSNumber(value: 0 as Int)
        } else {
            return NSNumber(value: 1 as Int)
        }
    }
    
    @objc func path(_ url: String) -> String {
        return URL(string: url)?.path ?? ""
    }
}

class MigrationPolicy1_9: NSEntityMigrationPolicy {
    @objc func bookCategory(urlString: String?) -> String? {
        guard let urlString = urlString,
            let components = URL(string: urlString)?.pathComponents,
            components.indices ~= 1 else {return nil}
        if let category = BookCategory(rawValue: components[1]) {
            return category.rawValue
        } else if components[1] == "stack_exchange" {
            return BookCategory.stackExchange.rawValue
        } else {
            return BookCategory.other.rawValue
        }
    }
}
