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

// MARK: - Group styling helper

/// Applies the stock grouped sections: a titled card whose rows get the system
/// rounded corners (`List(.insetGrouped)` draws those for us).
private struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            Text(title)
        }
    }
}

/// A `PSMultiValueSpecifier` rendered as a row that opens a menu. The menu
/// picker style shows the current selection at the trailing edge automatically,
/// which is the system Settings look.
private struct SettingsPickerRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: SettingsIconTint
    let key: String
    /// Option labels are `LocalizedStringKey` (not `String`) so the menu items
    /// go through the localisation lookup too — `Text` only localises when it
    /// receives a key, and a plain `String` bypasses the table entirely.
    let options: [(title: LocalizedStringKey, value: Int)]

    @AppStorage private var rawValue: Int

    init(title: LocalizedStringKey,
         systemImage: String,
         tint: SettingsIconTint,
         key: String,
         default defaultValue: Int,
         options: [(title: LocalizedStringKey, value: Int)]) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.key = key
        self.options = options
        self._rawValue = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        // The picker's label is what draws the badge, so the icon rides along
        // inside it. `.menu` keeps the system's trailing-value treatment.
        Picker(selection: $rawValue) {
            ForEach(options, id: \.value) { option in
                Text(option.title).tag(option.value)
            }
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.settingsIcon(tint))
        }
        .pickerStyle(.menu)
    }
}

/// A `PSSliderSpecifier` rendered as a labelled slider. The value is stored as
/// an `Int` because the consumers (`VMCursor.m`, gamepad handling) read these
/// keys with `integerForKey:`.
private struct SettingsSliderRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: SettingsIconTint
    let key: String
    let range: ClosedRange<Int>
    let defaultValue: Int
    var showsValue = true

    @AppStorage private var value: Int

    init(title: LocalizedStringKey,
         systemImage: String,
         tint: SettingsIconTint,
         key: String,
         range: ClosedRange<Int>,
         defaultValue: Int,
         showsValue: Bool = true) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.key = key
        self.range = range
        self.defaultValue = defaultValue
        self.showsValue = showsValue
        self._value = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        // `Slider` needs a `Double` binding; the stored value stays an Int so
        // the ObjC consumers keep reading it with `integerForKey:`. Capturing
        // the projected value in a local first avoids reaching into self from
        // inside the escaping binding closures.
        let intBinding = $value
        let doubleBinding = Binding<Double>(
            get: { Double(intBinding.wrappedValue) },
            set: { intBinding.wrappedValue = Int($0.rounded()) }
        )
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.body)
                    .foregroundStyle(tint.color)
                Text(title)
                if showsValue {
                    Spacer()
                    Text("\(value)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Slider(value: doubleBinding,
                   in: Double(range.lowerBound)...Double(range.upperBound),
                   step: 1)
        }
    }
}

// MARK: - Core sections (always visible)

/// The four groups shown in the compact layout: the ones most people touch.
struct SettingsCoreSections: View {
    let usesValueNavigation: Bool

    var body: some View {
        SettingsGroup(title: "Background") {
            SettingsToggleRow(title: "Continue running VM in the background",
                              systemImage: "arrow.triangle.2.circlepath",
                              tint: .background,
                              key: "RunInBackground",
                              defaultValue: false)
            SettingsToggleRow(title: "Auto save on background",
                              systemImage: "clock.arrow.circlepath",
                              tint: .background,
                              key: "AutosaveBackground",
                              defaultValue: true)
            SettingsToggleRow(title: "Auto save on low memory",
                              systemImage: "memorychip",
                              tint: .background,
                              key: "AutosaveLowMemory",
                              defaultValue: true)
        }

        SettingsGroup(title: "Idle") {
            SettingsToggleRow(title: "Disable screen dimming when idle",
                              systemImage: "sun.max",
                              tint: .idle,
                              key: "DisableIdleTimer",
                              defaultValue: false)
            SettingsToggleRow(title: "Do not save VM screenshot to disk",
                              systemImage: "photo",
                              tint: .idle,
                              key: "NoSaveScreenshot",
                              defaultValue: false)
        }

        SettingsGroup(title: "Storage") {
            SettingsSelectableRow(title: "Cache",
                                  systemImage: "internaldrive",
                                  tint: .storage,
                                  pane: .cache,
                                  usesValueNavigation: usesValueNavigation)
            SettingsSelectableRow(title: "Virtual Machines",
                                  systemImage: "externaldrive",
                                  tint: .storage,
                                  pane: .virtualMachineStorage,
                                  usesValueNavigation: usesValueNavigation)
        }

        SettingsGroup(title: "About") {
            SettingsInfoRow(title: "Version",
                            systemImage: "number",
                            tint: .about,
                            value: SettingsInfo.version)
            SettingsInfoRow(title: "Build",
                            systemImage: "hammer",
                            tint: .about,
                            value: SettingsInfo.build)
            SettingsSelectableRow(title: "License",
                                  systemImage: "doc.text",
                                  tint: .about,
                                  pane: .license,
                                  usesValueNavigation: usesValueNavigation)
        }
    }
}

