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

/// Bottom tab bar shown on iPhone (and compact width layouts).
///
/// Three tabs: the virtual machine list, a "new VM" action, and settings.
/// Selecting the middle tab does not change the visible page — it presents the
/// new-VM wizard as a sheet and immediately returns to the previous tab, which
/// matches the "＋" behaviour the toolbar used to provide.
///
/// The virtual machine list is pushed into its own navigation stack so that
/// opening a VM takes over the full screen and hides the tab bar.
@available(iOS 16, *)
struct VMMainTabView: View {
    @EnvironmentObject private var data: UTMData

    private enum Tab: Hashable {
        case virtualMachines
        case create
        case settings
    }

    @State private var selection: Tab = .virtualMachines
    /// Remembered so that tapping the "create" tab can bounce back to whatever
    /// page the user was actually on.
    @State private var lastContentTab: Tab = .virtualMachines
    @State private var createSheetPresented = false

    var body: some View {
        TabView(selection: tabSelection) {
            VMNavigationListView()
                .tabItem {
                    Label("Virtual Machines", systemImage: "desktopcomputer")
                }
                .tag(Tab.virtualMachines)

            // Placeholder page: selecting this tab is intercepted and presents
            // the wizard instead, so this content is never actually shown.
            Color.clear
                .tabItem {
                    Label("New", systemImage: "plus.circle")
                }
                .tag(Tab.create)

            #if !WITH_REMOTE
            UTMSettingsView(isPresentedAsSheet: false)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
            #endif
        }
        .sheet(isPresented: $createSheetPresented) {
            VMWizardView()
        }
        .onReceive(NSNotification.OpenVirtualMachine) { _ in
            createSheetPresented = false
        }
    }

    /// Intercepts the "create" tab so it never becomes the selected page.
    private var tabSelection: Binding<Tab> {
        Binding {
            selection
        } set: { newValue in
            if newValue == .create {
                createSheetPresented = true
                data.showNewVMSheet = true
                // Snap back to the last real page so the tab highlight does not
                // get stuck on an empty placeholder.
                selection = lastContentTab
            } else {
                lastContentTab = newValue
                selection = newValue
            }
        }
    }
}
