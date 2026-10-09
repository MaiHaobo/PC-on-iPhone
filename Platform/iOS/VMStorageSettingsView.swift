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
/// The list starts read-only: it shows everything the bundle holds and marks
/// what nothing refers to any more. Removing those is a deliberate step — the
/// user enters selection mode, picks the files, and confirms once — because the
/// bundle is the only copy of a virtual machine's data.
///
/// Only entries the analyzer calls reclaimable can be selected. Files in use and
/// snapshot state are listed but have no selection control, so there is no way
/// to remove them from this screen even by mistake.
struct VMStorageSettingsView: View {
    let vm: VMData
    /// Called after a cleanup finishes. The overview screen uses this to know
    /// its totals are out of date.
    var onFinish: (() -> Void)?

    @State private var report: UTMPackageAnalyzer.Report?
    @State private var isScanning = false
    @State private var isSelecting = false
    @State private var selected: Set<URL> = []
    /// One alert at a time. SwiftUI only honours the last `.alert` on a view,
    /// so the confirmation and the result notice share a single modifier and
    /// are told apart by which case is set.
    @State private var activeAlert: StorageAlert?

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
                    if !report.reclaimableEntries.isEmpty {
                        removeSection(report)
                    }
                }
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: scan)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let report = report, !report.reclaimableEntries.isEmpty, !isScanning {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting {
                            selected.removeAll()
                        }
                    }
                }
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .confirmRemoval(let pending):
                return Alert(
                    title: Text("Delete Unused Files?"),
                    message: Text(String(
                        format: NSLocalizedString("This permanently deletes %lld file(s), freeing %@. This cannot be undone.", comment: "Settings"),
                        pending.urls.count,
                        UTMPackageAnalyzer.Report.formatted(pending.size)
                    )),
                    primaryButton: .destructive(Text("Delete")) {
                        performRemoval(pending.urls)
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            case .finished(let message):
                return Alert(
                    title: Text("Cleanup Complete"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
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
                    .monospacedDigit()
            }
            HStack {
                Text("Unused")
                Spacer()
                Text(UTMPackageAnalyzer.Report.formatted(report.reclaimableSize))
                    .foregroundStyle(report.reclaimableSize > 0 ? .orange : .secondary)
                    .monospacedDigit()
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
                    entryRow(entry)
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
    private func entryRow(_ entry: UTMPackageAnalyzer.Entry) -> some View {
        let isSelectable = isSelecting && entry.kind.isReclaimable
        HStack {
            if isSelectable {
                Image(systemName: selected.contains(entry.url) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(entry.url) ? Color.accentColor : Color.secondary)
            }
            Text(entry.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            Text(UTMPackageAnalyzer.Report.formatted(entry.size))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelectable else { return }
            if selected.contains(entry.url) {
                selected.remove(entry.url)
            } else {
                selected.insert(entry.url)
            }
        }
    }

    @ViewBuilder
    private func noteSection(_ report: UTMPackageAnalyzer.Report) -> some View {
        Section {
            EmptyView()
        } footer: {
            if report.reclaimableSize > 0 {
                Text("Files listed as Unused or Temporary are not referenced by this virtual machine. Files in use and snapshots are never removed.")
            } else {
                Text("Every file in this bundle is referenced by the configuration or belongs to a snapshot.")
            }
        }
    }

    @ViewBuilder
    private func removeSection(_ report: UTMPackageAnalyzer.Report) -> some View {
        Section {
            if isSelecting {
                Button(role: .destructive) {
                    activeAlert = .confirmRemoval(PendingRemoval(urls: Array(selected), size: selectedSize))
                } label: {
                    HStack {
                        Spacer()
                        Text(selected.isEmpty
                             ? "Select Files to Delete"
                             : String(format: NSLocalizedString("Delete %lld File(s)", comment: "Settings"), selected.count))
                        Spacer()
                    }
                }
                .disabled(selected.isEmpty)
            } else {
                Button(role: .destructive) {
                    // Start from nothing selected so the destructive action is
                    // never one tap away from the summary.
                    selected.removeAll()
                    isSelecting = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Select Unused Files…")
                        Spacer()
                    }
                }
            }
        } header: {
            Text("Cleanup")
        }
    }

    // MARK: - Helpers

    private struct KindGroup {
        let kind: UTMPackageAnalyzer.FileKind
        let entries: [UTMPackageAnalyzer.Entry]
        var total: Int64 { entries.reduce(0) { $0 + $1.size } }
    }

    /// Reports the kinds in a fixed order and skips the ones with nothing in
    /// them so the screen stays short.
    private func groupedKinds(_ report: UTMPackageAnalyzer.Report) -> [KindGroup] {
        let order: [UTMPackageAnalyzer.FileKind] = [.orphan, .temporary, .snapshot, .inUse, .unknown]
        return order.compactMap { kind in
            let entries = report.entries(of: kind)
            return entries.isEmpty ? nil : KindGroup(kind: kind, entries: entries)
        }
    }

    /// Total size of the current selection, for the confirmation text.
    private var selectedSize: Int64 {
        guard let report = report else { return 0 }
        return report.entries
            .filter { selected.contains($0.url) }
            .reduce(Int64(0)) { $0 + $1.size }
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

    private func performRemoval(_ urls: [URL]) {
        guard let report = report else { return }
        let packageURL = report.packageURL
        Task {
            let result = await UTMPackageAnalyzer.remove(urls, from: report)
            let fresh = await UTMPackageAnalyzer.analyze(packageURL: packageURL)
            await MainActor.run {
                self.report = fresh
                selected.removeAll()
                isSelecting = false
                let message: String
                if result.keptNames.isEmpty {
                    message = String(
                        format: NSLocalizedString("Freed %@.", comment: "Settings"),
                        UTMPackageAnalyzer.Report.formatted(result.freedSize)
                    )
                } else {
                    message = String(
                        format: NSLocalizedString("Freed %@. %lld file(s) were kept because they are still in use.", comment: "Settings"),
                        UTMPackageAnalyzer.Report.formatted(result.freedSize),
                        result.keptNames.count
                    )
                }
                activeAlert = .finished(message)
                onFinish?()
            }
        }
    }
}

/// Which alert the screen is showing. Both the confirmation and the result
/// notice go through one `.alert(item:)`, because only the last alert modifier
/// on a view takes effect.
private enum StorageAlert: Identifiable {
    case confirmRemoval(PendingRemoval)
    case finished(String)

    var id: String {
        switch self {
        case .confirmRemoval(let pending): return "confirm-" + pending.id
        case .finished(let message): return "finished-" + message
        }
    }
}

/// Wrapper so the confirmation alert can be driven by `item:` from a set of URLs.
private struct PendingRemoval {
    let urls: [URL]
    let size: Int64
    var id: String { urls.map(\.lastPathComponent).joined(separator: ",") }
}
