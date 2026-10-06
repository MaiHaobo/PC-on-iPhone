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
        // The iOS deployment target is 15.0, so the split view (iOS 16+) needs an
        // availability branch. On iOS 15 a `NavigationView` provides the same
        // two-column-on-wide / push-on-narrow behaviour with the older API.
        if #available(iOS 16, *) {
            NavigationSplitView {
                SettingsSidebar(isPresentedAsSheet: isPresentedAsSheet,
                                showAdvanced: $showAdvanced,
                                onClose: { presentationMode.wrappedValue.dismiss() })
            } detail: {
                SettingsDetailPlaceholder()
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            // Mirror the VM list's iOS 15 fallback: two children in a
            // `NavigationView` give the default double-column behaviour, and
            // destination-based `NavigationLink`s push within it.
            NavigationView {
                SettingsSidebarLegacy(isPresentedAsSheet: isPresentedAsSheet,
                                      showAdvanced: $showAdvanced,
                                      onClose: { presentationMode.wrappedValue.dismiss() })
                SettingsDetailPlaceholder()
            }
        }
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

/// The shared list content: the compact/full toggle followed by every group.
/// Both sidebar variants (iOS 16 split view and iOS 15 navigation view) render
/// this, so the two never drift apart.
private struct SettingsListContent: View {
    @Binding var showAdvanced: Bool
    /// `true` for the iOS 16 sidebar (value-based `NavigationLink`), `false` for
    /// the iOS 15 fallback (destination-based `NavigationLink`).
    let usesValueNavigation: Bool

    var body: some View {
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

        SettingsCoreSections(usesValueNavigation: usesValueNavigation)

        if showAdvanced {
            SettingsAdvancedSections(usesValueNavigation: usesValueNavigation)
        }
    }
}

/// iOS 16+ sidebar: a `NavigationLink(value:)` fills the detail column, and the
/// split view collapses to a push on narrow layouts.
@available(iOS 16, *)
private struct SettingsSidebar: View {
    let isPresentedAsSheet: Bool
    @Binding var showAdvanced: Bool
    let onClose: () -> Void

    var body: some View {
        List {
            SettingsListContent(showAdvanced: $showAdvanced, usesValueNavigation: true)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SettingsPane.self) { pane in
            SettingsDetailDestination(pane: pane)
        }
        .toolbar {
            if isPresentedAsSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}

/// iOS 15 fallback sidebar: rows are `NavigationLink(destination:)` so tapping
/// one pushes the pane onto the navigation stack.
private struct SettingsSidebarLegacy: View {
    let isPresentedAsSheet: Bool
    @Binding var showAdvanced: Bool
    let onClose: () -> Void

    var body: some View {
        List {
            SettingsListContent(showAdvanced: $showAdvanced, usesValueNavigation: false)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        // The condition lives inside the ToolbarItem: the toolbar builder's
        // `buildIf` is iOS 16+, so an `if` around the ToolbarItem itself would
        // not compile against the iOS 15 deployment target.
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isPresentedAsSheet {
                    Button(action: onClose) {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }
}

// MARK: - Detail column

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
