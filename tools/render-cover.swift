import AppKit
import SwiftUI

// Renders the real cover UI to PNG for the README.
// Same fonts, colours and copy as CoverView in Sources/WeChatPrivacy.swift,
// minus the live LocalAuthentication control (which needs a window).

struct CoverPreview: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("🙈").font(.system(size: 100)).accessibilityLabel("Privacy cover")
            Text("Hey, don’t you try to peek.")
                .font(.system(size: 27, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
            Image(systemName: "touchid")
                .font(.system(size: 29))
                .padding(12)
            Button("Use Mac password…") {}
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color(red: 0.32, green: 0.25, blue: 0.22))
        .background(Color(red: 0.98, green: 0.96, blue: 0.92))
        .preferredColorScheme(.light)
    }
}

@MainActor
func render(width: CGFloat, height: CGFloat, to path: String, scale: CGFloat = 2) throws {
    let renderer = ImageRenderer(content: CoverPreview().frame(width: width, height: height))
    renderer.scale = scale
    guard let cg = renderer.cgImage else { throw RenderError.failed }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError.failed }
    try png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path) (\(cg.width)x\(cg.height))")
}

enum RenderError: Error { case failed }

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/cover.png"
MainActor.assumeIsolated {
    try! render(width: 880, height: 620, to: out)
}
