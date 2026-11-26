import AppKit
import SwiftUI
import LocalAuthentication
import LocalAuthenticationEmbeddedUI
import CoreGraphics

// Pure session rules: no message text or keystrokes are collected.
struct Session {
    var isPublic = true
    var covered = true
    var lastInteraction: TimeInterval = 0
    mutating func beginPublic(now: TimeInterval) {
        isPublic = true; covered = false; lastInteraction = now
    }
    mutating func tick(now: TimeInterval, wechatActive: Bool, latestInput: TimeInterval) {
        guard isPublic && !covered else { return }
        // Expiration wins over an event arriving after an idle session has ended.
        if now - lastInteraction >= 15 { covered = true; return }
        if wechatActive && latestInput > lastInteraction && latestInput <= now {
            lastInteraction = latestInput
        }
    }
    mutating func revealed(now: TimeInterval) { covered = false; lastInteraction = now }
    mutating func makePrivate() { isPublic = false; covered = false }
}

// The visible target stays active. These rules never require a focus handoff.
struct OverlayPolicy {
    enum Action: Equatable { case present, keepDuringAuthentication, hideInactiveTarget }
    static func action(targetActive: Bool, helperActive: Bool, authenticating: Bool) -> Action {
        if targetActive || helperActive { return .present }
        if authenticating { return .keepDuringAuthentication }
        return .hideInactiveTarget
    }
}
struct PromptGate {
    private(set) var attempted = false
    mutating func claim() -> Bool {
        guard !attempted else { return false }
        attempted = true; return true
    }
    mutating func leaveForAnotherApp() { attempted = false }
}
final class CoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
struct TargetWindow {
    var id: Int
    var frame: NSRect
    var onscreen: Bool
}
@MainActor final class Privacy: NSObject, ObservableObject, NSApplicationDelegate {
    @Published var authenticating = false
    @Published var message = ""
    private var session = Session()
    private var statusItem: NSStatusItem!
    private var panels: [Int: CoverPanel] = [:]
    private var timer: Timer?
    private var context: LAContext?
    @Published private(set) var embeddedContext: LAContext?
    @Published private(set) var authenticationPanelID: Int?
    private var embeddedReady = false
    private var generation = UUID()
    private var hiddenByUs = Set<pid_t>()
    private var seenPID: pid_t?
    private var observers: [NSObjectProtocol] = []
    private var promptGate = PromptGate()
    private var updating = false
    private var forcePresent = false
    private let bundle = "com.tencent.xinWeChat"
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var targets: [NSRunningApplication] { NSRunningApplication.runningApplications(withBundleIdentifier: bundle) }
    private var targetActive: Bool { NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count > 1 {
            NSApp.terminate(nil); return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateMenu()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                // Authentication agents are not user visits to another regular app.
                // A failed/cancelled prompt must not immediately prompt again.
                if let app = app, app.activationPolicy == .regular,
                   app.bundleIdentifier != self.bundle,
                   app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    if !self.authenticating { self.promptGate.leaveForAnotherApp() }
                    self.forcePresent = false
                }
                self.tick()
            }
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cover(prompt: false) }
            })
        }
        timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        tick()
    }
    func windows() -> [TargetWindow] {
        guard let data = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let screen = NSScreen.screens.first else { return [] }
        let apps = targets
        let pids = Set(apps.map { Int($0.processIdentifier) })
        return data.compactMap { item in
            guard let pid = item[kCGWindowOwnerPID as String] as? Int else { return nil }
            let owner = NSRunningApplication(processIdentifier: pid_t(pid))
            let isTarget = pids.contains(pid) || apps.contains { app in
                guard let root = app.bundleURL?.path, let path = owner?.bundleURL?.path else { return false }
                return path.hasPrefix(root + "/")
            }
            guard isTarget, (item[kCGWindowLayer as String] as? Int) == 0,
                  let id = item[kCGWindowNumber as String] as? Int,
                  let bounds = item[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds), rect.width >= 80, rect.height >= 60 else { return nil }
            return TargetWindow(id: id,
                frame: NSRect(x: rect.minX, y: screen.frame.maxY - rect.maxY, width: rect.width, height: rect.height),
                onscreen: item[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }
    }
    func makePanel(id: Int) -> CoverPanel {
        let panel = CoverPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "WeChat Privacy"
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: CoverView(privacy: self, panelID: id).clipped())
        return panel
    }
    func latestInput() -> TimeInterval {
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .leftMouseDragged, .rightMouseDragged]
        let age = types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? .infinity
        return now - age
    }
    func hidePanels() { for panel in panels.values { panel.orderOut(nil) } }
    func hideInactiveTargets() {
        // Never hide the active WeChat process: that was the source of the race.
        guard !targetActive else { return }
        for app in targets where !app.isHidden && !app.isActive {
            if app.hide() { hiddenByUs.insert(app.processIdentifier) }
        }
        // Wait for hiding to finish before taking the covers away.
        if targets.allSatisfy({ $0.isHidden }) { hidePanels() }
    }
    func presentPanels(prompt: Bool) {
        let all = windows()
        let visible = all.filter { $0.onscreen }
        // A manually requested cover can use the last hidden window footprint.
        let frames = visible.isEmpty && forcePresent ? all : visible
        guard !frames.isEmpty else { return }
        let ids = Set(frames.map { $0.id })
        for id in Array(panels.keys) where !ids.contains(id) {
            panels.removeValue(forKey: id)?.orderOut(nil)
        }
        for entry in frames {
            let panel = panels[entry.id] ?? makePanel(id: entry.id)
            panels[entry.id] = panel
            if panel.frame != entry.frame { panel.setFrame(entry.frame, display: false) }
            // No NSApp.activate and no makeKeyAndOrderFront in the polling loop.
            if !panel.isVisible { panel.orderFrontRegardless() }
        }
        let largest = frames.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
        if let id = largest?.id, let panel = panels[id], !authenticating, !panel.isKeyWindow {
            // A non-activating panel can receive keys without changing the active app.
            panel.makeKey()
        }
        if prompt && !authenticating && promptGate.claim() { unlock() }
    }
    func tick() {
        guard !updating else { return }
        updating = true; defer { updating = false }
        let apps = targets
        guard !apps.isEmpty else {
            seenPID = nil; forcePresent = false; hidePanels(); return
        }
        if seenPID != apps.first?.processIdentifier {
            seenPID = apps.first?.processIdentifier
            session.covered = true; promptGate.leaveForAnotherApp()
        }
        let active = targetActive
        let wasCovered = session.covered
        session.tick(now: now, wechatActive: active, latestInput: latestInput())
        guard session.covered else { return }
        switch OverlayPolicy.action(targetActive: active, helperActive: forcePresent || NSApp.isActive, authenticating: authenticating) {
        case .present: presentPanels(prompt: true)
        case .keepDuringAuthentication: break
        case .hideInactiveTarget: hideInactiveTargets()
        }
        if !wasCovered { updateMenu() }
    }
    func cover(prompt: Bool) {
        generation = UUID(); context?.invalidate(); context = nil
        embeddedContext = nil; authenticationPanelID = nil; embeddedReady = false
        authenticating = false; message = ""
        session.covered = true; promptGate.leaveForAnotherApp()
        forcePresent = prompt
        if prompt { presentPanels(prompt: true) }
        else { hideInactiveTargets() }
        updateMenu()
    }
    func restoreWeChat() {
        forcePresent = false
        hidePanels()
        // No application activation is needed: the overlay left WeChat active.
        // If it was explicitly opened from the menu, only restore our own hiding.
        for app in targets where hiddenByUs.contains(app.processIdentifier) { app.unhide() }
        hiddenByUs.removeAll()
        // Authentication temporarily activates this helper; hand focus back once.
        if NSApp.isActive, let target = targets.first {
            NSApp.yieldActivation(to: target)
            target.activate(options: [.activateAllWindows])
        }
    }
    func embeddedViewReady(_ auth: LAContext) {
        if context === auth { embeddedReady = true }
    }
    func authenticate(embedded: Bool = true, then completion: @escaping () -> Void) {
        guard !authenticating else { return }
        let auth = LAContext()
        let policy: LAPolicy = embedded ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        var error: NSError?
        guard auth.canEvaluatePolicy(policy, error: &error) else {
            message = embedded ? "Touch ID isn’t available. Use your Mac password below." : "Mac authentication isn’t available. Check your login settings."
            return
        }
        generation = UUID(); let token = generation
        context = auth; authenticating = true; message = ""
        embeddedReady = false
        if embedded {
            authenticationPanelID = panels.filter { $0.value.isVisible }.max {
                $0.value.frame.width * $0.value.frame.height < $1.value.frame.width * $1.value.frame.height
            }?.key
            embeddedContext = auth
        } else {
            embeddedContext = nil; authenticationPanelID = nil
            // Only the explicitly requested password/system-dialog path activates
            // the helper. Embedded Touch ID uses the existing key cover panel.
            NSApp.activate()
        }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Pair the real system authentication view with this exact context
            // and attach it to the window before beginning policy evaluation.
            for _ in 0..<100 {
                guard self.generation == token else { return }
                if embedded ? self.embeddedReady : NSApp.isActive { break }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            guard self.generation == token else { return }
            guard embedded ? self.embeddedReady : NSApp.isActive else {
                self.authenticating = false; self.context = nil; self.embeddedContext = nil
                self.message = "Authentication couldn’t start. Tap the fingerprint or use your Mac password."
                return
            }
            if embedded, let id = self.authenticationPanelID { self.panels[id]?.makeKey() }
            auth.evaluatePolicy(policy, localizedReason: "Reveal WeChat behind your privacy cover.") { [weak self] success, _ in
                Task { @MainActor in
                    guard let self = self, self.generation == token else { return }
                    self.authenticating = false; self.context = nil; self.embeddedContext = nil
                    self.authenticationPanelID = nil; self.embeddedReady = false
                    if success { completion() }
                    else { self.message = "Still tucked away. Tap the fingerprint or use your Mac password." }
                }
            }
        }
    }

    func unlock() {
        authenticate { [weak self] in
            guard let self = self else { return }
            self.session.revealed(now: self.now)
            self.restoreWeChat(); self.updateMenu()
        }
    }
    func unlockWithPassword() {
        if authenticating && embeddedContext != nil {
            generation = UUID(); context?.invalidate(); context = nil
            embeddedContext = nil; authenticationPanelID = nil; embeddedReady = false
            authenticating = false
        }
        authenticate(embedded: false) { [weak self] in
            guard let self = self else { return }
            self.session.revealed(now: self.now)
            self.restoreWeChat(); self.updateMenu()
        }
    }
    @objc func lockNow() { cover(prompt: true) }
    @objc func openCover() {
        if session.covered {
            forcePresent = true
            presentPanels(prompt: true)
        } else {
            let alert = NSAlert()
            alert.messageText = "🙈 WeChat Privacy"
            alert.informativeText = "WeChat is covered after 15 seconds without interaction. Touch ID appears automatically when you return. Quit this app to turn protection off; open WeChat Privacy from Applications to turn it back on."
            alert.addButton(withTitle: "OK"); alert.runModal()
        }
    }
    @objc func quitHelper() {
        authenticate(embedded: false) { [weak self] in
            guard let self = self else { return }
            self.restoreWeChat(); NSApp.terminate(nil)
        }
    }
    func updateMenu() {
        statusItem.button?.title = "🙈"
        statusItem.button?.font = .systemFont(ofSize: 14)
        statusItem.button?.toolTip = "WeChat Privacy · Auto-cover on · 15 seconds"
        statusItem.button?.setAccessibilityLabel(statusItem.button?.toolTip)
        let menu = NSMenu()
        menu.addItem(withTitle: "Cover WeChat now", action: #selector(lockNow), keyEquivalent: "")
        menu.addItem(withTitle: session.covered ? "Show privacy cover…" : "About WeChat Privacy…", action: #selector(openCover), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit WeChat Privacy…", action: #selector(quitHelper), keyEquivalent: "")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openCover(); return true }
}

// Mount the system-owned fingerprint view in the cover. Its paired LAContext
// controls authentication, keeping biometric processing entirely in macOS.
final class EmbeddedAuthHost: NSView {
    let icon: LAAuthenticationView
    let ready: () -> Void
    init(auth: LAContext, ready: @escaping () -> Void) {
        icon = LAAuthenticationView(context: auth, controlSize: .large)
        self.ready = ready
        super.init(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { ready() }
    }
}
struct EmbeddedFingerprint: NSViewRepresentable {
    let auth: LAContext
    let ready: () -> Void
    func makeNSView(context: Context) -> EmbeddedAuthHost { EmbeddedAuthHost(auth: auth, ready: ready) }
    func updateNSView(_ nsView: EmbeddedAuthHost, context: Context) {}
}
struct CoverView: View {
    @ObservedObject var privacy: Privacy
    let panelID: Int
    var body: some View {
        VStack(spacing: 24) {
            Text("🙈").font(.system(size: 100)).accessibilityLabel("Privacy cover")
            Text("Hey, don’t you try to peek.")
                .font(.system(size: 27, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
            if let auth = privacy.embeddedContext, privacy.authenticationPanelID == panelID {
                EmbeddedFingerprint(auth: auth) { privacy.embeddedViewReady(auth) }
                    .id(ObjectIdentifier(auth)).frame(width: 64, height: 64)
                    .accessibilityLabel("Rest your finger on Touch ID to reveal WeChat")
            } else {
                Button { privacy.unlock() } label: {
                    Image(systemName: "touchid").font(.system(size: 29)).padding(12)
                }.buttonStyle(.plain).disabled(privacy.authenticating)
                    .help("Retry Touch ID").accessibilityLabel("Retry Touch ID")
            }
            Button("Use Mac password…") { privacy.unlockWithPassword() }
                .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                .disabled(privacy.authenticating && privacy.embeddedContext == nil)
            if !privacy.message.isEmpty { Text(privacy.message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center) }
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Color(red: 0.32, green: 0.25, blue: 0.22))
            .background(Color(red: 0.98, green: 0.96, blue: 0.92))
            .preferredColorScheme(.light)
    }
}

func selfTest() {
    var s = Session()
    s.revealed(now: 100)
    s.tick(now: 114, wechatActive: true, latestInput: 100); precondition(!s.covered)
    s.tick(now: 115, wechatActive: true, latestInput: 115); precondition(s.covered)
    s.revealed(now: 200)
    s.tick(now: 210, wechatActive: true, latestInput: 209)
    s.tick(now: 223, wechatActive: false, latestInput: 223); precondition(!s.covered)
    s.tick(now: 224, wechatActive: false, latestInput: 224); precondition(s.covered)
    precondition(OverlayPolicy.action(targetActive: true, helperActive: false, authenticating: false) == .present)
    precondition(OverlayPolicy.action(targetActive: true, helperActive: false, authenticating: true) == .present)
    precondition(OverlayPolicy.action(targetActive: false, helperActive: false, authenticating: true) == .keepDuringAuthentication)
    precondition(OverlayPolicy.action(targetActive: false, helperActive: false, authenticating: false) == .hideInactiveTarget)
    precondition(OverlayPolicy.action(targetActive: false, helperActive: true, authenticating: false) == .present)
    var prompt = PromptGate()
    precondition(prompt.claim())
    for _ in 0..<100 { precondition(!prompt.claim()) }
    prompt.leaveForAnotherApp(); precondition(prompt.claim()); precondition(!prompt.claim())
    print("PASS: 15-second deadline; WeChat activity resets deadline; other-app activity does not")
    print("PASS: active WeChat uses overlay; background hides inactive target; authentication retains cover")
    print("PASS: one automatic prompt per visit; cancellation cannot cause repeated polling prompts; returning allows another prompt")
}
if CommandLine.arguments.contains("--self-test") { selfTest(); exit(0) }
let app = NSApplication.shared
let privacy = MainActor.assumeIsolated { Privacy() }
app.delegate = privacy
app.setActivationPolicy(.accessory)
app.run()
