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

struct FileBrowseField: View {
    let titleKey: LocalizedStringKey
    @Binding var url: URL?
    @Binding var isFileImporterPresented: Bool
    let hasClearButton: Bool
    let onBrowse: () -> Void

    /// Set to `true` while the fix for the SwiftUI importer bug is being applied.
    ///
    /// See `VMRemovableDrivesView` for the full write-up. In short: tapping
    /// outside the importer dismisses it without clearing the `isPresented`
    /// binding, so the next tap toggles a flag that is already `true` and
    /// nothing presents. The drive list works around that by forcing the flag
    /// back to `false` first and re-presenting on the following runloop tick;
    /// the wizards need the same treatment, and they get it through this flag.
    @State private var workaroundFileImporterBug: Bool = false

    init(_ titleKey: LocalizedStringKey = "Path", url: Binding<URL?>, isFileImporterPresented: Binding<Bool>, hasClearButton: Bool = true, onBrowse: @escaping () -> Void = {}) {
        self.titleKey = titleKey
        self._url = url
        self._isFileImporterPresented = isFileImporterPresented
        self.hasClearButton = hasClearButton
        self.onBrowse = onBrowse
    }

    /// Presents the importer, routing around the stale-binding bug.
    ///
    /// A plain `toggle()` is not enough: once the bug has left the binding stuck
    /// at `true`, toggling it flips it to `false` and no picker ever appears — the
    /// "tap does nothing" symptom. Resetting to `false` *first* and only
    /// re-presenting on the next tick guarantees the state actually changes.
    private func presentImporter() {
        onBrowse()
        if isFileImporterPresented {
            isFileImporterPresented = false
            workaroundFileImporterBug = true
        } else {
            isFileImporterPresented = true
        }
    }

    var body: some View {
        #if os(macOS)
        HStack {
            TextField(titleKey, text: .constant(url?.lastPathComponent ?? ""))
                .truncationMode(.head)
                .disabled(true)
            if hasClearButton {
                Button {
                    url = nil
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
            }
            Button {
                presentImporter()
            } label: {
                Label("Browse…", systemImage: "folder")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(titleKey)
        #else
        if let path = url?.path {
            Text(path)
                .lineLimit(1)
                .truncationMode(.head)
        } else {
            Text(titleKey)
                .foregroundColor(.secondary)
        }
        if hasClearButton {
            Button {
                url = nil
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
        }
        Button {
            presentImporter()
        } label: {
            Label("Browse…", systemImage: "folder")
        }
        .onChange(of: workaroundFileImporterBug) { doWorkaround in
            /// Explanation see "SwiftUI FileImporter modal bug" in `presentImporter()`
            if doWorkaround {
                DispatchQueue.main.async {
                    workaroundFileImporterBug = false
                    isFileImporterPresented = true
                }
            }
        }
        #endif
    }
}

struct FileBrowseField_Previews: PreviewProvider {
    static var previews: some View {
        FileBrowseField(url: .constant(URL(fileURLWithPath: "/")), isFileImporterPresented: .constant(false))
    }
}
