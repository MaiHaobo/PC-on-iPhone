//
// Copyright © 2026 PC on iPhone. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI
import UIKit

// MARK: - Gamepad

/// The fifteen gamepad button remap rows, all sharing the same long list of
/// assignable keys. Reusing one picker keeps the group readable.
struct SettingsGamepadRows: View {
    /// Every key the gamepad buttons can be mapped to, in the same order as the
    /// original `Root.plist`. Labels are `LocalizedStringKey` so the picker
    /// localises them; single-letter and symbol keys simply have no entry in
    /// the strings table and fall back to themselves.
    static let keyOptions: [(title: LocalizedStringKey, value: Int)] = [
        ("Disabled", 0),
        ("Mouse Left Button", -1),
        ("Mouse Right Button", -3),
        ("Mouse Middle Button", -2),
        ("Ctrl", 29),
        ("Command/Windows", 57435),
        ("Option/Alt", 56),
        ("Shift", 42),
        ("Tab", 15),
        ("Space", 57),
        ("Enter", 28),
        ("Backspace", 14),
        ("Esc", 1),
        ("Caps", 58),
        ("`", 41),
        ("1", 2),
        ("2", 3),
        ("3", 4),
        ("4", 5),
        ("5", 6),
        ("6", 7),
        ("7", 8),
        ("8", 9),
        ("9", 10),
        ("0", 11),
        ("-", 12),
        ("=", 13),
        ("[", 26),
        ("]", 27),
        (";", 39),
        ("'", 40),
        ("\\", 43),
        (",", 51),
        (".", 52),
        ("/", 53),
        ("Ins", 57426),
        ("Home", 57415),
        ("PgUp", 57417),
        ("PgDn", 57425),
        ("Del", 57427),
        ("End", 57423),
        ("Up", 200),
        ("Left", 203),
        ("Down", 208),
        ("Right", 205),
        ("A", 30),
        ("B", 48),
        ("C", 46),
        ("D", 32),
        ("E", 18),
        ("F", 33),
        ("G", 34),
        ("H", 35),
        ("I", 23),
        ("J", 36),
        ("K", 37),
        ("L", 38),
        ("M", 50),
        ("N", 49),
        ("O", 24),
        ("P", 25),
        ("Q", 16),
        ("R", 19),
        ("S", 31),
        ("T", 20),
        ("U", 22),
        ("V", 47),
        ("W", 17),
        ("X", 45),
        ("Y", 21),
        ("Z", 44),
        ("F1", 59),
        ("F2", 60),
        ("F3", 61),
        ("F4", 62),
        ("F5", 63),
        ("F6", 64),
        ("F7", 65),
        ("F8", 66),
        ("F9", 67),
        ("F10", 68),
        ("F11", 87),
        ("F12", 88),
    ]

    /// `(title, defaults key, default value)` for each remappable button.
    private static let buttons: [(title: LocalizedStringKey, key: String, defaultValue: Int)] = [
        ("Menu", "GCButtonMenu", 1),
        ("Options", "GCButtonOptions", 0),
        ("Home", "GCButtonHome", 0),
        ("D-UP", "GCButtonDpadUp", 17),
        ("D-LEFT", "GCButtonDpadLeft", 30),
        ("D-DOWN", "GCButtonDpadDown", 31),
        ("D-RIGHT", "GCButtonDpadRight", 32),
        ("A", "GCButtonA", 0),
        ("B", "GCButtonB", 0),
        ("X", "GCButtonX", 0),
        ("Y", "GCButtonY", 0),
        ("L1", "GCButtonShoulderLeft", 0),
        ("L2", "GCButtonTriggerLeft", 0),
        ("R1", "GCButtonShoulderRight", 0),
        ("R2", "GCButtonTriggerRight", 0),
    ]

    var body: some View {
        ForEach(Self.buttons, id: \.key) { button in
            SettingsGamepadRow(title: button.title,
                               key: button.key,
                               defaultValue: button.defaultValue)
        }
    }
}

private struct SettingsGamepadRow: View {
    let title: LocalizedStringKey
    let key: String
    let defaultValue: Int

    @AppStorage private var value: Int

    init(title: LocalizedStringKey, key: String, defaultValue: Int) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        self._value = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        Picker(selection: $value) {
            ForEach(SettingsGamepadRows.keyOptions, id: \.value) { option in
                Text(option.title).tag(option.value)
            }
        } label: {
            // Every button row carries the same gamepad glyph. The row titles
            // are one or two characters ("A", "L1"), so a per-button symbol
            // would be noise; a constant badge is what makes the group read as
            // one block, the way the system Settings app badges repeated rows.
            Label(title, systemImage: "gamecontroller")
                .labelStyle(.settingsIcon(.gamepad))
        }
        .pickerStyle(.menu)
    }
}

