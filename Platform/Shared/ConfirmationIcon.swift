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

/// The app-wide style for "confirm" buttons in navigation bars.
///
/// A bare `checkmark` glyph is hard to read at toolbar size and gives no
/// affordance that it is tappable. Every confirm button therefore draws the
/// same treatment the settings rows already use: a blue filled rounded
/// rectangle with a white glyph on top. Keeping it in one place means the
/// Save/Done buttons across the app (settings, drives, keyboard shortcuts,
/// wizard) can never drift apart.
///
/// Usage:
/// ```swift
/// Button(action: save) {
///     ConfirmationIcon()          // blue rounded square + white checkmark
/// }
/// ```
struct ConfirmationIcon: View {
    /// Glyph drawn in white on top of the blue fill.
    var systemName: String = "checkmark"
    /// Side length of the rounded square.
    var size: CGFloat = 28
    /// Fill colour. Confirmation actions are blue throughout the app.
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .circular)
                .fill(color)
                .frame(width: size, height: size)
            Image(systemName: systemName)
                .font(.system(size: size * 0.56, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

/// A navigation-bar button that matches `ConfirmationIcon`.
///
/// Wraps the icon in a plain `Button` and adds the localised text as the
/// accessibility label, so VoiceOver keeps announcing "Save"/"Done" even
/// though the visible title is gone.
struct ConfirmationButton: View {
    let title: LocalizedStringKey
    let systemName: String
    let size: CGFloat
    let action: () -> Void

    init(_ title: LocalizedStringKey,
         systemName: String = "checkmark",
         size: CGFloat = 28,
         action: @escaping () -> Void) {
        self.title = title
        self.systemName = systemName
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ConfirmationIcon(systemName: systemName, size: size)
        }
        .accessibilityLabel(Text(title))
    }
}
