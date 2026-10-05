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
            Text(title)
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
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
