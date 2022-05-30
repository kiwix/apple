//
//  OutlineButton.swift
//  Kiwix
//
//  Created by Chris Li on 5/27/22.
//  Copyright © 2022 Chris Li. All rights reserved.
//

import SwiftUI

struct OutlineButton: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Binding var sheetDisplayMode: SheetDisplayMode?
    @Binding var sidebarDisplayMode: SidebarDisplayMode?
    
    var body: some View {
        Button {
            if horizontalSizeClass == .regular {
                withAnimation(sidebarDisplayMode == nil ?  .easeOut(duration: 0.18) : .easeIn(duration: 0.18)) {
                    sidebarDisplayMode = sidebarDisplayMode != .outline ? .outline : nil
                }
            } else {
                sheetDisplayMode = .outline
            }
        } label: {
            Image(systemName: "list.bullet")
        }
    }
}