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
            WizardCardGroup("Information") {
                WizardRow("Name",
                          subtitle: "Shown in the sidebar",
                          systemImage: "textformat") {
                    TextField("Name", text: $wizardState.name.bound)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                }
                #if os(macOS)
                WizardRowDivider()
                WizardToggleRow("Open VM Settings",
                                subtitle: "Open the settings panel after creation",
                                systemImage: "gearshape",
                                isOn: $wizardState.isOpenSettingsAfterCreation)
                    .disabled(wizardState.isPendingIPSWDownload)
                #endif
            }

            WizardCardGroup("System") {
                summaryValue("Engine",
                             systemImage: "cpu",
                             value: wizardState.useAppleVirtualization
                             ? NSLocalizedString("Apple Virtualization", comment: "VMWizardSummaryView")
                             : "QEMU")
                WizardRowDivider()
                summaryValue("Operating System",
                             systemImage: "desktopcomputer",
                             value: wizardState.operatingSystem.name.localizedString)
                if !wizardState.useAppleVirtualization {
                    WizardRowDivider()
                    summaryValue("Architecture",
                                 systemImage: "square.stack.3d.up",
                                 value: wizardState.systemArchitecture.prettyValue)
                    WizardRowDivider()
                    summaryValue("System",
                                 systemImage: "pc",
                                 value: wizardState.systemTarget.prettyValue)
                }
                WizardRowDivider()
                summaryValue("RAM",
                             systemImage: "memorychip",
                             value: memoryDescription)
                WizardRowDivider()
                summaryValue("CPU",
                             systemImage: "cpu",
                             value: coreDescription)
                WizardRowDivider()
                summaryValue("Storage",
                             systemImage: "internaldrive",
                             value: storageDescription)
            }

            if hasBootDetails {
                WizardCardGroup("Boot") {
                    bootRows
                }
            }

            WizardCardGroup("Sharing") {
                summaryValue("Share Directory",
                             systemImage: "folder",
                             value: wizardState.sharingDirectoryURL != nil
                             ? NSLocalizedString("Enabled", comment: "VMWizardSummaryView")
                             : NSLocalizedString("Disabled", comment: "VMWizardSummaryView"))
                if let sharingPath = wizardState.sharingDirectoryURL?.path {
                    WizardRowDivider()
                    summaryValue("Directory",
                                 systemImage: "folder.badge.gearshape",
                                 value: sharingPath)
                    if !wizardState.useAppleVirtualization {
                        WizardRowDivider()
                        summaryValue("Read Only",
                                     systemImage: "lock",
                                     value: wizardState.sharingReadOnly
                                     ? NSLocalizedString("Yes", comment: "VMWizardSummaryView")
                                     : NSLocalizedString("No", comment: "VMWizardSummaryView"))
                    }
                }
            }
        }
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
            summaryValue("Boot Image",
                         systemImage: "opticaldisc",
                         value: bootImageURL.path)
        }
        if wizardState.operatingSystem == .macOS {
            #if os(macOS) && arch(arm64)
            if wizardState.bootImageURL != nil {
                WizardRowDivider()
            }
            summaryValue("IPSW",
                         systemImage: "arrow.down.circle",
                         value: wizardState.macRecoveryIpswURL?.path ?? "")
            #endif
        } else if wizardState.operatingSystem == .Linux && wizardState.bootDevice == .kernel {
            if wizardState.bootImageURL != nil {
                WizardRowDivider()
            }
            if let kernel = wizardState.linuxKernelURL?.path {
                summaryValue("Kernel", systemImage: "terminal", value: kernel)
            }
            if let ramdisk = wizardState.linuxInitialRamdiskURL?.path {
                WizardRowDivider()
                summaryValue("Initial Ramdisk", systemImage: "memorychip", value: ramdisk)
            }
            if let root = wizardState.linuxRootImageURL?.path {
                WizardRowDivider()
                summaryValue("Root Image", systemImage: "internaldrive", value: root)
            }
            if !wizardState.linuxBootArguments.isEmpty {
                WizardRowDivider()
                summaryValue("Boot Arguments", systemImage: "text.alignleft",
                             value: wizardState.linuxBootArguments)
            }
        }
    }

    /// A read-only row: label on the left, emphasised value on the right.
    /// Long values (paths, arguments) wrap rather than truncate.
    @ViewBuilder
    private func summaryValue(_ title: LocalizedStringKey,
                              systemImage: String,
                              value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundColor(.accentColor)
                .frame(width: 26)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

struct VMWizardSummaryView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardSummaryView(wizardState: wizardState)
    }
}
