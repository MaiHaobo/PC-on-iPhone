//
// Copyright © 2023 osy. All rights reserved.
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

/// Page scaffold for the new-VM wizard.
///
/// Every wizard page wraps its body in this view so the step indicator and the
/// page title sit in the same place throughout. The content is a `ScrollView`
/// rather than a `List`: the pages are built from grouped cards with their own
/// chrome, which a `List` would fight by imposing row backgrounds, insets and
/// separators on each child. The grouped page background is painted explicitly
/// so the cards land on the same colour the Settings app uses.
struct VMWizardContent<Content>: View where Content: View {
    let titleKey: LocalizedStringKey
    var page: VMWizardPage?
    let content: Content

    init(_ titleKey: LocalizedStringKey,
         page: VMWizardPage? = nil,
         @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.page = page
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let page = page {
                    WizardProgressBar(page: page)
                }
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(.horizontal, WizardMetrics.cardInset)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.wizardPageBackground)
        #if os(macOS)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text(titleKey)
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WizardMetrics.cardInset)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
        #else
        .navigationTitle(Text(titleKey))
        #endif
    }
}

/// Pins the page's primary action above the home indicator, the way the system
/// setup assistants do, so the button is always reachable with a thumb and
/// never scrolls out of view.
///
/// This is a standalone modifier rather than a parameter on `VMWizardContent`
/// so that pages which have no action (the entry page, the boot pages) keep the
/// exact same call site as the ones that do.
struct WizardBottomAction<BarContent: View>: ViewModifier {
    @ViewBuilder let content: () -> BarContent

    func body(content original: Content) -> some View {
        original.safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                content()
                    .padding(.horizontal, WizardMetrics.cardInset)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
            }
            .background(.bar)
        }
    }
}

extension View {
    /// Adds the pinned bottom action bar. The caller supplies the button; this
    /// only handles the rule, the material background and the insets so every
    /// page's action lines up identically.
    func wizardBottomAction<BarContent: View>(
        @ViewBuilder content: () -> BarContent
    ) -> some View {
        modifier(WizardBottomAction(content: content))
    }
}

/// The footer's primary button, styled once so every page's action is the same
/// size and shape: a full-width prominent button, which is what the system uses
/// for a flow's main affirmative action.
struct WizardPrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isBusy: Bool = false
    let action: () -> Void

    init(_ title: LocalizedStringKey,
         systemImage: String? = nil,
         isBusy: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isBusy = isBusy
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isBusy)
    }
}

#Preview {
    NavigationStack {
        VMWizardContent("Test", page: .hardware) {
            WizardCardGroup("Section") {
                WizardRow("Memory", systemImage: "memorychip") {
                    Text("2 GB").foregroundColor(.secondary)
                }
                WizardRowDivider()
                WizardRow("CPU Cores", systemImage: "cpu") {
                    Text("4").foregroundColor(.secondary)
                }
            }
        }
        .wizardBottomAction {
            WizardPrimaryButton("Continue") {}
        }
    }
}
