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

struct VMWizardOSView: View {
    @ObservedObject var wizardState: VMWizardState

    var body: some View {
        VMWizardContent("Operating System", page: .operatingSystem) {
            Section {
                #if os(macOS) && arch(arm64)
                if wizardState.useVirtualization {
                    Button {
                        wizardState.operatingSystem = .macOS
                        wizardState.useAppleVirtualization = true
                        wizardState.isGuestToolsInstallRequested = false
                        wizardState.next()
                    } label: {
                        OperatingSystem(imageName: "Logo-macOS", name: "macOS 12+")
                    }
                }
                #endif
                if !wizardState.useVirtualization {
                    Button {
                        wizardState.operatingSystem = .ClassicMacOS
                        wizardState.useAppleVirtualization = false
                        wizardState.isGuestToolsInstallRequested = false
                        wizardState.next()
                    } label: {
                        OperatingSystem(imageName: "Logo-macOS", name: "Classic Mac OS")
                    }
                }
                Button {
                    wizardState.operatingSystem = .Windows
                    wizardState.useAppleVirtualization = false
                    wizardState.isGuestToolsInstallRequested = true
                    wizardState.next()
                } label: {
                    OperatingSystem(imageName: "Logo-Windows", name: "Windows")
                }
                Button {
                    wizardState.operatingSystem = .Linux
                    wizardState.isGuestToolsInstallRequested = false
                    wizardState.next()
                } label: {
                    OperatingSystem(imageName: "Logo-Linux", name: "Linux")
                }
            } header: {
                Text("Preconfigured")
            }

            Section {
                Button {
                    wizardState.operatingSystem = .Other
                    wizardState.useAppleVirtualization = false
                    wizardState.isGuestToolsInstallRequested = false
                    wizardState.next()
                } label: {
                    HStack {
                        Image(systemName: "gearshape")
                            .resizable()
                            .frame(width: 30.0, height: 30.0)
                            .aspectRatio(contentMode: .fit)
                        Text("Other")
                            .font(.title)
                    }
                    .padding()
                }
            } header: {
                Text("Custom")
            }
        }
        .buttonStyle(.inList)
    }
}

/// A row showing a bundled brand mark next to the OS name.
///
/// The image is looked up defensively: the original force-unwrapped it, which
/// would trap at runtime if an asset were ever renamed or dropped from a build.
/// A missing mark now falls back to a neutral symbol so the row still renders.
struct OperatingSystem: View {
    let imageName: String
    let name: LocalizedStringKey

    var body: some View {
        HStack {
            brandImage
            Text(name)
                .font(.title)
        }
        .padding()
    }

    @ViewBuilder
    private var brandImage: some View {
        #if os(macOS)
        if let image = NSImage(named: imageName) {
            Image(nsImage: image)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackIcon
        }
        #else
        if let image = UIImage(named: imageName) {
            Image(uiImage: image)
                .resizable()
                .frame(width: 30.0, height: 30.0)
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackIcon
        }
        #endif
    }

    private var fallbackIcon: some View {
        Image(systemName: "desktopcomputer")
            .resizable()
            .frame(width: 30.0, height: 30.0)
            .aspectRatio(contentMode: .fit)
    }
}

struct VMWizardOSView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardOSView(wizardState: wizardState)
    }
}
