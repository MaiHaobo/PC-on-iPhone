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

/// Icon-only replacement for `EditButton`.
///
/// Toggles the enclosing list's edit mode through the `editMode` environment,
/// exactly like the system button does, but renders an icon instead of a
/// localised text title: `arrow.up.arrow.down.circle` while inactive (the
/// mode is for reordering/deleting rows) and the app-wide blue-circle white
/// checkmark (`ConfirmationIcon`) while active (tapping again finishes
/// editing), matching the system Files app's selection-mode Done button.
struct EditToggleButton: View {
    @Environment(\.editMode) private var editMode

    private var isActive: Bool { editMode?.wrappedValue == .active }

    var body: some View {
        Button {
            switch editMode?.wrappedValue {
            case .active:
                editMode?.wrappedValue = .inactive
            default:
                editMode?.wrappedValue = .active
            }
        } label: {
            if isActive {
                ConfirmationIcon(systemName: "checkmark")
            } else {
                Image(systemName: "arrow.up.arrow.down.circle")
            }
        }
        .accessibilityLabel(Text(isActive ? "Done" : "Edit"))
    }
}
