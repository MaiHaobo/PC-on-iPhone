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

struct VMWizardHardwareView: View {
    private enum SupportedMachine: CaseIterable, Identifiable {
        case quadra800
        //case powerMacG3Beige
        case powerMacG4
        //case powerMacG5
        case i440FX
        case q35
        case arm64Virt
        case riscv64Virt

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .quadra800: "Macintosh Quadra 800 (1993, M68K)"
            //case .powerMacG3Beige: "Power Macintosh G3 (1997, Beige)"
            case .powerMacG4: "Power Macintosh G4 (1999, PPC)"
            //case .powerMacG5: "Power Macintosh G5 (2003, PPC64)"
            case .i440FX: "Intel i440FX based PC (1996, i386)"
            case .q35: "Intel ICH9 based PC (2009, x86_64)"
            case .arm64Virt: "ARM64 virtual machine (2014, ARM64)"
            case .riscv64Virt: "RISC-V64 virtual machine (2018, RISC-V64)"
            }
        }

        /// Short form used in the collapsed summary row, so the chosen machine
        /// is readable at a glance without the full descriptive title.
        var displayTitle: String {
            switch self {
            case .quadra800: return "Macintosh Quadra 800"
            case .powerMacG4: return "Power Macintosh G4"
            case .i440FX: return "Intel i440FX PC"
            case .q35: return "Intel ICH9 PC"
            case .arm64Virt: return "ARM64 virtual machine"
            case .riscv64Virt: return "RISC-V64 virtual machine"
            }
        }

        var symbolName: String {
            switch self {
            case .quadra800, .powerMacG4: return "desktopcomputer"
            case .i440FX, .q35: return "pc"
            case .arm64Virt, .riscv64Virt: return "cpu"
            }
        }

        var architecture: QEMUArchitecture {
            switch self {
            case .quadra800: return .m68k
            //case .powerMacG3Beige: return .ppc
            case .powerMacG4: return .ppc
            //case .powerMacG5: return .ppc64
            case .i440FX: return .i386
            case .q35: return .x86_64
            case .arm64Virt: return .aarch64
            case .riscv64Virt: return .riscv64
            }
        }

        var target: any QEMUTarget {
            switch self {
            case .quadra800: return QEMUTarget_m68k.q800
            //case .powerMacG3Beige: return QEMUTarget_ppc.g3beige
            case .powerMacG4: return QEMUTarget_ppc.mac99
            //case .powerMacG5: return QEMUTarget_ppc.mac99
            case .i440FX: return QEMUTarget_i386.pc
            case .q35: return QEMUTarget_x86_64.q35
            case .arm64Virt: return QEMUTarget_aarch64.virt
            case .riscv64Virt: return QEMUTarget_riscv64.virt
            }
        }

        var minRam: Int {
            switch self {
            case .quadra800: return 8
            //case .powerMacG3Beige: return 32
            case .powerMacG4: return 64
            //case .powerMacG5: return 64
            default: return 0
            }
        }

        var maxRam: Int {
            switch self {
            case .quadra800: return 1024
            //case .powerMacG3Beige: return 2047
            case .powerMacG4: return 2048
            //case .powerMacG5: return 2048
            default: return 0
            }
        }

        var defaultRam: Int {
            switch self {
            case .quadra800: return 128
            //case .powerMacG3Beige: return 512
            case .powerMacG4: return 512
            //case .powerMacG5: return 512
            case .i440FX: return 512
            #if os(macOS)
            default: return 4096
            #else
            default: return 512
            #endif
            }
        }

        var defaultStorageGiB: Int {
            switch self {
            case .quadra800, .powerMacG4: return 2
            case .i440FX: return 2
            #if os(macOS)
            default: return 64
            #else
            default: return 2
            #endif
            }
        }

        var maxSupportedCores: Int {
            switch self {
            case .quadra800, .powerMacG4: return 1
            default: return 0
            }
        }

        var isLegacyHardware: Bool {
            switch self {
            case .quadra800, .powerMacG4, .i440FX: return true
            default: return false
            }
        }

        func isSupported(running os: VMWizardOS) -> Bool {
            switch os {
            case .Other: return true
            case .macOS: return [.arm64Virt].contains(self)
            case .Linux: return true
            case .Windows: return [.i440FX, .q35, .arm64Virt].contains(self)
            case .ClassicMacOS: return [.quadra800, .powerMacG4].contains(self)
            }
        }

        static func `default`(for os: VMWizardOS) -> Self {
            switch os {
            case .Other: return .q35
            case .macOS: return .arm64Virt
            case .Linux: return .q35
            case .Windows: return .q35
            case .ClassicMacOS: return .powerMacG4
            }
        }
    }

    @ObservedObject var wizardState: VMWizardState
    @State private var isExpertMode: Bool = false
    @State private var selectedMachine: SupportedMachine?

    var minCores: Int {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.minimumAllowedCPUCount
        #else
        1
        #endif
    }

    var maxCores: Int {
        #if canImport(Virtualization)
        VZVirtualMachineConfiguration.maximumAllowedCPUCount
        #else
        Int(sysctlIntRead("hw.ncpu"))
        #endif
    }

    var minMemoryMib: Int {
        #if canImport(Virtualization)
        Int(VZVirtualMachineConfiguration.minimumAllowedMemorySize / UInt64(wizardState.bytesInMib))
        #else
        8
        #endif
    }

    var maxMemoryMib: Int {
        #if canImport(Virtualization)
        Int(VZVirtualMachineConfiguration.maximumAllowedMemorySize / UInt64(wizardState.bytesInMib))
        #else
        sysctlIntRead("hw.memsize")
        #endif
    }

    /// The machine list actually offered for the chosen OS.
    private var supportedMachines: [SupportedMachine] {
        SupportedMachine.allCases.filter { $0.isSupported(running: wizardState.operatingSystem) }
    }

    var body: some View {
        VMWizardContent("Hardware", page: .hardware) {
            if !wizardState.useVirtualization {
                Toggle("Expert Mode", isOn: $isExpertMode)
                    .help("List all supported hardware. May require manual configuration to boot.")
            }

            if !wizardState.useVirtualization && isExpertMode {
                Section {
                    VMConfigConstantPicker(selection: $wizardState.systemArchitecture)
                        .onChange(of: wizardState.systemArchitecture) { newValue in
                            wizardState.systemTarget = newValue.targetType.default
                        }
                } header: {
                    Text("Architecture")
                }

                Section {
                    VMConfigConstantPicker(selection: $wizardState.systemTarget,
                                           type: wizardState.systemArchitecture.targetType)
                } header: {
                    Text("System")
                }
            } else if !isExpertMode {
                machineSection
            }

            Section {
                RAMSlider(systemMemory: $wizardState.systemMemoryMib) { _ in
                    let selectedMax = selectedMachine?.maxRam ?? 0
                    let validMax = selectedMax > 0 ? selectedMax : maxMemoryMib
                    if wizardState.systemMemoryMib > validMax {
                        wizardState.systemMemoryMib = validMax
                    }
                    let validMin = selectedMachine?.minRam ?? 0
                    if wizardState.systemMemoryMib < validMin {
                        wizardState.systemMemoryMib = validMin
                    }
                }
            } header: {
                Text("Memory")
            }

            if isExpertMode || selectedMachine?.maxSupportedCores == 0 {
                Section {
                    HStack {
                        Stepper(value: $wizardState.systemCpuCount, in: minCores...maxCores) {
                            Text("CPU Cores")
                        }
                        NumberTextField("", number: $wizardState.systemCpuCount,
                                        prompt: "Default",
                                        onEditingChanged: { _ in
                            guard wizardState.systemCpuCount != 0 else {
                                return
                            }
                            if wizardState.systemCpuCount < minCores {
                                wizardState.systemCpuCount = minCores
                            } else if wizardState.systemCpuCount > maxCores {
                                wizardState.systemCpuCount = maxCores
                            }
                        })
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("CPU")
                }
            }

            if !wizardState.useAppleVirtualization && wizardState.operatingSystem == .Linux {
                Section {
                    Toggle("Enable display output", isOn: $wizardState.isDisplayEnabled)
                        .onChange(of: wizardState.isDisplayEnabled) { newValue in
                            if !newValue {
                                wizardState.isGLEnabled = false
                            }
                        }
                    Toggle("Enable hardware OpenGL acceleration", isOn: $wizardState.isGLEnabled)
                        .disabled(!wizardState.isDisplayEnabled)
                } header: {
                    Text("Display Output")
                } footer: {
                    Text("There are known issues in some newer Linux drivers including black screen, broken compositing, and apps failing to render.")
                }
            }

            if !wizardState.useVirtualization && isExpertMode {
                Section {
                    Toggle("Legacy Hardware", isOn: $wizardState.legacyHardware)
                        .help("If checked, emulated devices with higher compatibility will be instantiated at the cost of performance.")
                } header: {
                    Text("Options")
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            if wizardState.useVirtualization {
                isExpertMode = true
                selectedMachine = nil
                #if arch(arm64)
                wizardState.systemArchitecture = .aarch64
                #elseif arch(x86_64)
                wizardState.systemArchitecture = .x86_64
                #else
                #error("Unsupported architecture.")
                #endif
                wizardState.systemTarget = wizardState.systemArchitecture.targetType.default
                wizardState.legacyHardware = false
            } else if selectedMachine == nil {
                let machine = SupportedMachine.default(for: wizardState.operatingSystem)
                selectedMachine = machine
                apply(machine)
            }
        }
    }

    /// The machine picker, in the same shape as the original UTM: a native
    /// inline picker inside a `List` section, so the rows get the system
    /// (liquid glass) treatment on iOS 26 without any custom drawing.
    @ViewBuilder
    private var machineSection: some View {
        Picker("Machine", selection: $selectedMachine) {
            ForEach(supportedMachines) { machine in
                Text(machine.title).tag(Optional(machine))
            }
        }
        .pickerStyle(.inline)
        .onChange(of: selectedMachine) { newValue in
            guard let newValue = newValue else {
                return
            }
            apply(newValue)
        }
    }

    /// Applies every setting that follows from a machine choice. Kept in one
    /// place so the picker and the `onAppear` default cannot drift apart.
    private func apply(_ machine: SupportedMachine) {
        wizardState.systemArchitecture = machine.architecture
        wizardState.systemTarget = machine.target
        wizardState.systemMemoryMib = machine.defaultRam
        wizardState.systemCpuCount = machine.maxSupportedCores
        wizardState.storageSizeGib = machine.defaultStorageGiB
        wizardState.legacyHardware = machine.isLegacyHardware
    }

    private func sysctlIntRead(_ name: String) -> Int {
        var value: Int = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }
}

struct VMWizardHardwareView_Previews: PreviewProvider {
    @StateObject static var wizardState = VMWizardState()

    static var previews: some View {
        VMWizardHardwareView(wizardState: wizardState)
    }
}
