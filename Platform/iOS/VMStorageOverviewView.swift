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

/// Storage report across every virtual machine, pushed from the "Virtual
/// Machines" row under Storage in the app settings.
///
/// The per-VM screen answers "what is in this bundle?"; this one answers "which
/// bundle is holding on to space?". Scanning every VM means reading each
/// bundle, so it runs in the background and the list fills in as results
/// arrive rather than blocking on the whole set.
@MainActor
struct VMStorageOverviewView: View {
    @EnvironmentObject private var data: UTMData

    @State private var reports: [UTMPackageAnalyzer.Report] = []
    @State private var isScanning = false
    /// Set while the overview is waiting on a per-VM screen that may have just
    /// deleted something, so the totals are refreshed on the way back.
    @State private var needsRescan = false

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        List {
            if isScanning && reports.isEmpty {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if data.virtualMachines.isEmpty {
                Section {
                    Text("There are no virtual machines.")
                        .foregroundStyle(.secondary)
                }
            } else {
                if totalReclaimable > 0 {
                    Section {
                        HStack {
                            Text("Unused")
                            Spacer()
                            Text(formatted(totalReclaimable))
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                        }
                    } header: {
                        Text("All Virtual Machines")
                    } footer: {
                        Text("Space held by files that no configuration refers to. You can remove them from this screen.")
                    }
                }
                Section {
                    ForEach(data.virtualMachines, id: \.id) { vm in
                        // The trailing-closure `NavigationLink` is iOS 16+; this
                        // screen also compiles against the iOS 15 SE target, so
                        // the older label/destination form is used instead.
                        NavigationLink(destination: storageView(for: vm)) {
                            row(for: vm)
                        }
                    }
                } header: {
                    Text("Virtual Machines")
                }
            }
        }
        .navigationTitle("Virtual Machines")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // A push is not an appearance, so a report that was stale before
            // navigating away stays stale. Rescan instead of trusting it.
            if needsRescan {
                needsRescan = false
                scan()
            } else if reports.isEmpty {
                scan()
            }
        }
    }

    /// The per-VM screen, with a callback that marks the totals as stale when
    /// the user comes back — deleting files there changes what this lists.
    private func storageView(for vm: VMData) -> some View {
        VMStorageSettingsView(vm: vm) {
            needsRescan = true
        }
    }

    @ViewBuilder
    private func row(for vm: VMData) -> some View {
        let report = reports.first { $0.packageURL == vm.pathUrl }
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(report?.name ?? vm.detailsTitleLabel)
                    .lineLimit(1)
                if let reclaimable = report?.reclaimableSize, reclaimable > 0 {
                    Text("\(formatted(reclaimable)) unused")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 12)
            if let total = report?.totalSize {
                Text(formatted(total))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                // Still scanning this one.
                ProgressView()
            }
        }
    }

    // MARK: - Helpers

    private var totalReclaimable: Int64 {
        reports.reduce(0) { $0 + $1.reclaimableSize }
    }

    private func formatted(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        reports.removeAll()
        let urls = data.virtualMachines.map { $0.pathUrl }
        Task {
            // One VM at a time so a large bundle does not monopolise the disk,
            // and each result is published as soon as it is ready.
            for url in urls {
                let report = await UTMPackageAnalyzer.analyze(packageURL: url)
                await MainActor.run {
                    reports.append(report)
                }
            }
            await MainActor.run {
                isScanning = false
            }
        }
    }
}
