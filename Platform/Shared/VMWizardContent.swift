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
/// Every wizard page wraps its body in this view, so each page is just a list
/// of `Section`s and the scaffold owns the title and the step indicator.
///
/// The content is a `List`, not a `ScrollView`: a list is what gives the pages
/// their grouped appearance and their row separators, and — importantly — it is
/// a stock container, so the system gives it its normal background material on
/// every OS version without the wizard painting anything itself. Pages supply
/// `Section`s with `header:`/`footer:`, exactly as they did before the card
/// redesign, which keeps them consistent with the rest of the app.
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
        #if os(macOS)
        Text(titleKey)
            .font(.largeTitle)
        #endif
        List {
            if let page = page {
                Section {
                    WizardProgressBar(page: page)
                }
            }
            #if os(macOS)
            if #available(macOS 13, *) {
                content.listRowSeparator(.hidden)
            } else {
                content
            }
            #else
            content
            #endif
        }
        #if os(iOS) || os(visionOS)
        .navigationTitle(Text(titleKey))
        #endif
    }
}

struct VMWizardContent_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VMWizardContent("Test", page: .hardware) {
                Section {
                    Text("Test 1")
                    Text("Test 2")
                } header: {
                    Text("Section")
                }
            }
        }
    }
}
