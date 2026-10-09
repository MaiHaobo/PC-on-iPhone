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

import Foundation

/// Inspects a `.utm` bundle and reports which files inside it are still in use.
///
/// This is read-only: it never removes anything. The configuration only ever
/// names the files it needs, so anything else in the bundle is left over from an
/// earlier configuration — a disk image that was replaced, a log from a run that
/// no longer happens — or from a download that was interrupted. Those are worth
/// telling the user about because the bundle is otherwise opaque: a VM that
/// "shrank" in the settings still occupies the space of the images it used to
/// point at.
///
/// Snapshots are the hazard here. Their files are named after the image they
/// belong to plus an identifier, so they look like leftovers to anything that
/// only compares names against the configuration. The manifest is the authority
/// on which ones are real; when it cannot be read the analyzer keeps every
/// candidate rather than risk reporting a snapshot as disposable.
enum UTMPackageAnalyzer {
    /// What the analyzer concluded about a single file.
    enum FileKind {
        /// Named by the configuration: a disk image, firmware, an icon.
        case inUse
        /// State or screenshot belonging to a snapshot.
        case snapshot
        /// Nothing refers to it and it is not a snapshot. The interesting case.
        case orphan
        /// Left behind by an interrupted write or a filesystem bookkeeping file.
        case temporary
        /// Not recognisable either way, so it is kept and not reported as waste.
        case unknown

        /// Whether the file counts toward the reclaimable total.
        var isReclaimable: Bool {
            switch self {
            case .orphan, .temporary: return true
            case .inUse, .snapshot, .unknown: return false
            }
        }
    }

    struct Entry: Identifiable {
        let url: URL
        let size: Int64
        let kind: FileKind

        var id: URL { url }
        var name: String { url.lastPathComponent }
    }

    struct Report {
        let packageURL: URL
        let name: String
        let entries: [Entry]
        /// Whether the configuration could be read at all. When this is false the
        /// report is empty by construction — see `analyze`.
        let didReadConfiguration: Bool

        var totalSize: Int64 {
            entries.reduce(0) { $0 + $1.size }
        }

        var reclaimableSize: Int64 {
            entries.filter { $0.kind.isReclaimable }.reduce(0) { $0 + $1.size }
        }

        var reclaimableEntries: [Entry] {
            entries.filter { $0.kind.isReclaimable }
        }

        func entries(of kind: FileKind) -> [Entry] {
            entries.filter { $0.kind == kind }
        }
    }

    // MARK: - Names the configuration is allowed to keep

    /// Files with a fixed name in the `Data` directory. Whether one is actually
    /// present depends on the matching configuration switch, so they are only
    /// counted as referenced when that switch is on — otherwise a stale
    /// `tpmdata` from a removed TPM device would read as "in use" and never be
    /// reported.
    private static func fixedNames(for qemu: UTMQemuConfigurationQEMU) -> Set<String> {
        var names: Set<String> = []
        if qemu.hasUefiBoot {
            names.insert(QEMUPackageFileName.efiVariables.rawValue)
        }
        if qemu.hasTPMDevice {
            names.insert(QEMUPackageFileName.tpmData.rawValue)
        }
        if qemu.hasDebugLog {
            names.insert(QEMUPackageFileName.debugLog.rawValue)
        }
        // A saved machine state is what "resume" reads, so it is in use whenever
        // it exists. It is not behind a switch in the configuration.
        names.insert(QEMUPackageFileName.vmState.rawValue)
        return names
    }

    /// Extensions that mark a half-written file rather than a real one.
    private static let temporaryExtensions: Set<String> = [
        "part", "partial", "download", "tmp", "temp", "crdownload",
    ]

    /// Names the filesystem or a download tool leaves behind that carry no data.
    private static let temporaryNames: Set<String> = [
        ".DS_Store", ".localized", "Thumbs.db",
    ]

    // MARK: - Analysis