// MARK: - JitStreamer detail

/// The JitStreamer address is edited on its own pane so the list row stays a
/// simple disclosure, matching how the address used to live on a child page.
struct SettingsJitStreamerView: View {
    @AppStorage("JitStreamerAddress") private var address = "69.69.0.1"

    var body: some View {
        Form {
            Section {
                TextField("JitStreamer IP Address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            } footer: {
                Text("The IP address of the machine running JitStreamer, reachable by this device.")
            }
        }
        .navigationTitle("JitStreamer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - License

/// Renders the bundled `License.plist` (the upstream open-source notices) as a
/// scrollable page. The plist holds a single `PSGroupSpecifier` whose
/// `FooterText` is one large Markdown document listing every dependency and its
/// licence.
struct SettingsLicenseView: View {
    // Parsed once per app run: the document is ~80 KB of Markdown, so we avoid
    // re-parsing it on every view rebuild.
    private static let markdown: String = loadMarkdown()

    /// The Markdown rendered to an `AttributedString`. `Text(LocalizedStringKey)`
    /// is not used here: the document is far too large to be an effective
    /// localisation key.
    private var attributed: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible)
        return (try? AttributedString(markdown: Self.markdown, options: options))
            ?? AttributedString(Self.markdown)
    }

    var body: some View {
        ScrollView {
            Text(attributed)
                .font(.footnote)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("License")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func loadMarkdown() -> String {
        // License.plist ships inside Settings.bundle (it was originally the
        // `File` target of a PSChildPaneSpecifier), so it must be looked up
        // there rather than at the top level of the app bundle.
        guard let settingsBundleURL = Bundle.main.url(forResource: "Settings", withExtension: "bundle"),
              let settingsBundle = Bundle(url: settingsBundleURL),
              let url = settingsBundle.url(forResource: "License", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let root = plist as? [String: Any],
              let specifiers = root["PreferenceSpecifiers"] as? [[String: Any]],
              let footer = specifiers.first?["FooterText"] as? String else {
            return ""
        }
        return footer
    }
}

// MARK: - App info

/// Reads the marketing version and build number straight from the bundle,
/// replacing the two deprecated `PSTitleValueSpecifier` rows.
enum SettingsInfo {
    /// The marketing version, with the pre-release label appended when one is
    /// set. Keeping the label out of `CFBundleShortVersionString` matters:
    /// iOS compares that string when deciding whether an update is newer, and
    /// a suffix like "0.5.2 Beta 3" would make the comparison meaningless.
    static var version: String {
        let base = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let label = Bundle.main.object(forInfoDictionaryKey: "PCIPreReleaseLabel") as? String
        guard let label, !label.isEmpty else {
            return base
        }
        return "\(base) \(label)"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}

// MARK: - JIT guide

/// Why the guide is on screen. Both entry points show the same steps; only
/// the wording of the first line differs.
enum JITGuideReason {
    /// Detected on launch: the process has no JIT and the app would otherwise
    /// silently fall back to interpreters.
    case launch
    /// The user reached for a feature that cannot work without JIT.
    case newVirtualMachine
}

/// Walks the user through enabling JIT, then plays the confirmation animation.
///
/// Presented as a full-screen cover over the launch animation, so the mark
/// the user just watched fan apart is the same mark that starts spinning.
struct JITGuideView: View {
    var reason: JITGuideReason
    /// Called after the closing animation has finished.
    var onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("JitStreamerAddress") private var address = "69.69.0.1"

    /// The shipped placeholder from the Settings pane. The guide only reveals
    /// the field once the user has changed it away from this, because it is
    /// not a real server address and showing it invites confusion.
    private static let jitStreamerDefault = "69.69.0.1"

    private enum Phase: Equatable {
        /// Explaining the steps, waiting for the user to start.
        case instructions
        /// Reaching for the JIT server; the mark spins.
        case enabling
        /// The mark freezes, then plays the launch fan-out as a finale.
        case finished
    }

    @State private var phase: Phase = .instructions
    @State private var failureMessage: String?
    /// Set once the hand-off fails, which swaps the steps for the manual
    /// LocalDevVPN → StikDebug → return walkthrough.
    @State private var showsFallbackSteps = false
    /// Continuous rotation, in degrees. The spinner drives this 0 → 360 and
    /// repeats; `settle` stops it at a whole turn so the stop is seamless.
    @State private var angle: Double = 0
    @State private var isSpinning = false
    @State private var settled = false

    var body: some View {
        ZStack {
            LiquidGlassPaper()

            switch phase {
            case .instructions:
                instructions
                    .transition(.opacity)
            case .enabling, .finished:
                spinner
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: phase)
        // Cannot be swiped away: the only exits are a successful enable or
        // closing the app, and an accidental dismiss during an attach would
        // leave the process half-configured.
        .interactiveDismissDisabled()
        // The hand-off happens in StikDebug, so the interesting moment is the
        // user coming back. Without this the guide would keep spinning for
        // the rest of its timeout even though JIT is already on.
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)) { _ in
            guard phase == .enabling, Main.refreshJITAvailability() else { return }
            Task { await settleAndFinish() }
        }
    }

    // MARK: Instructions

    private var instructions: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            LiquidGlassMark(side: 76)
                .padding(.bottom, 24)

            Text("Enable JIT")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.bottom, 10)

            Text(reason == .newVirtualMachine
                 ? "Emulating another architecture needs JIT compilation. Without it, virtual machines fall back to a much slower interpreter."
                 : "This build runs virtual machines through JIT compilation, which iOS only allows when it is switched on from outside the app.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 32)

            Spacer(minLength: 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if showsFallbackSteps {
                        // Reached only after the hand-off failed, so the user
                        // gets the step-by-step route instead of a dead end.
                        step(1, "Connect LocalDevVPN",
                             "StikDebug does not work without the loopback VPN running.",
                             action: ("Open LocalDevVPN", openLocalDevVPN))
                        step(2, "Import the pairing file in StikDebug",
                             "One-time setup. Generate it on a computer with iLoader or iDevicePair.",
                             action: ("Open StikDebug", openStikDebug))
                        step(3, "Pick PC on iPhone and start JIT",
                             "On iOS 26+ StikDebug also needs the UTM debug script assigned.",
                             action: ("Open StikDebug", openStikDebug))
                        step(4, "Come back here",
                             "JIT is detected automatically when the app returns.",
                             action: nil)
                    } else {
                        step(1, "LocalDevVPN must be connected",
                             "StikDebug needs the loopback VPN. Turn it on first if it is not.",
                             action: ("Open LocalDevVPN", openLocalDevVPN))
                        step(2, "Tap below to hand off to StikDebug",
                             "PC on iPhone asks StikDebug to attach to this very process.",
                             action: nil)
                        step(3, "Return to PC on iPhone",
                             "JIT is detected automatically and the animation finishes.",
                             action: nil)
                    }

                    if address != Self.jitStreamerDefault {
                        HStack(spacing: 10) {
                            TextField("JitStreamer IP Address", text: $address)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.14),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(18)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 18)
            }

            Text("Not installed? StikDebug is the standard way to enable JIT on a sideloaded build.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 10)

            if let failureMessage {
                Text(failureMessage)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                    .padding(.top, 10)
            }

            Button {
                Task { await handOffToStikDebug() }
            } label: {
                Text(showsFallbackSteps ? "Try Again" : "Turn On JIT")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(colorScheme == .dark
                                     ? LiquidGlassMark.glassBottom
                                     : LiquidGlassMark.glassTop)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

            Button(role: .cancel) {
                onDismiss()
            } label: {
                Text("Not Now")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .foregroundStyle(.white)
    }

    /// A numbered step, optionally carrying the button that performs it.
    private func step(_ number: Int,
                      _ title: String,
                      _ detail: String,
                      action: (String, () -> Void)?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.22), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                if let (label, run) = action {
                    Button(action: run) {
                        Text(label)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18),
                                        in: Capsule())
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Spinner

    private var spinner: some View {
        VStack(spacing: 22) {
            LiquidGlassMark(side: 84,
                            scatter: settled ? 1 : 0,
                            spin: .degrees(angle),
                            showsDot: false)
                .frame(height: 200)
                .animation(.spring(response: 0.75, dampingFraction: 0.62), value: settled)

            if phase == .enabling {
                Text("Turning on JIT…")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .onAppear { startSpinning() }
    }

    /// Rotation is driven by a long-running linear animation rather than a
    /// `.repeatForever` on a boolean: a boolean can only flip once, so
    /// stopping it (on success or failure) would cut the mark mid-turn with
    /// no way to restart. A repeating angle animation is re-triggerable.
    private func startSpinning() {
        guard !reduceMotion else { return }
        isSpinning = true
        angle = 0
        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }

    /// Stop the mark at a whole turn so it does not jump when the fan-out
    /// takes over. The repeating animation is cut by removing it, then a
    /// short linear pass lands exactly on the next boundary.
    private func stopSpinning() {
        guard isSpinning else { return }
        isSpinning = false
        // Snap the model value to the current on-screen angle's boundary.
        let boundary = (angle / 360).rounded(.up) * 360
        angle = boundary
        withAnimation(.linear(duration: 0.001)) {
            angle = boundary
        }
    }

    private func settleAndFinish() async {
        // Both the poll loop and the did-become-active observer can land here
        // in the same second; without this the fan-out would play twice.
        guard !settled else { return }
        stopSpinning()
        settled = true
        try? await Task.sleep(nanoseconds: 900_000_000)
        phase = .finished
        try? await Task.sleep(nanoseconds: 700_000_000)
        onDismiss()
    }

    // MARK: Enabling

    /// Hand the process to StikDebug. It attaches a debugger and sets
    /// CS_DEBUGGED, which is what actually unlocks executable memory.
    ///
    /// The URL carries our own bundle id and pid, plus the UTM debug script
    /// name: on iOS 26+ StikDebug refuses to attach without a script, and
    /// "UTM" is the name under which it ships the right one. The script is
    /// resolved inside StikDebug, so a missing assignment there shows up as
    /// "returned but JIT still off", which the timeout path explains.
    private func handOffToStikDebug() async {
        failureMessage = nil
        phase = .enabling

        guard let url = stikDebugURL else {
            fail(String(localized: "StikDebug is not installed, or its URL scheme is unavailable."))
            return
        }

        await UIApplication.shared.open(url)

        // StikDebug has to be brought to the foreground (and its own setup
        // completed) for the attach to land. Poll the flag rather than
        // trusting the round trip: open() succeeding only means iOS found a
        // handler for the scheme.
        let deadline = Date().addingTimeInterval(Self.handOffTimeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Main.refreshJITAvailability() {
                await settleAndFinish()
                return
            }
        }

        fail(String(localized: "StikDebug did not manage to attach. Make sure LocalDevVPN is connected and StikDebug has this iPhone's pairing file, then try again."),
             showFallback: true)
    }

    /// StikDebug registers `stikjit://`; `stikdebug://` is kept as an alias
    /// because some guides and older builds use it. We prefer the documented
    /// one and fall back to the other.
    private var stikDebugURL: URL? {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.utmapp.UTM"
        let pid = ProcessInfo.processInfo.processIdentifier
        var components = URLComponents()
        components.scheme = "stikjit"
        components.host = "enable-jit"
        components.queryItems = [
            URLQueryItem(name: "bundle-id", value: bundleID),
            URLQueryItem(name: "pid", value: "\(pid)"),
            URLQueryItem(name: "script-name", value: "UTM"),
        ]
        return components.url
    }

    private func openLocalDevVPN() {
        // LocalDevVPN publishes no URL scheme, so the best we can do is open
        // its App Store listing or leave the user to the Home Screen. Falling
        // back to Settings keeps the button from being a dead end.
        if let url = URL(string: "localdevvpn://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openStikDebug() {
        guard let url = stikDebugURL else { return }
        UIApplication.shared.open(url)
    }

    private func fail(_ message: String, showFallback: Bool = false) {
        isSpinning = false
        angle = 0
        settled = false
        withAnimation(.easeInOut(duration: 0.25)) {
            failureMessage = message
            showsFallbackSteps = showFallback
            phase = .instructions
        }
    }

    /// How long to wait for StikDebug to attach before offering the manual
    /// route. Attaching is usually instant, but the first run also mounts the
    /// Developer Disk Image, which takes seconds.
    private static let handOffTimeout: TimeInterval = 60
}

/// Holds the guide's presentation state above the app's root so both entry
/// points (launch, new virtual machine) drive the same instance.
@MainActor final class JITGuideCoordinator: ObservableObject {
    @Published var isPresented = false
    var reason: JITGuideReason = .launch

    /// Only meaningful on a build that compiles JIT support in; HV-only and
    /// macOS builds never present the guide.
    ///
    /// Re-reads the live flag rather than caching the launch-time answer: a
    /// user who enabled JIT from StikDebug mid-session must not be nagged
    /// again when they tap "new virtual machine".
    static var isNeeded: Bool {
        #if os(iOS) && WITH_JIT
        return !Main.refreshJITAvailability()
        #else
        return false
        #endif
    }

    func present(reason: JITGuideReason) {
        guard Self.isNeeded else { return }
        self.reason = reason
        isPresented = true
    }
}
