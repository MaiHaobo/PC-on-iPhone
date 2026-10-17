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
        // These are the system Settings hues rather than SwiftUI's generic
        // `.yellow` / `.mint` / `.teal`, which are noticeably paler. Settings
        // chips are deeper so white glyphs stay legible at 17pt.
        // Red appears twice on purpose: the system reuses the same warm red
        // for destructive rows and for its media category.
        case .general:    return Color(red: 0.557, green: 0.557, blue: 0.576) // systemGray
        case .background: return Color(red: 0.000, green: 0.478, blue: 1.000) // systemBlue
        case .idle:       return Color(red: 0.686, green: 0.322, blue: 0.871) // systemPurple
        case .storage:    return Color(red: 0.188, green: 0.690, blue: 0.780) // systemTeal
        case .about:      return Color(red: 0.345, green: 0.337, blue: 0.839) // systemIndigo
        case .devices:    return Color(red: 0.204, green: 0.780, blue: 0.349) // systemGreen
        case .graphics:   return Color(red: 1.000, green: 0.584, blue: 0.000) // systemOrange
        case .gestures:   return Color(red: 1.000, green: 0.176, blue: 0.333) // systemPink
        case .cursor:     return Color(red: 0.196, green: 0.678, blue: 0.902) // systemCyan
        case .gamepad:    return Color(red: 0.000, green: 0.780, blue: 0.745) // systemMint (deepened)
        case .network:    return Color(red: 0.000, green: 0.478, blue: 1.000) // systemBlue
        case .drives:     return Color(red: 1.000, green: 0.800, blue: 0.000) // systemYellow
        case .danger:     return Color(red: 1.000, green: 0.231, blue: 0.188) // systemRed
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
///
/// Geometry matches the system Settings app: a 29pt square with a 7pt
/// continuous corner radius and a ~17pt glyph, so a row here sits at the same
/// weight as a row in Settings.
///
/// The fill is a flat, saturated colour in both light and dark mode. An earlier
/// version used `.glassEffect(...)` on iOS 26 in the belief that system icons
/// were glassy; they are not. Real Settings rows are solid colour chips, and
/// tinting glass with the category colour desaturates it into a muddy grey —
/// most obvious on yellow and mint, which read as beige and sage.
struct SettingsIconBadge<Glyph: View>: View {
    var tint: SettingsIconTint
    var size: CGFloat = 29
    var cornerRadius: CGFloat = 7
    @ViewBuilder var glyph: () -> Glyph

    var body: some View {
        glyph()
            .font(.system(size: size * 0.6, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(fill,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .compositingGroup()
            // The badge is decorative; VoiceOver should read the row title and
            // value, not a colour name or a glyph.
            .accessibilityHidden(true)
    }

    /// `Color.gradient` is iOS 16+, and this app still deploys to 15, so the
    /// two-stop gradient is spelled out. The slight darkening towards the
    /// bottom is what keeps the chips from reading as flat stickers.
    private var fill: LinearGradient {
        LinearGradient(colors: [tint.color.opacity(0.92), tint.color],
                       startPoint: .top,
                       endPoint: .bottom)
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
