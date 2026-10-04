//
// Copyright © 2022 osy. All rights reserved.
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
import InAppSettingsKit

struct IASKAppSettings: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> IASKAppSettingsViewController {
        let vc = IASKAppSettingsViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: IASKAppSettingsViewController, context: Context) {
        uiViewController.neverShowPrivacySettings = !context.environment.showPrivacyLink
        uiViewController.showCreditsFooter = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Handles custom buttons declared in Settings.bundle (IASKButtonSpecifier).
    ///
    /// InAppSettingsKit 3.x declares the callbacks in `IASKSettingsDelegate`
    /// (bridged from Objective-C, assigned via `IASKAppSettingsViewController.delegate`).
    final class Coordinator: NSObject, IASKSettingsDelegate {
        func settingsViewController(_ settingsViewController: IASKAppSettingsViewController, buttonTappedFor specifier: IASKSpecifier) {
            guard specifier.key == "clear_cache_button" else { return }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let size = formatter.string(fromByteCount: AppCacheCleaner.totalSize())
            let alert = UIAlertController(
                title: NSLocalizedString("Clear Cache?", comment: "Settings"),
                message: String(format: NSLocalizedString("This will delete %@ of temporary files from the app cache. Virtual machines are not affected. Close any running virtual machines first.", comment: "Settings"), size),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("Clear", comment: "Settings"), style: .destructive) { _ in
                let freed = AppCacheCleaner.clear()
                let done = UIAlertController(
                    title: NSLocalizedString("Cache Cleared", comment: "Settings"),
                    message: String(format: NSLocalizedString("Freed %@.", comment: "Settings"), formatter.string(fromByteCount: freed)),
                    preferredStyle: .alert
                )
                done.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Settings"), style: .default))
                settingsViewController.present(done, animated: true)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Settings"), style: .cancel))
            settingsViewController.present(alert, animated: true)
        }
    }
}

/// Computes and removes the contents of the app's cache directories
/// (`Caches` and `tmp`). Virtual machine data lives in `Documents` and is
/// never touched.
enum AppCacheCleaner {
    static var cacheDirectories: [URL] {
        let fileManager = FileManager.default
        var urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        urls.append(fileManager.temporaryDirectory)
        return urls
    }

    /// Recursively sums the size of regular files under `url`.
    static func size(of url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
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

    static func totalSize() -> Int64 {
        cacheDirectories.reduce(0) { $0 + size(of: $1) }
    }

    /// Removes every top-level item in the cache directories.
    /// - Returns: The number of bytes freed.
    @discardableResult
    static func clear() -> Int64 {
        let fileManager = FileManager.default
        var freed: Int64 = 0
        for directory in cacheDirectories {
            let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for item in contents {
                freed += size(of: item)
                try? fileManager.removeItem(at: item)
            }
        }
        return freed
    }
}

private struct AppSettingsShowPrivacyLinkKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var showPrivacyLink: Bool {
        get { self[AppSettingsShowPrivacyLinkKey.self] }
        set { self[AppSettingsShowPrivacyLinkKey.self] = newValue }
    }
}

extension View {
    func appSettingsShowPrivacyLink(_ showPrivacyLink: Bool) -> some View {
        environment(\.showPrivacyLink, showPrivacyLink)
    }
}

struct IASKAppSettings_Previews: PreviewProvider {
    static var previews: some View {
        IASKAppSettings()
    }
}
