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
    let key: String
    let options: [(title: String, value: Int)]

    @AppStorage private var rawValue: Int

    init(title: LocalizedStringKey,
         key: String,
         default defaultValue: Int,
         options: [(title: String, value: Int)]) {
        self.title = title
        self.key = key
        self.options = options
        self._rawValue = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        Picker(title, selection: $rawValue) {
            ForEach(options, id: \.value) { option in
                Text(option.title).tag(option.value)
            }
        }
        .pickerStyle(.menu)
    }
}

/// A `PSSliderSpecifier` rendered as a labelled slider. The value is stored as
/// an `Int` because the consumers (`VMCursor.m`, gamepad handling) read these
/// keys with `integerForKey:`.
private struct SettingsSliderRow: View {
    let title: LocalizedStringKey
    let key: String
    let range: ClosedRange<Int>
    let defaultValue: Int
    var showsValue = true

    @AppStorage private var value: Int

    init(title: LocalizedStringKey,
         key: String,
         range: ClosedRange<Int>,
         defaultValue: Int,
         showsValue: Bool = true) {
        self.title = title
        self.key = key
        self.range = range
        self.defaultValue = defaultValue
        self.showsValue = showsValue
        self._value = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                if showsValue {
                    Spacer()
                    Text("\(value)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            // `Slider` needs a `Double` binding; the stored value stays an Int
            // so the ObjC consumers keep reading it with `integerForKey:`.
            Slider(value: Binding(
                get: { Double($value.wrappedValue) },
                set: { $value.wrappedValue = Int($0.rounded()) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        }
    }
}

// MARK: - Core sections (always visible)

/// The four groups shown in the compact layout: the ones most people touch.
struct SettingsCoreSections: View {
    var body: some View {
        SettingsGroup(title: "Background") {
            SettingsToggleRow(title: "Continue running VM in the background",
                              key: "RunInBackground",
                              defaultValue: false)
            SettingsToggleRow(title: "Auto save on background",
                              key: "AutosaveBackground",
                              defaultValue: true)
            SettingsToggleRow(title: "Auto save on low memory",
                              key: "AutosaveLowMemory",
                              defaultValue: true)
        }

        SettingsGroup(title: "Idle") {
            SettingsToggleRow(title: "Disable screen dimming when idle",
                              key: "DisableIdleTimer",
                              defaultValue: false)
            SettingsToggleRow(title: "Do not save VM screenshot to disk",
                              key: "NoSaveScreenshot",
                              defaultValue: false)
        }

        SettingsGroup(title: "Storage") {
            SettingsSelectableRow(title: "Cache",
                                  systemImage: "internaldrive",
                                  pane: .cache)
        }

        SettingsGroup(title: "About") {
            SettingsInfoRow(title: "Version", value: SettingsInfo.version)
            SettingsInfoRow(title: "Build", value: SettingsInfo.build)
            SettingsSelectableRow(title: "License",
                                  systemImage: "doc.text",
                                  pane: .license)
        }
    }
}

// MARK: - Advanced sections (behind the toggle)

/// The remaining groups from the original plist, revealed by the "advanced"
/// toggle.
struct SettingsAdvancedSections: View {
    var body: some View {
        SettingsGroup(title: "Devices") {
            SettingsToggleRow(title: "Do not show prompt when USB device is plugged in",
                              key: "NoUsbPrompt",
                              defaultValue: false)
            SettingsToggleRow(title: "Prefer device to external microphone",
                              key: "PreferDeviceMicrophone",
                              defaultValue: false)
        }

        SettingsGroup(title: "Graphics") {
            SettingsPickerRow(title: "Renderer Backend",
                              key: "QEMURendererBackend",
                              default: 0,
                              options: [("Default", 0), ("ANGLE (OpenGL)", 1), ("ANGLE (Metal)", 2)])
            SettingsPickerRow(title: "Vulkan Driver",
                              key: "QEMUVulkanDriver",
                              default: 0,
                              options: [("Default", 0), ("Disabled", 1), ("MoltenVK", 2), ("KosmicKrisp", 3)])
            SettingsPickerRow(title: "DirectX Driver",
                              key: "QEMUDirectXDriver",
                              default: 0,
                              options: [("Default", 0), ("Disabled", 1), ("DXMT", 2)])
            SettingsPickerRow(title: "FPS Limit",
                              key: "QEMURendererFPSLimit",
                              default: 0,
                              options: [("None", 0), ("15", 15), ("30", 30), ("45", 45),
                                        ("60", 60), ("75", 75), ("90", 90), ("105", 105), ("120", 120)])
        }

        SettingsGroup(title: "Gestures") {
            SettingsPickerRow(title: "Long Press",
                              key: "GestureLongPress",
                              default: 1,
                              options: [("Disabled", 0), ("Click & Hold", 1),
                                        ("Right Click", 2), ("Middle Click", 5)])
            SettingsPickerRow(title: "Two Finger Tap",
                              key: "GestureTwoTap",
                              default: 2,
                              options: [("Disabled", 0), ("Right Click", 2), ("Middle Click", 5)])
            SettingsPickerRow(title: "Two Finger Pan",
                              key: "GestureTwoPan",
                              default: 3,
                              options: [("Disabled", 0), ("Move Screen", 3), ("Click & Hold", 1),
                                        ("Mouse Wheel", 4), ("Right Click & Hold", 6), ("Middle Click & Hold", 7)])
            SettingsPickerRow(title: "Two Finger Swipe",
                              key: "GestureTwoScroll",
                              default: 0,
                              options: [("Disabled", 0), ("Mouse Wheel (per swipe)", 4)])
            SettingsPickerRow(title: "Three Finger Pan",
                              key: "GestureThreePan",
                              default: 0,
                              options: [("Disabled", 0), ("Move Screen", 3), ("Click & Hold", 1),
                                        ("Mouse Wheel", 4), ("Right Click & Hold", 6), ("Middle Click & Hold", 7)])
        }

        SettingsGroup(title: "Cursor") {
            SettingsPickerRow(title: "Touch Input",
                              key: "MouseTouchType",
                              default: 0,
                              options: [("Drag cursor", 0), ("Touch mode (always show cursor)", 1),
                                        ("Touch mode (try hiding cursor)", 2), ("Touch mode (drag to scroll)", 3)])
            SettingsPickerRow(title: "Apple Pencil Input",
                              key: "MousePencilType",
                              default: 2,
                              options: [("Drag cursor", 0), ("Tablet mode (always show cursor)", 1),
                                        ("Tablet mode (try hiding cursor)", 2)])
            SettingsSliderRow(title: "Drag Speed",
                              key: "DragCursorSpeed",
                              range: 1...100,
                              defaultValue: 100)        }

        SettingsGroup(title: "Cursor - Scroll Wheel") {
            SettingsToggleRow(title: "Invert Scroll",
                              key: "InvertScroll",
                              defaultValue: false)
        }

        SettingsGroup(title: "Gamepad") {
            SettingsGamepadRows()
            SettingsSliderRow(title: "Cursor Speed",
                              key: "GCThumbstickRightSpeed",
                              range: 1...100,
                              defaultValue: 10)
        }

        SettingsGroup(title: "JitStreamer") {
            SettingsToggleRow(title: "Enable JitStreamer Attach",
                              key: "JitStreamerAttach",
                              defaultValue: false)
            SettingsSelectableRow(title: "JitStreamer IP Address",
                                  systemImage: "network",
                                  pane: .jitStreamer)
        }
    }
}

// MARK: - Simple reusable rows

/// A `PSToggleSwitchSpecifier` row bound to a `UserDefaults` key.
private struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    let key: String
    let defaultValue: Bool

    @AppStorage private var value: Bool

    init(title: LocalizedStringKey, key: String, defaultValue: Bool) {
        self.title = title
        self.key = key
        self.defaultValue = defaultValue
        self._value = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        Toggle(title, isOn: $value)
    }
}

/// A read-only row showing a title and its value (Version / Build).
private struct SettingsInfoRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

/// A row that opens a detail pane. Uses `NavigationLink(value:)` so the
/// surrounding `NavigationSplitView` shows the pane in the detail column on
/// wide layouts and pushes it on narrow ones (the split view collapses
/// automatically). The `.navigationDestination(for:)` that resolves the value
/// lives on the sidebar's `List`.
private struct SettingsSelectableRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let pane: SettingsPane

    var body: some View {
        NavigationLink(value: pane) {
            Label(title, systemImage: systemImage)
        }
    }
}
