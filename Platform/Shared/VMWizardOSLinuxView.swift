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

struct VMWizardOSLinuxView: View {
    private enum SelectImage {
        case kernel
        case initialRamdisk
        case rootImage
        case bootImage
    }

    @ObservedObject var wizardState: VMWizardState
    @State private var isFileImporterPresented: Bool = false
    @State private var selectImage: SelectImage = .kernel

    private var hasVenturaFeatures: Bool {
        if #available(macOS 13, *) {
            return true
        } else {
            return false
        }
    }

    var body: some View {
        VMWizardContent("Linux", page: .linuxBoot) {
            #if os(macOS)
            if wizardState.useVirtualization {
                WizardCardGroup("Virtualization Engine",
                                footer: "Apple Virtualization is experimental and only for advanced use cases. Leave unchecked to use QEMU, which is recommended.") {
                    WizardToggleRow("Use Apple Virtualization",
                                    subtitle: "Experimental, advanced use cases only",
                                    systemImage: "cpu",
                                    isOn: $wizardState.useAppleVirtualization)
                }
            }
            #endif

            WizardCardGroup("Boot Image Type") {
                WizardRow("Boot Method",
                          subtitle: "How the installer or system is loaded",
                          systemImage: "opticaldisc") {
                    Picker("Boot Image Type", selection: $wizardState.bootDevice) {
                        Text("Boot from kernel image").tag(VMBootDevice.kernel)
                        if !wizardState.useAppleVirtualization || hasVenturaFeatures {
                            Text("Boot from ISO image").tag(VMBootDevice.cd)
                            Text("Import existing drive").tag(VMBootDevice.drive)
                        }
                    }
                    .labelsHidden()
                }
                .onAppear {
                    if ![.kernel, .cd, .drive].contains(wizardState.bootDevice) {
                        wizardState.bootDevice = .cd
                    }
                }

                if wizardState.bootDevice != .kernel {
                    WizardRowDivider()
                    Link(destination: URL(string: wizardState.useAppleVirtualization
                                          ? "https://docs.getutm.app/guides/debian/"
                                          : "https://docs.getutm.app/guides/ubuntu/")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "book")
                                .font(.system(size: 17))
                                .foregroundColor(.accentColor)
                                .frame(width: 26)
                            Text(wizardState.useAppleVirtualization
                                 ? "Debian Install Guide"
                                 : "Ubuntu Install Guide")
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
            }

            #if arch(arm64)
            if #available(macOS 13, *), wizardState.useAppleVirtualization {
                WizardCardGroup("Additional Options") {
                    WizardToggleRow("Enable Rosetta (x86_64 Emulation)",
                                    subtitle: "Run x86_64 binaries on Apple silicon",
                                    systemImage: "arrow.triangle.2.circlepath",
                                    isOn: $wizardState.linuxHasRosetta)
                    WizardRowDivider()
                    Link(destination: URL(string: "https://docs.getutm.app/advanced/rosetta/")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "book")
                                .font(.system(size: 17))
                                .foregroundColor(.accentColor)
                                .frame(width: 26)
                            Text("Installation Instructions")
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
            }
            #endif

            if wizardState.bootDevice == .kernel {
                WizardCardGroup(kernelSectionTitle,
                                footer: "These are typically the files you downloaded alongside a Linux distribution's ISO.") {
                    FileBrowseField(url: $wizardState.linuxKernelURL,
                                    isFileImporterPresented: $isFileImporterPresented,
                                    hasClearButton: false) {
                        selectImage = .kernel
                    }
                    WizardRowDivider()
                    FileBrowseField(url: $wizardState.linuxInitialRamdiskURL,
                                    isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .initialRamdisk
                    }
                    WizardRowDivider()
                    FileBrowseField(url: $wizardState.linuxRootImageURL,
                                    isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .rootImage
                    }
                    WizardRowDivider()
                    FileBrowseField(url: $wizardState.bootImageURL,
                                    isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .bootImage
                    }
                }

                WizardCardGroup("Boot Arguments") {
                    WizardRow("Arguments",
                              subtitle: "Passed to the kernel on boot",
                              systemImage: "text.alignleft") {
                        TextField("Boot Arguments", text: $wizardState.linuxBootArguments)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                WizardCardGroup(wizardState.bootDevice == .drive
                                ? "Import Disk Image"
                                : "Boot ISO Image") {
                    FileBrowseField(url: $wizardState.bootImageURL,
                                    isFileImporterPresented: $isFileImporterPresented) {
                        selectImage = .bootImage
                    }
                }
            }

            if wizardState.isBusy {
                HStack {
                    Spacer()
                    Spinner(size: .large)
                    Spacer()
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
    }

    private var kernelSectionTitle: LocalizedStringKey {
        if wizardState.useAppleVirtualization {
            return "Uncompressed kernel and ramdisk"
        } else {
            return "Kernel and ramdisk"
        }
    }

    private func processImage(_ result: Result<URL, Error>) {
        wizardState.busyWorkAsync {
            let url = try result.get()
            await MainActor.run {
                switch selectImage {
                case .kernel:
                    wizardState.linuxKernelURL = url
                case .initialRamdisk:
                    wizardState.linuxInitialRamdiskURL = url
                case .rootImage:
                    wizardState.linuxRootImageURL = url
                case .bootImage:
                    wizardState.bootImageURL = url
                }
            }
        }
    }
}

struct VMWizardOSLinuxView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardOSLinuxView(wizardState: wizardState)
    }
}
