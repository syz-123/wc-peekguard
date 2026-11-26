import AppKit
import SwiftUI

// Composes the README hero shot: menu bar + the real cover panel on a desktop.
// The panel content is the same view/fonts/colours as CoverView.

struct MenuBar: View {
    var body: some View {
        HStack(spacing: 18) {
            Text("").font(.system(size: 15))
            Text("绿色泡泡").font(.system(size: 13, weight: .semibold))
            Text("文件").font(.system(size: 13))
            Text("编辑").font(.system(size: 13))
            Spacer()
            Text("🙈").font(.system(size: 15))
            Image(systemName: "wifi").font(.system(size: 14))
            Image(systemName: "battery.75").font(.system(size: 15))
            Text("14:27").font(.system(size: 13))
        }
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background(.white.opacity(0.86))
        .overlay(alignment: .bottom) { Rectangle().fill(.black.opacity(0.08)).frame(height: 1) }
    }
}

struct CoverPanelPreview: View {
    var body: some View {
        VStack(spacing: 26) {
            Text("🙈").font(.system(size: 132))
            Text("Hey, don’t you try to peek.")
                .font(.system(size: 34, weight: .medium, design: .rounded))
            Image(systemName: "touchid").font(.system(size: 38)).padding(16)
            Button("Use Mac password…") {}
                .buttonStyle(.plain).font(.system(size: 14)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color(red: 0.32, green: 0.25, blue: 0.22))
        .background(Color(red: 0.98, green: 0.96, blue: 0.92))
    }
}

struct Hero: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(white: 0.93), Color(white: 0.86)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            CoverPanelPreview()
                .frame(width: 1240, height: 600)
                .shadow(color: .black.opacity(0.18), radius: 34, y: 16)
                .padding(.top, 92)
                .padding(.horizontal, 180)
            MenuBar()
        }
        .frame(width: 1600, height: 780)
    }
}

@MainActor
func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, to path: String, scale: CGFloat = 1) throws {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = scale
    guard let cg = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(cg.width)x\(cg.height))")
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/hero.png"
MainActor.assumeIsolated {
    try! render(Hero(), width: 1600, height: 780, to: out)
}
