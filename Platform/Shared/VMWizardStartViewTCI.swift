//
// Copyright © 2024 osy. All rights reserved.
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

/// Entry page for the TCI (no-hypervisor) build, where virtualization is never
/// offered so the engine step is replaced by a single "New Machine" action.
struct VMWizardStartViewTCI: View {
    @ObservedObject var wizardState: VMWizardState

    var body: some View {
        VMWizardContent("Start", page: .start) {
            WizardCardGroup("Custom") {
                WizardCard(
                    title: "New Machine",
                    subtitle: "Create a new emulated machine from scratch."
                ) {
                    wizardState.useVirtualization = false
                    wizardState.next()
                } icon: {
                    Image(systemName: "pc")
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
}

#Preview {
    VMWizardStartViewTCI(wizardState: VMWizardState())
}