// MARK: - Advanced sections (behind the toggle)

/// The remaining groups from the original plist, revealed by the "advanced"
/// toggle.
struct SettingsAdvancedSections: View {
    let usesValueNavigation: Bool

    var body: some View {
        SettingsGroup(title: "Devices") {
            SettingsToggleRow(title: "Do not show prompt when USB device is plugged in",
                              systemImage: "cable.connector",
                              tint: .devices,
                              key: "NoUsbPrompt",
                              defaultValue: false)
            SettingsToggleRow(title: "Prefer device to external microphone",
                              systemImage: "mic",
                              tint: .devices,
                              key: "PreferDeviceMicrophone",
                              defaultValue: false)
        }

        SettingsGroup(title: "Graphics") {
            SettingsPickerRow(title: "Renderer Backend",
                              systemImage: "cpu",
                              tint: .graphics,
                              key: "QEMURendererBackend",
                              default: 0,
                              options: [("Default", 0), ("ANGLE (OpenGL)", 1), ("ANGLE (Metal)", 2)])
            SettingsPickerRow(title: "Vulkan Driver",
                              systemImage: "cube",
                              tint: .graphics,
                              key: "QEMUVulkanDriver",
                              default: 0,
                              options: [("Default", 0), ("Disabled", 1), ("MoltenVK", 2), ("KosmicKrisp", 3)])
            SettingsPickerRow(title: "DirectX Driver",
                              systemImage: "gamecontroller",
                              tint: .graphics,
                              key: "QEMUDirectXDriver",
                              default: 0,
                              options: [("Default", 0), ("Disabled", 1), ("DXMT", 2)])
            SettingsPickerRow(title: "FPS Limit",
                              systemImage: "speedometer",
                              tint: .graphics,
                              key: "QEMURendererFPSLimit",
                              default: 0,
                              options: [("None", 0), ("15", 15), ("30", 30), ("45", 45),
                                        ("60", 60), ("75", 75), ("90", 90), ("105", 105), ("120", 120)])
        }

        SettingsGroup(title: "Gestures") {
            SettingsPickerRow(title: "Long Press",
                              systemImage: "hand.tap",
                              tint: .gestures,
                              key: "GestureLongPress",
                              default: 1,
                              options: [("Disabled", 0), ("Click & Hold", 1),
                                        ("Right Click", 2), ("Middle Click", 5)])
            SettingsPickerRow(title: "Two Finger Tap",
                              systemImage: "hand.point.up.left",
                              tint: .gestures,
                              key: "GestureTwoTap",
                              default: 2,
                              options: [("Disabled", 0), ("Right Click", 2), ("Middle Click", 5)])
            SettingsPickerRow(title: "Two Finger Pan",
                              systemImage: "hand.draw",
                              tint: .gestures,
                              key: "GestureTwoPan",
                              default: 3,
                              options: [("Disabled", 0), ("Move Screen", 3), ("Click & Hold", 1),
                                        ("Mouse Wheel", 4), ("Right Click & Hold", 6), ("Middle Click & Hold", 7)])
            SettingsPickerRow(title: "Two Finger Swipe",
                              systemImage: "hand.point.up",
                              tint: .gestures,
                              key: "GestureTwoScroll",
                              default: 0,
                              options: [("Disabled", 0), ("Mouse Wheel (per swipe)", 4)])
            SettingsPickerRow(title: "Three Finger Pan",
                              systemImage: "hand.raised",
                              tint: .gestures,
                              key: "GestureThreePan",
                              default: 0,
                              options: [("Disabled", 0), ("Move Screen", 3), ("Click & Hold", 1),
                                        ("Mouse Wheel", 4), ("Right Click & Hold", 6), ("Middle Click & Hold", 7)])
        }

        SettingsGroup(title: "Cursor") {
            SettingsPickerRow(title: "Touch Input",
                              systemImage: "hand.point.up.left.fill",
                              tint: .cursor,
                              key: "MouseTouchType",
                              default: 0,
                              options: [("Drag cursor", 0), ("Touch mode (always show cursor)", 1),
                                        ("Touch mode (try hiding cursor)", 2), ("Touch mode (drag to scroll)", 3)])
            SettingsPickerRow(title: "Apple Pencil Input",
                              systemImage: "pencil.tip",
                              tint: .cursor,
                              key: "MousePencilType",
                              default: 2,
                              options: [("Drag cursor", 0), ("Tablet mode (always show cursor)", 1),
                                        ("Tablet mode (try hiding cursor)", 2)])
            SettingsSliderRow(title: "Drag Speed",
                              systemImage: "hare",
                              tint: .cursor,
                              key: "DragCursorSpeed",
                              range: 1...100,
                              defaultValue: 100)        }

        SettingsGroup(title: "Cursor - Scroll Wheel") {
            SettingsToggleRow(title: "Invert Scroll",
                              systemImage: "arrow.up.arrow.down",
                              tint: .cursor,
                              key: "InvertScroll",
                              defaultValue: false)
        }

        SettingsGroup(title: "Gamepad") {
            SettingsGamepadRows()
            SettingsSliderRow(title: "Cursor Speed",
                              systemImage: "gauge.with.dots.needle.67percent",
                              tint: .gamepad,
                              key: "GCThumbstickRightSpeed",
                              range: 1...100,
                              defaultValue: 10)
        }

        SettingsGroup(title: "JitStreamer") {
            SettingsToggleRow(title: "Enable JitStreamer Attach",
                              systemImage: "bolt",
                              tint: .network,
                              key: "JitStreamerAttach",
                              defaultValue: false)
            SettingsSelectableRow(title: "JitStreamer IP Address",
                                  systemImage: "network",
                                  tint: .network,
                                  pane: .jitStreamer,
                                  usesValueNavigation: usesValueNavigation)
        }
    }
}

