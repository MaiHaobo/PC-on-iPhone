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
#if canImport(Virtualization)
import Virtualization
#endif

/// Entry page: choose how the VM will run.
///
/// The two engine choices are the largest, most consequential decision in the
/// wizard — virtualization is dramatically faster but architecturally limited —
/// so they get the full card treatment with the trade-off stated in the
/// subtitle rather than hidden behind a one-word label.
struct VMWizardStartView: View {
    @ObservedObject var wizardState: VMWizardState

    var isVirtualizationSupported: Bool {
        #if os(macOS)
        VZVirtualMachine.isSupported && !processIsTranslated()
        #else
        UTMCapabilities.current.contains(.hasHypervisorSupport)
        #endif
    }

    var isEmulationSupported: Bool {
        #if !WITH_JIT
        true
        #else
        Main.jitAvailable
        #endif
    }

    var body: some View {
        VMWizardContent("Start", page: .start) {
            WizardCardGroup("Custom", footer: engineFooter) {
                WizardCard(
                    title: "Virtualize",
                    subtitle: "Faster, but can only run the native CPU architecture.",
                    isEnabled: isVirtualizationSupported
                ) {
                    wizardState.useVirtualization = true
                    wizardState.next()
                } icon: {
                    Image(systemName: "hare")
                        .font(.system(size: 26))
                        .foregroundColor(.accentColor)
                }

                WizardRowDivider()

                WizardCard(
                    title: "Emulate",
                    subtitle: "Slower, but can run other CPU architectures."
                ) {
                    wizardState.useVirtualization = false
                    wizardState.next()
                } icon: {
                    Image(systemName: "tortoise")
                        .font(.system(size: 26))
                        .foregroundColor(.accentColor)
                }
            }

            WizardCardGroup("Existing") {
                WizardCard(title: "Open…") {
                    NotificationCenter.default.post(name: NSNotification.OpenVirtualMachine,
                                                    object: nil)
                } icon: {
                    Image(systemName: "folder")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }

                WizardRowDivider()

                Link(destination: URL(string: "https://mac.getutm.app/gallery/")!) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                            .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Download prebuilt from UTM Gallery…")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Explains, when relevant, why an engine is unavailable. Empty when both
    /// work, so the card group renders no footer at all.
    private var engineFooter: LocalizedStringKey? {
        if !isEmulationSupported && !isVirtualizationSupported {
            return "Your version of iOS does not support running VMs while unmodified. You must either run UTM while jailbroken or with a remote debugger attached. See https://getutm.app/install/ for more details."
        } else if !isVirtualizationSupported {
            return "Virtualization is not supported on your system."
        } else if !isEmulationSupported {
            return "This build does not emulation."
        }
        return nil
    }

    private func processIsTranslated() -> Bool {
        let key = "sysctl.proc_translated"
        var ret = Int32(0)
        var size: Int = 0
        sysctlbyname(key, nil, &size, nil, 0)
        let result = sysctlbyname(key, &ret, &size, nil, 0)
        if result == -1 {
            return false
        }
        return ret != 0
    }
}

struct VMWizardStartView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardStartView(wizardState: wizardState)
    }
}
