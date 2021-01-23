//
//  BuildingBlocks.swift
//  Kiwix
//
//  Created by Chris Li on 10/26/20.
//  Copyright © 2020 Chris Li. All rights reserved.
//

import SwiftUI
import WebKit

@available(iOS 14.0, *)
extension View {
    @ViewBuilder func hidden(_ isHidden: Bool) -> some View {
        if isHidden {
            self.hidden()
        } else {
            self
        }
    }
}

@available(iOS 14.0, *)
struct WebView: UIViewRepresentable {
    @EnvironmentObject var sceneViewModel: SceneViewModel
    
    func makeUIView(context: Context) -> WKWebView { sceneViewModel.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

@available(iOS 13.0, *)
struct DisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(Font.footnote.weight(.bold))
            .foregroundColor(Color(.systemFill))
    }
}

@available(iOS 13.0, *)
struct Favicon: View {
    let zimFile: ZimFile?
    
    var body: some View {
        let image: Image = {
            if let data = zimFile?.faviconData, let image = UIImage(data: data) {
                return Image(uiImage: image)
            } else {
                return Image("GenericZimFile")
            }
        }()
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return image.resizable()
            .frame(width: 24, height: 24)
            .background(Color(.white))
            .clipShape(shape)
            .overlay(shape.stroke(Color(.white).opacity(0.9), lineWidth: 1))
    }
}

@available(iOS 13.0, *)
extension List {
    func insetGroupedListStyle() -> some View {
        if #available(iOS 14.0, *) {
            return AnyView(self.listStyle(InsetGroupedListStyle()))
        } else {
            return AnyView(self.listStyle(GroupedListStyle()).environment(\.horizontalSizeClass, .regular))
        }
    }
}
