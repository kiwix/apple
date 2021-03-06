//
//  OutlineView.swift
//  Kiwix
//
//  Created by Chris Li on 11/10/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

import SwiftUI

@available(iOS 14.0, *)
struct OutlineView: View {
    @EnvironmentObject private var sceneViewModel: SceneViewModel
    @Binding var isSheetPresented: Bool
    
    var body: some View {
        switch sceneViewModel.contentDisplayMode {
        case .web:
            if let outlineItems = sceneViewModel.currentArticleOutlineItems, !outlineItems.isEmpty {
                List(outlineItems, id: \.index) { outlineItem in
                    Button {
                        sceneViewModel.navigateToOutlineItem(index: outlineItem.index)
                        if sceneViewModel.shouldAutoHideSidebar { sceneViewModel.hideSidebar() }
                        isSheetPresented = false
                    } label: {
                        if outlineItem.level == 1 {
                            HStack {
                                Spacer()
                                Text(outlineItem.text).bold()
                                Spacer()
                            }
                        } else {
                            Text(outlineItem.text).padding(.leading, 20 * CGFloat(outlineItem.level - 2))
                        }
                    }
                }
            } else {
                unavailable
            }
        case .home:
            unavailable
        case .transition:
            Color(.systemBackground)
        }
    }
    
    var unavailable: some View {
        VStack(spacing: 20) {
            Image("Compass").resizable().frame(width: 100, height: 100)
            Text("Outline not available.").font(.headline).fontWeight(.semibold)
        }
    }
}
