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

/// Cache management screen, pushed from the "Cache" row in Settings.
///
/// The row uses `IASKCustomViewSpecifier`, and InAppSettingsKit instantiates
/// this class by name (`IASKViewControllerClass`), so the name must stay in
/// sync with `Settings.bundle/Root.plist`.
struct VMCacheSettingsView: View {
    @State private var total: Int64 = 0
    @State private var breakdown: [(title: String, size: Int64)] = []
    @State private var isClearing = false
    @State private var alert: CacheAlert?

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private func formatted(_ bytes: Int64) -> String {
        Self.byteFormatter.string(fromByteCount: bytes)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total")
                    Spacer()
                    Text(formatted(total))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Cache Usage")
            } footer: {
                Text("Temporary files only. Virtual machines and their data are stored separately and are never affected.")
            }

            if !breakdown.isEmpty {
                Section {
                    ForEach(breakdown, id: \.title) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            Text(formatted(item.size))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Breakdown")
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmClear()
                } label: {
                    HStack {
                        Spacer()
                        if isClearing {
                            ProgressView()
                        } else {
                            Text("Clear Cache")
                        }
                        Spacer()
                    }
                }
                .disabled(total == 0 || isClearing)
            }
        }
        .navigationTitle("Cache")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .alert(item: $alert) { item in
            switch item {
            case .confirm(let size):
                return Alert(
                    title: Text("Clear Cache?"),
                    message: Text(String(format: NSLocalizedString("This will delete %@ of temporary files from the app cache. Virtual machines are not affected. Close any running virtual machines first.", comment: "Settings"), formatted(size))),
                    primaryButton: .destructive(Text("Clear")) { performClear() },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            case .result(let freed):
                return Alert(
                    title: Text("Cache Cleared"),
                    message: Text(String(format: NSLocalizedString("Freed %@.", comment: "Settings"), formatted(freed))),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func reload() {
        let data = AppCacheCleaner.breakdown()
        total = data.total
        breakdown = data.categories.filter { $0.size > 0 || $0.title != "Other" }
    }

    private func confirmClear() {
        alert = .confirm(total)
    }

    private func performClear() {
        isClearing = true
        let freed = AppCacheCleaner.clear()
        reload()
        isClearing = false
        alert = .result(freed)
    }
}

private enum CacheAlert: Identifiable {
    case confirm(Int64)
    case result(Int64)

    var id: String {
        switch self {
        case .confirm(let value): return "confirm-\(value)"
        case .result(let value): return "result-\(value)"
        }
    }
}

/// Hosting controller registered in `Settings.bundle/Root.plist` via
/// `IASKViewControllerClass`. InAppSettingsKit pushes this onto its navigation
/// stack when the user taps the "Cache" row.
///
/// InAppSettingsKit instantiates the class with `[vcClass alloc]` followed by
/// a plain no-argument `init` (unless `IASKViewControllerSelector` says
/// otherwise), so the parameterless initializer below is the required entry
/// point. `UIHostingController` does not expose `init(nibName:bundle:)` to
/// Swift subclasses, so `init(rootView:)` is called directly.
@objc(IASKCacheSettingsViewController)
final class IASKCacheSettingsViewController: UIHostingController<VMCacheSettingsView> {
    @objc init() {
        super.init(rootView: VMCacheSettingsView())
        // We never draw our own bars; the parent settings controller provides them.
        navigationItem.largeTitleDisplayMode = .never
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        // InAppSettingsKit only constructs this class programmatically.
        fatalError("init(coder:) has not been implemented")
    }
}