    /// Classifies every file in the bundle's `Data` directory (plus the
    /// snapshot screenshots directory, which sits beside it).
    ///
    /// Returns an empty report if the configuration cannot be read. That is
    /// deliberate: without it there is no way to tell an image from a leftover,
    /// and guessing would mean reporting live files as waste. An empty report
    /// says nothing, which is the safe failure.
    @MainActor static func analyze(packageURL: URL) async -> Report {
        // The bundle is named after the VM on disk, but the configuration holds
        // the name the user actually sees, so prefer that when it is available.
        let fallbackName = packageURL.deletingPathExtension().lastPathComponent

        func emptyReport(didRead: Bool) -> Report {
            Report(packageURL: packageURL, name: fallbackName, entries: [], didReadConfiguration: didRead)
        }

        let scoped = packageURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                packageURL.stopAccessingSecurityScopedResource()
            }
        }

        // `load` lives in an extension on the protocol, which has an associated
        // type and so cannot be called on the metatype; naming the concrete type
        // is what makes it resolve. Anything that is not a QEMU configuration —
        // including a bundle whose plist cannot be decoded — ends up as nil.
        guard let config = try? UTMQemuConfiguration.load(from: packageURL) as? UTMQemuConfiguration else {
            return emptyReport(didRead: false)
        }

        // Everything the configuration points at, by file name. The accessors
        // are main actor-isolated, so the whole set is collected here and only
        // plain values are handed to the background work below.
        let displayName = config.information.name
        var referenced: Set<String> = []
        for drive in config.drives {
            if let imageName = drive.imageName {
                referenced.insert(imageName)
            }
        }
        referenced.formUnion(fixedNames(for: config.qemu))
        if config.information.isIconCustom, let iconURL = config.information.iconURL {
            referenced.insert(iconURL.lastPathComponent)
        }
        // The manifest is part of the bundle by definition.
        referenced.insert(UTMSnapshotManifest.fileName)

        // Snapshot state lives beside the images it belongs to and is named
        // after them, so a name that begins with a referenced image plus a dot
        // is a snapshot candidate.
        let manifest = (try? UTMSnapshotManifest.load(from: packageURL)) ?? nil
        var snapshotIdentifiers = Set(manifest?.snapshots.map { $0.backendIdentifier } ?? [])
        // QEMU suspends under a fixed name when the manifest does not record
        // one, which is how builds before the manifest existed wrote it, and
        // such a state is still resumable. `suspendSnapshotName` falls back to
        // that constant, so it has to be treated as a live snapshot even when
        // there is no manifest at all. The cost is that a file genuinely named
        // `<image>.suspend` is never reported as waste, which is the safe way
        // to be wrong.
        snapshotIdentifiers.insert(kUTMQemuDefaultSuspendSnapshotName)
        if let suspendIdentifier = manifest?.suspendIdentifier {
            snapshotIdentifiers.insert(suspendIdentifier)
        }
        let namedScreenshots = Set(manifest?.snapshots.compactMap { $0.screenshotName } ?? [])
        // A report with no manifest keeps every screenshot: none can be ruled
        // out without the list that names them.
        let hasManifest = manifest != nil

        let dataURL = packageURL.appendingPathComponent(UTMQemuConfiguration.dataDirectoryName)

        return await Task.detached(priority: .userInitiated) {
            var entries: [Entry] = []

            let fileManager = FileManager.default
            let contents = (try? fileManager.contentsOfDirectory(
                at: dataURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .totalFileAllocatedSizeKey]
            )) ?? []

            for url in contents {
                let values = try? url.resourceValues(
                    forKeys: [.fileSizeKey, .isRegularFileKey, .totalFileAllocatedSizeKey]
                )
                // Directories other than the screenshots one are not expected in
                // Data; count their contents so nothing is silently ignored.
                let isFile = values?.isRegularFile ?? false
                let size: Int64
                if isFile {
                    size = Int64(values?.fileSize ?? 0)
                } else {
                    size = recursiveSize(of: url, fileManager: fileManager)
                }
                let kind = classify(
                    url: url,
                    referenced: referenced,
                    snapshotIdentifiers: snapshotIdentifiers
                )
                entries.append(Entry(url: url, size: size, kind: kind))
            }

            // Screenshots are referenced by the manifest, never by the
            // configuration. One the manifest no longer names belongs to a
            // snapshot that was deleted. Without a manifest none of them can be
            // ruled out, so they are all kept.
            let screenshotsURL = UTMSnapshotManifest.screenshotsURL(in: packageURL)
            let screenshots = (try? fileManager.contentsOfDirectory(
                at: screenshotsURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
            )) ?? []
            for url in screenshots {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                let size = Int64(values?.fileSize ?? 0)
                let kind: FileKind
                if !hasManifest || namedScreenshots.contains(url.lastPathComponent) {
                    kind = .snapshot
                } else {
                    kind = .orphan
                }
                entries.append(Entry(url: url, size: size, kind: kind))
            }

            entries.sort { $0.size > $1.size }
            return Report(packageURL: packageURL, name: displayName, entries: entries, didReadConfiguration: true)
        }.value
    }

    /// Analyzes every bundle, in order.
    @MainActor static func analyzeAll(packageURLs: [URL]) async -> [Report] {
        var reports: [Report] = []
        for url in packageURLs {
            reports.append(await analyze(packageURL: url))
        }
        return reports
    }

    // MARK: - Removal

    struct RemovalResult {
        var removedCount: Int
        var freedSize: Int64
        /// Files that were asked for but kept, because they no longer classify
        /// as reclaimable or could not be removed.
        var keptNames: [String]
    }

    /// Deletes the given files, but only after checking each one again.
    ///
    /// The report is a snapshot of an earlier moment: the configuration could
    /// have been edited, a snapshot taken, or the machine started since. So each
    /// candidate is re-classified against the state on disk right now and
    /// anything that is no longer disposable is left alone. Names are matched
    /// against the freshly built classification rather than trusted from the
    /// caller, which is what keeps a stale list from deleting live data.
    ///
    /// - Parameters:
    ///   - urls: Files the user chose to remove.
    ///   - report: The report those choices came from.
    /// - Returns: What was removed and what was held back.
    @discardableResult
    @MainActor static func remove(_ urls: [URL], from report: Report) async -> RemovalResult {
        guard !urls.isEmpty else {
            return RemovalResult(removedCount: 0, freedSize: 0, keptNames: [])
        }

        // Re-scan so the decision is made on current state, not on the report
        // the user was looking at.
        let fresh = await analyze(packageURL: report.packageURL)
        let allowed = Dictionary(
            fresh.entries.filter { $0.kind.isReclaimable }.map { ($0.url, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let scoped = report.packageURL.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                report.packageURL.stopAccessingSecurityScopedResource()
            }
        }

        return await Task.detached(priority: .userInitiated) {
            var removedCount = 0
            var freed: Int64 = 0
            var kept: [String] = []
            let fileManager = FileManager.default

            for url in urls {
                guard let entry = allowed[url] else {
                    // No longer disposable, or never was.
                    kept.append(url.lastPathComponent)
                    continue
                }
                do {
                    try fileManager.removeItem(at: url)
                    removedCount += 1
                    freed += entry.size
                } catch {
                    kept.append(url.lastPathComponent)
                }
            }
            return RemovalResult(removedCount: removedCount, freedSize: freed, keptNames: kept)
        }.value
    }

    // MARK: - Classification

    private static func classify(
        url: URL,
        referenced: Set<String>,
        snapshotIdentifiers: Set<String>
    ) -> FileKind {
        let name = url.lastPathComponent

        if referenced.contains(name) {
            return .inUse
        }

        // A snapshot file is named after the image it belongs to plus an
        // identifier: `<image>.<identifier>` for a saved state or a layer. The
        // identifiers come from the manifest plus the QEMU suspend default, so
        // a state that predates the manifest is still recognised. Without a
        // manifest every name of that shape is kept, because mistaking a
        // snapshot for a leftover is the one error the user cannot undo.
        if !snapshotIdentifiers.isEmpty {
            for identifier in snapshotIdentifiers where name.hasSuffix("." + identifier) {
                return .snapshot
            }
        }
        for base in referenced where name.hasPrefix(base + ".") {
            return .snapshot
        }

        if isTemporary(name: name) {
            return .temporary
        }

        return .orphan
    }

    private static func isTemporary(name: String) -> Bool {
        if temporaryNames.contains(name) {
            return true
        }
        let ext = (name as NSString).pathExtension.lowercased()
        return temporaryExtensions.contains(ext)
    }

    private static func recursiveSize(of url: URL, fileManager: FileManager) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}

// MARK: - Formatting

extension UTMPackageAnalyzer.Report {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Human-readable size, shared by the storage screens.
    static func formatted(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }
}

extension UTMPackageAnalyzer.FileKind {
    var localizedTitle: String {
        switch self {
        case .inUse: return NSLocalizedString("In Use", comment: "UTMPackageAnalyzer")
        case .snapshot: return NSLocalizedString("Snapshots", comment: "UTMPackageAnalyzer")
        case .orphan: return NSLocalizedString("Unused", comment: "UTMPackageAnalyzer")
        case .temporary: return NSLocalizedString("Temporary", comment: "UTMPackageAnalyzer")
        case .unknown: return NSLocalizedString("Other", comment: "UTMPackageAnalyzer")
        }
    }
}
