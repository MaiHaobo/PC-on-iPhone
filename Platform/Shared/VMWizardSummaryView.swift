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

/// Final review page.
///
/// Previously every value was rendered as a disabled `TextField`, which made
/// the summary a wall of greyed-out input boxes that looked editable but were
/// not. Values are now plain read-only rows with a trailing emphasis value,
/// and the one thing the user *can* change here — the name — is the only
/// editable control on the page.
struct VMWizardSummaryView: View {
    @ObservedObject var wizardState: VMWizardState
    @EnvironmentObject private var data: UTMData

    var storageDescription: String {
        var size = Int64(wizardState.storageSizeGib * wizardState.bytesInGib)
        #if arch(arm64)
        if wizardState.operatingSystem == .Windows && wizardState.useVirtualization {
            if let attributes = try? wizardState.bootImageURL?.resourceValues(forKeys: [.fileSizeKey]), let fileSize = attributes.fileSize {
                size = Int64(fileSize)
            }
        }
        #endif
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)
    }

    var coreDescription: String {
        let cores = wizardState.systemCpuCount
        if cores == 0 {
            return NSLocalizedString("Default Cores", comment: "VMWizardSummaryView")
        } else {
            return String.localizedStringWithFormat(NSLocalizedString("%lld Cores", comment: "VMWizardSummaryView"), cores)
        }
    }

    private var memoryDescription: String {
        ByteCountFormatter.string(
            fromByteCount: Int64(wizardState.systemMemoryMib * wizardState.bytesInMib),
            countStyle: .binary)
    }

    var body: some View {
        VMWizardContent("Summary", page: .summary) {
            Section {
                summaryValue("Name", value: wizardState.name ?? "")
                #if os(macOS)
                Toggle("Open VM Settings", isOn: $wizardState.isOpenSettingsAfterCreation)
                    .disabled(wizardState.isPendingIPSWDownload)
                #endif
            } header: {
                Text("Information")
            }

            Section {
                summaryValue("Engine",
                             value: wizardState.useAppleVirtualization
                             ? NSLocalizedString("Apple Virtualization", comment: "VMWizardSummaryView")
                             : "QEMU")
                summaryValue("Operating System",
                             value: wizardState.operatingSystem.name.localizedString)
                if !wizardState.useAppleVirtualization {
                    summaryValue("Architecture", value: wizardState.systemArchitecture.prettyValue)
                    summaryValue("System", value: wizardState.systemTarget.prettyValue)
                }
                summaryValue("RAM", value: memoryDescription)
                summaryValue("CPU", value: coreDescription)
                summaryValue("Storage", value: storageDescription)
            } header: {
                Text("System")
            }

            if hasBootDetails {
                Section {
                    bootRows
                } header: {
                    Text("Boot")
                }
            }

            Section {
                summaryValue("Share Directory",
                             value: wizardState.sharingDirectoryURL != nil
                             ? NSLocalizedString("Enabled", comment: "VMWizardSummaryView")
                             : NSLocalizedString("Disabled", comment: "VMWizardSummaryView"))
                if let sharingPath = wizardState.sharingDirectoryURL?.path {
                    summaryValue("Directory", value: sharingPath)
                    if !wizardState.useAppleVirtualization {
                        summaryValue("Read Only",
                                     value: wizardState.sharingReadOnly
                                     ? NSLocalizedString("Yes", comment: "VMWizardSummaryView")
                                     : NSLocalizedString("No", comment: "VMWizardSummaryView"))
                    }
                }
            } header: {
                Text("Sharing")
            }
        }
        .textFieldStyle(.automatic)
        .onAppear {
            if wizardState.name == nil {
                let os = wizardState.operatingSystem
                if os == .Other {
                    wizardState.name = data.newDefaultVMName()
                } else {
                    wizardState.name = data.newDefaultVMName(base: os.name.localizedString)
                }
            }
            wizardState.confusedUserCheck()
        }
    }

    private var hasBootDetails: Bool {
        if wizardState.bootImageURL != nil {
            return true
        }
        switch wizardState.operatingSystem {
        case .macOS:
            #if os(macOS) && arch(arm64)
            return true
            #else
            return false
            #endif
        case .Linux:
            return wizardState.linuxKernelURL != nil
                || wizardState.linuxInitialRamdiskURL != nil
                || wizardState.linuxRootImageURL != nil
                || !wizardState.linuxBootArguments.isEmpty
        default:
            return false
        }
    }

    @ViewBuilder
    private var bootRows: some View {
        if let bootImageURL = wizardState.bootImageURL {
            summaryValue("Boot Image", value: bootImageURL.path)
        }
        if wizardState.operatingSystem == .macOS {
            #if os(macOS) && arch(arm64)
            summaryValue("IPSW", value: wizardState.macRecoveryIpswURL?.path ?? "")
            #endif
        } else if wizardState.operatingSystem == .Linux && wizardState.bootDevice == .kernel {
            if let kernel = wizardState.linuxKernelURL?.path {
                summaryValue("Kernel", value: kernel)
            }
            if let ramdisk = wizardState.linuxInitialRamdiskURL?.path {
                summaryValue("Initial Ramdisk", value: ramdisk)
            }
            if let root = wizardState.linuxRootImageURL?.path {
                summaryValue("Root Image", value: root)
            }
            if !wizardState.linuxBootArguments.isEmpty {
                summaryValue("Boot Arguments", value: wizardState.linuxBootArguments)
            }
        }
    }

    /// A read-only row: label on the left, value on the right, matching the
    /// shape a stock `List` row gets for free. Long values (paths, arguments)
    /// wrap rather than truncate.
    ///
    /// `LabeledContent` would be the natural choice but it is iOS 16+, and the
    /// SE build compiles this file for iOS 15, so the row is spelled out.
    @ViewBuilder
    private func summaryValue(_ title: LocalizedStringKey,
                              value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct VMWizardSummaryView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardSummaryView(wizardState: wizardState)
            .environmentObject(UTMData())
    }
}