// MARK: - Simple reusable rows

/// A `PSToggleSwitchSpecifier` row bound to a `UserDefaults` key.
private struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: SettingsIconTint
    let key: String
    let defaultValue: Bool

    @AppStorage private var value: Bool

    init(title: LocalizedStringKey,
         systemImage: String,
         tint: SettingsIconTint,
         key: String,
         defaultValue: Bool) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.key = key
        self.defaultValue = defaultValue
        self._value = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        // `Toggle(title, isOn:)` would draw its own text-only label; the
        // label-at-a-time initialiser is what lets a badge sit in front.
        Toggle(isOn: $value) {
            Label(title, systemImage: systemImage)
                .labelStyle(.settingsIcon(tint))
        }
    }
}

/// A read-only row showing a title and its value (Version / Build).
private struct SettingsInfoRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: SettingsIconTint
    let value: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(tint.color)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

/// A row that opens a detail pane.
///
/// On iOS 16+ (`usesValueNavigation`) it is a `NavigationLink(value:)` resolved
/// by the sidebar's `.navigationDestination(for:)`: the surrounding
/// `NavigationSplitView` shows the pane in the detail column on wide layouts and
/// pushes it on narrow ones. On iOS 15 it is a `NavigationLink(destination:)`,
/// which pushes onto the enclosing `NavigationView` stack.
private struct SettingsSelectableRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: SettingsIconTint
    let pane: SettingsPane
    let usesValueNavigation: Bool

    var body: some View {
        if usesValueNavigation {
            if #available(iOS 16, *) {
                NavigationLink(value: pane) {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.settingsIcon(tint))
                }
            } else {
                legacyLink
            }
        } else {
            legacyLink
        }
    }

    private var legacyLink: some View {
        NavigationLink {
            SettingsDetailDestination(pane: pane)
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.settingsIcon(tint))
        }
    }
}

/// Resolves a `SettingsPane` to its view. Shared by the iOS 16
/// `navigationDestination` and the iOS 15 destination-based `NavigationLink`.
struct SettingsDetailDestination: View {
    let pane: SettingsPane

    var body: some View {
        switch pane {
        case .cache:
            VMCacheSettingsView()
        case .virtualMachineStorage:
            VMStorageOverviewView()
        case .license:
            SettingsLicenseView()
        case .jitStreamer:
            SettingsJitStreamerView()
        }
    }
}
