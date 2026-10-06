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
/// Confirmation actions used to draw a hand-rolled blue shape behind the
/// glyph, which meant their metrics (corner radius, glyph weight, hit area)
/// had to be maintained by hand and drifted from what the system does. They
/// now use the native `borderedProminent` button style instead: SwiftUI
/// supplies the blue fill, the white foreground, the corner rounding and a
/// 44pt-class hit target, and the result adapts automatically to platform,
/// Dynamic Type and accessibility settings.
///
/// Usage:
/// ```swift
/// ConfirmationButton("Save") { save() }          // prominent blue, white checkmark
/// ```
///
/// The `ConfirmationIcon` shim is kept for call sites that need the bare
/// glyph rendered inside their own `Button` (for example when the button must
/// carry a `disabled(_:)` modifier):
/// ```swift
/// Button(action: save) { ConfirmationIcon() }
///     .buttonStyle(.borderedProminent)
/// ```
struct ConfirmationIcon: View {
    /// Glyph drawn on top of the prominent fill. Rendered in the style's
    /// foreground colour (white), so no explicit colour is applied here.
    var systemName: String = "checkmark"
    /// Point size of the glyph.
    var pointSize: CGFloat = 17
    /// Additional horizontal padding for callers that want a wider capsule.
    var horizontalPadding: CGFloat = 4
    /// Additional vertical padding for callers that want a taller capsule.
    var verticalPadding: CGFloat = 4

    var body: some View {
        Image(systemName: systemName)
            // `.fontWeight(_:)` is iOS 16+; the deployment target is iOS 15,
            // so weight is applied through the font descriptor instead.
            .font(.system(size: pointSize, weight: .semibold))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }
}

/// A navigation-bar button that matches `ConfirmationIcon`.
///
/// Uses the native prominent button style so the blue fill and white glyph
/// come from SwiftUI rather than from custom drawing, and exposes the
/// localised text as the accessibility label so VoiceOver keeps announcing
/// "Save"/"Done" even though the visible title is gone.
struct ConfirmationButton: View {
    let title: LocalizedStringKey
    let systemName: String
    let pointSize: CGFloat
    let action: () -> Void

    init(_ title: LocalizedStringKey,
         systemName: String = "checkmark",
         pointSize: CGFloat = 17,
         action: @escaping () -> Void) {
        self.title = title
        self.systemName = systemName
        self.pointSize = pointSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ConfirmationIcon(systemName: systemName, pointSize: pointSize)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel(Text(title))
    }
}
