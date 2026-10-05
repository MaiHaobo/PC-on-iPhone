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

struct UTMSettingsView: View {
    /// `true` when shown as a modal sheet (has a "Close" button),
    /// `false` when hosted as the root of a tab (nothing to close).
    var isPresentedAsSheet: Bool = true

    /// Shared between the two columns: the left column hands a settings pane to
    /// the navigation controller owned by the right column.
    @StateObject private var navigationModel = SettingsNavigationModel()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>

    private var hasContainer: Bool {
        #if WITH_JIT
        jb_has_container()
        #else
        true
        #endif
    }

    var body: some View {
        // Two-column layout mirroring the VM list screen: the left column holds
        // the settings list, the right column shows whatever pane the user
        // drills into (Cache, License, …).
        //
        // `IASKAppSettingsViewController` pushes its child panes through its own
        // `navigationController` and exposes no hook to intercept that, so it is
        // given an `InterceptingNavigationController` which diverts every pushed
        // pane to the right column instead of stacking it on the list.
        Group {
            if #available(iOS 16, *) {
                NavigationSplitView {
                    SettingsListColumn(isPresentedAsSheet: isPresentedAsSheet,
                                       hasContainer: hasContainer,
                                       onClose: { presentationMode.wrappedValue.dismiss() })
                        .environmentObject(navigationModel)
                } detail: {
                    SettingsDetailColumn()
                        .environmentObject(navigationModel)
                }
                .navigationSplitViewStyle(.balanced)
                // The split view shows both columns only at regular width;
                // keep the interception logic in sync with that.
                .onAppear { navigationModel.isDetachedDetailVisible = isRegularWidth }
                .onChange(of: horizontalSizeClass) { _ in
                    navigationModel.isDetachedDetailVisible = isRegularWidth
                }
            } else {
                NavigationView {
                    SettingsListColumn(isPresentedAsSheet: isPresentedAsSheet,
                                       hasContainer: hasContainer,
                                       onClose: { presentationMode.wrappedValue.dismiss() })
                        .environmentObject(navigationModel)
                    SettingsDetailColumn()
                        .environmentObject(navigationModel)
                }
            }
        }
    }

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
}

/// Shared bridge between the settings list and the detail column.
final class SettingsNavigationModel: ObservableObject {
    /// Navigation controller hosted by the detail column; receives the panes
    /// that InAppSettingsKit tries to push. Created up-front so the left column
    /// can always reach it, regardless of view-update ordering.
    let detailNavigation: UINavigationController

    /// `true` only while the detail column is actually on screen next to the
    /// list. When it is collapsed (iPhone portrait) the left column must keep
    /// pushing panes normally, otherwise they would be pushed into an
    /// off-screen navigation controller and appear to do nothing.
    @Published var isDetachedDetailVisible = false

    init() {
        let nav = UINavigationController()
        nav.navigationBar.prefersLargeTitles = false
        detailNavigation = nav
    }
}

// MARK: - Left column

/// Wraps `IASKAppSettingsViewController` so that its child-pane navigation is
/// redirected into the detail (right) column.
private struct SettingsListColumn: UIViewControllerRepresentable {
    let isPresentedAsSheet: Bool
    let hasContainer: Bool
    let onClose: () -> Void

    @EnvironmentObject private var navigationModel: SettingsNavigationModel

    func makeUIViewController(context: Context) -> InterceptingNavigationController {
        let settings = IASKAppSettingsViewController()
        settings.delegate = context.coordinator
        settings.neverShowPrivacySettings = !hasContainer
        settings.showCreditsFooter = false
        settings.navigationItem.title = NSLocalizedString("Settings", comment: "")
        settings.navigationItem.largeTitleDisplayMode = .never
        if isPresentedAsSheet {
            settings.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: NSLocalizedString("Close", comment: ""),
                style: .plain,
                target: context.coordinator,
                action: #selector(Coordinator.close)
            )
        }

        let nav = InterceptingNavigationController(rootViewController: settings)
        nav.navigationBar.prefersLargeTitles = false
        // Divert every pane IASK pushes to the detail column, but only when the
        // two columns are actually visible side by side. In a collapsed layout
        // (iPhone portrait) the detail column is off-screen, so the pane would
        // become unreachable — fall back to the standard push in that case.
        nav.onPush = { [weak navigationModel] viewController in
            guard let navigationModel, navigationModel.isDetachedDetailVisible else {
                return false  // no visible detail column: normal push
            }
            navigationModel.detailNavigation.pushViewController(viewController, animated: true)
            return true
        }
        context.coordinator.onClose = onClose
        return nav
    }

    func updateUIViewController(_ uiViewController: InterceptingNavigationController, context: Context) {
        guard let settings = uiViewController.viewControllers.first as? IASKAppSettingsViewController else {
            return
        }
        settings.neverShowPrivacySettings = !hasContainer
        settings.showCreditsFooter = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, IASKSettingsDelegate {
        var onClose: (() -> Void)?

        func settingsViewControllerDidEnd(_ settingsViewController: IASKAppSettingsViewController) {
        }

        @objc func close() {
            onClose?()
        }
    }
}

/// A `UINavigationController` that lets a closure decide what happens to pushed
/// view controllers. Returning `true` from `onPush` suppresses the standard
/// push, which is how InAppSettingsKit's child panes are diverted.
final class InterceptingNavigationController: UINavigationController {
    var onPush: ((UIViewController) -> Bool)?

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if let onPush, onPush(viewController) {
            return
        }
        super.pushViewController(viewController, animated: animated)
    }
}

// MARK: - Right column

/// Hosts the diverted settings pane. Empty (grouped background) until the user
/// opens one, matching the system Settings app.
private struct SettingsDetailColumn: View {
    @EnvironmentObject private var navigationModel: SettingsNavigationModel

    var body: some View {
        NavigationControllerView(navigationController: navigationModel.detailNavigation)
    }
}

/// Bridges an externally created `UINavigationController` into SwiftUI.
private struct NavigationControllerView: UIViewControllerRepresentable {
    let navigationController: UINavigationController

    func makeUIViewController(context: Context) -> UINavigationController {
        navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
}

struct UTMSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UTMSettingsView()
    }
}
