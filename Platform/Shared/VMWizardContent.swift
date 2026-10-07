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
/// rather than the previous `List`: the pages are now built from cards and
/// grouped rows with their own chrome, which a `List` would fight by imposing
/// row backgrounds, insets and separators on each child.
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
                    Divider()
                }
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        #if os(macOS)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text(titleKey)
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        #else
        .navigationTitle(Text(titleKey))
        #endif
    }
}

#Preview {
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
}
