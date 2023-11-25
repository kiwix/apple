//  Copyright © 2023 Kiwix. All rights reserved.

import Foundation

enum FeatureFlags {
#if DEBUG
    static let wikipediaDarkUserCSS: Bool = true
    static let map: Bool = true
#else
    static let wikipediaDarkUserCSS: Bool = false
    static let map: Bool = false
#endif
    /// Custom apps, which have a bundled zim file, do not require library access
    /// this will remove all library related features
    static let hasLibrary: Bool = Config.value(for: .hasLibrary) ?? true
}
