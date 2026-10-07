//
// Copyright © 2021 osy. All rights reserved.
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

/// Operating-system picker.
///
/// Each OS is a full-width card carrying its brand mark, name and a one-line
/// hint about what it is for, instead of the previous 30pt thumbnail next to a
/// plain title. The availability logic is unchanged: which entries appear still
/// depends on the engine chosen on the previous page.
struct VMWizardOSView: View {
    @ObservedObject var wizardState: VMWizardState

    var body: some View {
        VMWizardContent("Operating System", page: .operatingSystem) {
            WizardCardGroup("Preconfigured") {
                #if os(macOS) && arch(arm64)
                if wizardState.useVirtualization {
                    osCard(
                           title: "macOS 12+",
                           subtitle: "Apple Virtualization, arm64",
                           logo: "Logo-macOS") {
                        wizardState.operatingSystem = .macOS
                        wizardState.useAppleVirtualization = true
                        wizardState.isGuestToolsInstallRequested = false
                        wizardState.next()
                    }
                    WizardRowDivider()
                }
                #endif

                if !wizardState.useVirtualization {
                    osCard(
                           title: "Classic Mac OS",
                           subtitle: "68K / PowerPC emulation",
                           logo: "Logo-macOS") {
                        wizardState.operatingSystem = .ClassicMacOS
                        wizardState.useAppleVirtualization = false
                        wizardState.isGuestToolsInstallRequested = false
                        wizardState.next()
                    }
                    WizardRowDivider()
                }

                osCard(
                       title: "Windows",
                       subtitle: "Windows 10 / 11 and earlier",
                       logo: "Logo-Windows") {
                    wizardState.operatingSystem = .Windows
                    wizardState.useAppleVirtualization = false
                    wizardState.isGuestToolsInstallRequested = true
                    wizardState.next()
                }

                WizardRowDivider()

                osCard(
                       title: "Linux",
                       subtitle: "Ubuntu, Debian and others",
                       logo: "Logo-Linux") {
                    wizardState.operatingSystem = .Linux
                    wizardState.isGuestToolsInstallRequested = false
                    wizardState.next()
                }
            }

            WizardCardGroup("Custom") {
                WizardCard(title: "Other",
                           subtitle: "Any other operating system, configured manually") {
                    wizardState.operatingSystem = .Other
                    wizardState.useAppleVirtualization = false
                    wizardState.isGuestToolsInstallRequested = false
                    wizardState.next()
                } icon: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    /// Builds an OS card backed by a bundled brand image, falling back to a
    /// generic symbol when the asset is missing so the row never renders blank.
    @ViewBuilder
    private func osCard(title: LocalizedStringKey,
                        subtitle: LocalizedStringKey,
                        logo: String,
                        action: @escaping () -> Void) -> some View {
        WizardCard(title: title, subtitle: subtitle, action: action) {
            brandImage(logo)
        }
    }

    /// The bundled brand mark for an OS, or a neutral symbol if it is absent.
    @ViewBuilder
    private func brandImage(_ name: String) -> some View {
        #if os(macOS)
        if let image = NSImage(named: name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
        } else {
            fallbackIcon
        }
        #else
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
        } else {
            fallbackIcon
        }
        #endif
    }

    private var fallbackIcon: some View {
        Image(systemName: "desktopcomputer")
            .font(.system(size: 24))
            .foregroundColor(.accentColor)
            .frame(width: 34, height: 34)
    }
}

struct VMWizardOSView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardOSView(wizardState: wizardState)
    }
}
