//
// Copyright © 2022 osy. All rights reserved.
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

/// Settings screen, rebuilt as a native SwiftUI `NavigationSplitView` that
/// mirrors the system Settings app.
///
/// Earlier revisions embedded `IASKAppSettingsViewController` and hijacked its
/// navigation stack to fake a split view, which broke in four ways (blank
/// second-level panes in portrait, a stray Done button, missing rounded
/// corners, and pushes landing in the wrong column). This version drops
/// InAppSettingsKit entirely: the list is a plain SwiftUI `List` in the system
/// `.insetGrouped` style, so the corners, spacing and navigation behaviour are
/// all Apple's defaults.
///
/// Navigation uses the canonical `NavigationSplitView` pattern: a
/// `NavigationLink(value:)` in the sidebar plus a matching
/// `.navigationDestination(for:)`. On wide layouts (iPad, iPhone landscape) the
/// destination appears in the detail column; on narrow layouts (iPhone
/// portrait) the split view collapses and the destination is pushed on top of
/// the list — one structure, correct in both orientations, with no manual size
/// class juggling.
///
/// The "advanced" toggle at the top switches between a compact set of the most
/// used groups and the full set. Every row reads and writes the same
/// `UserDefaults` keys the old `Settings.bundle/Root.plist` used, so an
/// over-the-top install keeps the user's existing preferences.
struct UTMSettingsView: View {
    /// `true` when shown as a modal sheet (has a "Close" button),
    /// `false` when hosted as the root of a tab (nothing to close).
    var isPresentedAsSheet: Bool = true

    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>

    /// Drives the compact vs. full list. Persisted so the choice survives
    /// relaunches.
    @AppStorage("ShowAdvancedSettings") private var showAdvanced = false

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(isPresentedAsSheet: isPresentedAsSheet,
                            showAdvanced: $showAdvanced,
                            onClose: { presentationMode.wrappedValue.dismiss() })
        } detail: {
            SettingsDetailPlaceholder()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Panes

/// Destinations reachable from the settings list. Everything that used to be a
/// child pane in `Root.plist` is one of these.
enum SettingsPane: Hashable {
    case cache
    case license
    case jitStreamer
}

// MARK: - Sidebar (the list)

/// The settings list itself: a native grouped `List` with the compact/full
/// toggle at the top. Rows that open a pane are `NavigationLink(value:)`, which
/// fills the detail column on wide layouts and pushes on narrow ones.
private struct SettingsSidebar: View {
    let isPresentedAsSheet: Bool
    @Binding var showAdvanced: Bool
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                Toggle(isOn: $showAdvanced) {
                    Label {
                        Text("Show Advanced Settings")
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            } footer: {
                Text("Show the full set of options, including graphics, gestures, cursor and gamepad.")
            }

            SettingsCoreSections()

            if showAdvanced {
                SettingsAdvancedSections()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SettingsPane.self) { pane in
            SettingsDetailColumn(pane: pane)
        }
        .toolbar {
            if isPresentedAsSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}

// MARK: - Detail column

/// The pane shown for a given `SettingsPane`.
private struct SettingsDetailColumn: View {
    let pane: SettingsPane

    var body: some View {
        switch pane {
        case .cache:
            VMCacheSettingsView()
        case .license:
            SettingsLicenseView()
        case .jitStreamer:
            SettingsJitStreamerView()
        }
    }
}

/// Neutral placeholder shown in the detail column before a row is selected.
private struct SettingsDetailPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Settings")
                .font(.title2.weight(.semibold))
            Text("Select an option from the list to see its details.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

struct UTMSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UTMSettingsView()
    }
}
