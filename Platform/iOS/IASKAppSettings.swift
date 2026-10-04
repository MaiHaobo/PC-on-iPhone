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

    /// InAppSettingsKit requires a delegate to be assigned; `IASKSettingsDelegate`
    /// has exactly one @required member (`settingsViewControllerDidEnd`), which is
    /// a no-op here because the settings sheet is dismissed by the SwiftUI "Close"
    /// button. Custom rows (such as the Cache screen) are implemented as
    /// `IASKCustomViewSpecifier` child view controllers instead of delegate calls.
    final class Coordinator: NSObject, IASKSettingsDelegate {
        func settingsViewControllerDidEnd(_ settingsViewController: IASKAppSettingsViewController) {
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

    /// Known cache categories, matched by the name of the top-level item inside
    /// the cache directories. Anything unmatched is reported as "Other".
    private static let knownCategories: [(title: String, names: [String])] = [
        ("Downloads", ["Downloads", "com.apple.nsurlsessiond", "ipsw"]),
        ("QEMU", ["qemu"]),
    ]

    /// Breakdown of the cache by category, plus the total.
    static func breakdown() -> (total: Int64, categories: [(title: String, size: Int64)]) {
        let fileManager = FileManager.default
        var buckets: [String: Int64] = [:]
        var total: Int64 = 0
        for directory in cacheDirectories {
            let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
            for item in contents {
                let itemSize = size(of: item)
                total += itemSize
                let name = item.lastPathComponent
                let category = knownCategories.first(where: { $0.names.contains(name) })?.title ?? "Other"
                buckets[category, default: 0] += itemSize
            }
        }
        var ordered: [(String, Int64)] = []
        for category in knownCategories {
            if let value = buckets.removeValue(forKey: category.title), value > 0 {
                ordered.append((category.title, value))
            }
        }
        ordered.append(("Other", buckets["Other"] ?? 0))
        return (total, ordered)
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
