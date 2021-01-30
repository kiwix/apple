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
    private let image: Image
    private let outline = RoundedRectangle(cornerRadius: 4, style: .continuous)
    
    init (data: Data?) {
        if let data = data, let image = UIImage(data: data) {
            self.image = Image(uiImage: image)
        } else {
            self.image = Image("GenericZimFile")
        }
    }
    
    var body: some View {
        image
            .renderingMode(.original)
            .resizable()
            .frame(width: 24, height: 24)
            .background(Color(.white))
            .clipShape(outline)
            .overlay(outline.stroke(Color(.white).opacity(0.9), lineWidth: 1))
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

@available(iOS 13.0, *)
struct CompactZimFileView: View {
    let metadata: ZimFileMetadata
    let displayOnDeviceIndicator: Bool
    
    init(_ metadata: ZimFileMetadata, displayOnDeviceIndicator: Bool = false) {
        self.metadata = metadata
        self.displayOnDeviceIndicator = displayOnDeviceIndicator
    }
    
    var body: some View {
        HStack {
            Favicon(data: metadata.faviconData)
            VStack(alignment: .leading) {
                Text(metadata.title)
                Spacer(minLength: 2)
                Text(metadata.detail).font(.footnote)
            }.foregroundColor(.primary)
            Spacer()
            if metadata.state == .onDevice, displayOnDeviceIndicator {
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Image(systemName:"iphone").foregroundColor(.secondary)
                } else if UIDevice.current.userInterfaceIdiom == .pad {
                    Image(systemName:"ipad").foregroundColor(.secondary)
                }
            }
            DisclosureIndicator()
        }
    }
}
