//
// Copyright © 2026 PC on iPhone. All rights reserved.
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

/// Storage report for a single virtual machine, pushed from the "Storage" row
/// in the VM's settings.
///
/// Read-only by design: it lists what the bundle holds and which parts nothing
/// refers to any more, but leaves deleting to a later change. The scan walks
/// every file in the bundle, so it runs off the main thread and the screen
/// shows progress while it does.
struct VMStorageSettingsView: View {
    let vm: VMData

    @State private var report: UTMPackageAnalyzer.Report?
    @State private var isScanning = false

    var body: some View {
        List {
            if isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let report = report {
                summarySection(report)
                if report.entries.isEmpty {
                    emptySection(report)
                } else {
                    breakdownSection(report)
                    noteSection(report)
                }
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: scan)
    }

    // MARK: - Sections

    @ViewBuilder
    private func summarySection(_ report: UTMPackageAnalyzer.Report) -> some View {
        Section {
            HStack {
                Text("Total")
                Spacer()
                Text(UTMPackageAnalyzer.Report.formatted(report.totalSize))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Unused")
                Spacer()
                Text(UTMPackageAnalyzer.Report.formatted(report.reclaimableSize))
                    .foregroundStyle(report.reclaimableSize > 0 ? .orange : .secondary)
            }
        } header: {
            Text(report.name)
        }
    }

    @ViewBuilder
    private func emptySection(_ report: UTMPackageAnalyzer.Report) -> some View {
        Section {
            if report.didReadConfiguration {
                Text("This virtual machine has no data files in its bundle.")
                    .foregroundStyle(.secondary)
            } else {
                Text("The configuration for this virtual machine could not be read, so nothing was scanned.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func breakdownSection(_ report: UTMPackageAnalyzer.Report) -> some View {
        ForEach(groupedKinds(report), id: \.kind) { group in
            Section {
                ForEach(group.entries) { entry in
                    HStack {
                        Text(entry.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 12)
                        Text(UTMPackageAnalyzer.Report.formatted(entry.size))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } header: {
                HStack {
                    Text(group.kind.localizedTitle)
                    Spacer()
                    Text(UTMPackageAnalyzer.Report.formatted(group.total))
                }
            }
        }
    }

    @ViewBuilder
    private func noteSection(_ report: UTMPackageAnalyzer.Report) -> some View {
        Section {
            EmptyView()
        } footer: {
            if report.reclaimableSize > 0 {
                Text("Files listed as Unused or Temporary are not referenced by this virtual machine. Nothing has been deleted — this screen only reports what is there.")
            } else {
                Text("Every file in this bundle is referenced by the configuration or belongs to a snapshot.")
            }
        }
    }

    // MARK: - Helpers

    private struct KindGroup {
        let kind: UTMPackageAnalyzer.FileKind
        let entries: [UTMPackageAnalyzer.Entry]
        var total: Int64 { entries.reduce(0) { $0 + $1.size } }
    }

    /// Reports the kinds in a fixed order, largest group first within that, and
    /// skips the ones with nothing in them so the screen stays short.
    private func groupedKinds(_ report: UTMPackageAnalyzer.Report) -> [KindGroup] {
        let order: [UTMPackageAnalyzer.FileKind] = [.orphan, .temporary, .snapshot, .inUse, .unknown]
        return order.compactMap { kind in
            let entries = report.entries(of: kind)
            return entries.isEmpty ? nil : KindGroup(kind: kind, entries: entries)
        }
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        let url = vm.pathUrl
        Task {
            let result = await UTMPackageAnalyzer.analyze(packageURL: url)
            await MainActor.run {
                report = result
                isScanning = false
            }
        }
    }
}
