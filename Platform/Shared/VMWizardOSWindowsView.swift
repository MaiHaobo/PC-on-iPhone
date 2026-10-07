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

struct VMWizardOSWindowsView: View {
    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false

    var body: some View {
        VMWizardContent("Windows", page: .windowsBoot) {
            #if !WITH_QEMU_TCI
            WizardCardGroup("Image File Type",
                            footer: "Modern Windows requires UEFI and a TPM, which the wizard enables for you.") {
                WizardToggleRow("Install Windows 10 or higher",
                                subtitle: "Turn off for Windows 7 and earlier",
                                systemImage: "square.grid.2x2",
                                isOn: $wizardState.isWindows10OrHigher)
                    .onChange(of: wizardState.isWindows10OrHigher) { newValue in
                        if newValue {
                            wizardState.systemBootUefi = true
                            wizardState.systemBootTpm = true
                            wizardState.isGuestToolsInstallRequested = true
                        } else {
                            wizardState.systemBootUefi = false
                            wizardState.systemBootTpm = false
                            wizardState.isGuestToolsInstallRequested = false
                        }
                    }
                    .disabled(wizardState.legacyHardware)

                if wizardState.isWindows10OrHigher {
                    WizardRowDivider()
                    linkRow("Windows Install Guide",
                            systemImage: "book",
                            destination: "https://docs.getutm.app/guides/windows/")
                    #if os(macOS)
                    WizardRowDivider()
                    crystalFetchRow
                    #endif
                }
            }
            #endif

            WizardCardGroup(imageSectionTitle) {
                if wizardState.legacyHardware {
                    WizardRow("Boot Device",
                              subtitle: "Where the guest boots from",
                              systemImage: "opticaldisc") {
                        Picker("Boot Device", selection: $wizardState.bootDevice) {
                            Text("CD/DVD Image").tag(VMBootDevice.cd)
                            Text("Floppy Image").tag(VMBootDevice.floppy)
                        }
                        .labelsHidden()
                    }
                    .onAppear {
                        if !wizardState.legacyHardware && wizardState.bootDevice == .floppy {
                            wizardState.bootDevice = .cd
                        }
                    }
                    WizardRowDivider()
                }

                FileBrowseField(url: $wizardState.bootImageURL,
                                isFileImporterPresented: $isFileImporterPresented,
                                hasClearButton: false)

                if wizardState.isBusy {
                    WizardRowDivider()
                    HStack {
                        Spacer()
                        Spinner(size: .large)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                }
            }

            if !wizardState.isWindows10OrHigher && !wizardState.legacyHardware {
                WizardCardGroup("Boot Options",
                                footer: "Some older systems do not support UEFI boot, such as Windows 7 and below.") {
                    WizardToggleRow("UEFI Boot",
                                    subtitle: "Required by most modern systems",
                                    systemImage: "power",
                                    isOn: $wizardState.systemBootUefi)
                        .onChange(of: wizardState.systemBootUefi) { newValue in
                            if !newValue {
                                wizardState.systemBootTpm = false
                            }
                        }
                    WizardRowDivider()
                    WizardToggleRow("Secure Boot with TPM 2.0",
                                    subtitle: "Requires UEFI boot",
                                    systemImage: "lock.shield",
                                    isOn: $wizardState.systemBootTpm)
                        .disabled(!wizardState.systemBootUefi)
                }
            }

            // Disabled for non-Windows 10 installs due to autounattend version
            if wizardState.isWindows10OrHigher {
                WizardCardGroup("Guest Support",
                                footer: "Download and mount the guest support package for Windows. This is required for some features including dynamic resolution and clipboard sharing.") {
                    WizardToggleRow("Install drivers and SPICE tools",
                                    subtitle: "Recommended for the best experience",
                                    systemImage: "wrench.adjustable",
                                    isOn: $wizardState.isGuestToolsInstallRequested)
                }
            }
        }
        .wizardBottomAction {
            WizardPrimaryButton("Continue", systemImage: "chevron.right",
                                isBusy: wizardState.isBusy) {
                wizardState.next()
            }
        }
        .fileImporter(isPresented: $isFileImporterPresented,
                      allowedContentTypes: [.data],
                      onCompletion: processImage)
        .onAppear {
            wizardState.bootDevice = .cd
            #if WITH_QEMU_TCI
            wizardState.legacyHardware = true
            #endif
            if wizardState.legacyHardware {
                wizardState.isWindows10OrHigher = false
                wizardState.isGuestToolsInstallRequested = false
                wizardState.systemBootUefi = false
                wizardState.systemBootTpm = false
            }
        }
    }

    private var imageSectionTitle: LocalizedStringKey {
        if wizardState.bootDevice == .cd {
            return "Boot ISO Image"
        } else {
            return "Boot IMG Image"
        }
    }

    @ViewBuilder
    private func linkRow(_ title: LocalizedStringKey,
                         systemImage: String,
                         destination: String) -> some View {
        Link(destination: URL(string: destination)!) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17))
                    .foregroundColor(.accentColor)
                    .frame(width: 26)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    #if os(macOS)
    private var crystalFetchRow: some View {
        Button {
            let downloadCrystalFetch = URL(string: "https://mac.getutm.app/crystalfetch/")!
            if let crystalFetch = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "llc.turing.CrystalFetch") {
                NSWorkspace.shared.openApplication(at: crystalFetch, configuration: .init()) { _, error in
                    if error != nil {
                        NSWorkspace.shared.open(downloadCrystalFetch)
                    }
                }
            } else {
                NSWorkspace.shared.open(downloadCrystalFetch)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 17))
                    .foregroundColor(.accentColor)
                    .frame(width: 26)
                Text("Fetch latest Windows installer…")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif

    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            await MainActor.run {
                wizardState.bootImageURL = url
            }
        }
    }
}

struct VMWizardOSWindowsView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardOSWindowsView(wizardState: wizardState)
    }
}
