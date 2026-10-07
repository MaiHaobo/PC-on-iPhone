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

struct VMWizardDrivesView: View {
    @ObservedObject var wizardState: VMWizardState

    /// Quick-pick sizes, so the common choices do not require typing a number.
    private let presets: [Int] = [8, 16, 32, 64, 128, 256]

    private var storageDescription: String {
        let bytes = Int64(wizardState.storageSizeGib) * Int64(wizardState.bytesInGib)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    var body: some View {
        VMWizardContent("Storage", page: .drives) {
            WizardCardGroup("Size",
                            footer: "Specify the size of the drive where data will be stored into. The disk image expands as it fills, so the full size is not used immediately.") {
                WizardRow("Disk Size",
                          subtitle: storageDescription,
                          systemImage: "internaldrive") {
                    HStack(spacing: 6) {
                        NumberTextField("", number: $wizardState.storageSizeGib)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 64)
                            .multilineTextAlignment(.trailing)
                        Text("GiB")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            WizardCardGroup("Common Sizes") {
                // A stock segmented control rather than a grid of hand-drawn
                // chips: the system already renders this affordance, and using
                // it keeps the wizard visually identical to Settings.
                Picker("Preset", selection: $wizardState.storageSizeGib) {
                    ForEach(presets, id: \.self) { size in
                        Text("\(size) GiB").tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, WizardMetrics.rowInset)
                .padding(.vertical, 12)
            }
        }
        .wizardBottomAction {
            WizardPrimaryButton("Continue", systemImage: "chevron.right",
                                isBusy: wizardState.isBusy) {
                wizardState.next()
            }
        }
    }
}

struct VMWizardDrivesView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardDrivesView(wizardState: wizardState)
    }
}
