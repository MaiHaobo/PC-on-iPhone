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

// MARK: - Settings icon tint

/// Semantic colour buckets for settings rows.
///
/// Rows pick a bucket by meaning rather than by hand-picking a `Color`, so a
/// whole category (every storage row, say) stays visually consistent even when
/// the rows live in different files or are added later.
///
/// The palette mirrors the system Settings app: a saturated hue per category,
/// consistent across light and dark. Properties are `Color` literals rather
/// than asset-catalog entries because these are decorative tints, not
/// themeable brand colours — and keeping them in code means the icon style has
/// no asset-catalog dependency to break the build.
enum SettingsIconTint {
    case general
    case background
    case idle
    case storage
    case about
    case devices
    case graphics
    case gestures
    case cursor
    case gamepad
    case network
    case drives
    case danger

    var color: Color {
        switch self {
        case .general:    return .gray
        case .background: return .blue
        case .idle:       return .purple
        case .storage:    return .teal
        case .about:      return .indigo
        case .devices:    return .green
        case .graphics:   return .orange
        case .gestures:   return .pink
        case .cursor:     return .cyan
        case .gamepad:    return .mint
        case .network:    return .blue
        case .drives:     return .yellow
        case .danger:     return .red
        }
    }
}

// MARK: - Settings icon label style

/// Draws a settings row icon the way the system Settings app does: a rounded
/// square of a category colour with the glyph knocked out in white.
///
/// On iOS 26 the square is rendered as Liquid Glass tinted with the category
/// colour — the glyph sits on real material, so it picks up the surrounding
/// blur and specular highlight, and `.interactive()` gives it the press
/// response Apple's own settings rows have. On older systems the same geometry
/// falls back to a flat fill, which is what those systems expect anyway.
///
/// The style is a `LabelStyle`, so callers keep using `Label(title, systemImage:)`
/// and simply attach `.labelStyle(.settingsIcon(.background))`. Rows that put
/// their own content in the label can instead wrap just the glyph with
/// `SettingsIconBadge`, below.
struct SettingsIconLabelStyle: LabelStyle {
    var tint: SettingsIconTint
    var size: CGFloat = 29
    var cornerRadius: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            SettingsIconBadge(tint: tint, size: size, cornerRadius: cornerRadius) {
                configuration.icon
            }
        }
    }
}

/// The rounded-square badge itself. Public so rows whose label is custom
/// (a `Toggle`, a `Picker`, a slider header) can place the glyph manually and
/// still get identical geometry and material.
struct SettingsIconBadge<Glyph: View>: View {
    var tint: SettingsIconTint
    var size: CGFloat = 29
    var cornerRadius: CGFloat = 7
    @ViewBuilder var glyph: () -> Glyph

    var body: some View {
        badge
            // The badge is decorative; VoiceOver should read the row title and
            // value, not a colour name or a glyph.
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        if #available(iOS 26, *) {
            glyph()
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .glassEffect(.regular.tint(tint.color.opacity(0.85)).interactive(),
                             in: .rect(cornerRadius: cornerRadius))
        } else {
            glyph()
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(tint.color,
                            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

extension LabelStyle where Self == SettingsIconLabelStyle {
    /// `.labelStyle(.settingsIcon(.storage))`
    static func settingsIcon(_ tint: SettingsIconTint,
                             size: CGFloat = 29,
                             cornerRadius: CGFloat = 7) -> SettingsIconLabelStyle {
        SettingsIconLabelStyle(tint: tint, size: size, cornerRadius: cornerRadius)
    }
}
