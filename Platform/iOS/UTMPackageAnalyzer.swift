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
    static func analyze(packageURL: URL) async -> Report {
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

        guard let config = try? UTMConfiguration.load(from: packageURL) as? UTMQemuConfiguration else {
            return emptyReport(didRead: false)
        }
        let displayName = config.information.name

        // Everything the configuration points at, by file name.
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
        let snapshotIdentifiers = Set(manifest?.snapshots.map { $0.backendIdentifier } ?? [])
        let suspendIdentifier = manifest?.suspendIdentifier

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
                    snapshotIdentifiers: snapshotIdentifiers,
                    suspendIdentifier: suspendIdentifier
                )
                entries.append(Entry(url: url, size: size, kind: kind))
            }

            // Screenshots are referenced by the manifest, never by the
            // configuration. Without a manifest there is no way to tell which
            // are current, so they are all kept.
            let screenshotsURL = UTMSnapshotManifest.screenshotsURL(in: packageURL)
            let screenshots = (try? fileManager.contentsOfDirectory(
                at: screenshotsURL,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
            )) ?? []
            for url in screenshots {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                let size = Int64(values?.fileSize ?? 0)
                entries.append(Entry(url: url, size: size, kind: .snapshot))
            }

            entries.sort { $0.size > $1.size }
            return Report(packageURL: packageURL, name: displayName, entries: entries, didReadConfiguration: true)
        }.value
    }

    /// Analyzes every bundle, in order.
    static func analyzeAll(packageURLs: [URL]) async -> [Report] {
        var reports: [Report] = []
        for url in packageURLs {
            reports.append(await analyze(packageURL: url))
        }
        return reports
    }

    // MARK: - Classification

    private static func classify(
        url: URL,
        referenced: Set<String>,
        snapshotIdentifiers: Set<String>,
        suspendIdentifier: String?
    ) -> FileKind {
        let name = url.lastPathComponent

        if referenced.contains(name) {
            return .inUse
        }

        // A snapshot file is named after the image it belongs to plus an
        // identifier: `<image>.<identifier>` for a saved state or a layer. With
        // a readable manifest the identifiers are known; without one every name
        // of that shape is kept, because mistaking a snapshot for a leftover is
        // the one error the user cannot undo.
        var identifiers = snapshotIdentifiers
        if let suspendIdentifier = suspendIdentifier {
            identifiers.insert(suspendIdentifier)
        }
        if !identifiers.isEmpty {
            for identifier in identifiers where name.hasSuffix("." + identifier) {
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
