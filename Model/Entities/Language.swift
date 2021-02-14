//
//  Language.swift
//  Kiwix
//
//  Created by Chris Li on 2/14/21.
//  Copyright © 2021 Chris Li. All rights reserved.
//

struct Language: Comparable, Equatable, Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let count: Int?
    
    init?(code: String, count: Int? = nil) {
        if let name = Locale.current.localizedString(forLanguageCode: code) {
            self.code = code
            self.name = name
            self.count = count
        } else {
            return nil
        }
    }
    
    static func < (lhs: Language, rhs: Language) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
