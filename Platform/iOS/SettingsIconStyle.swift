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

/// Renders a settings row icon the way system apps without chips do (Mail,
/// Shortcuts): the bare SF Symbol, tinted with the row's category colour.
///
/// The Settings-app chip was tried first and abandoned: Apple does not
/// publish a template for it, so every proportion — size, radius, glyph
/// weight, gutter — was hand-tuned against screenshots and kept drifting.
/// The bare symbol is the actual system template, needs no geometry, and
/// inherits the row's dynamic-type size for free.
///
/// The style is a `LabelStyle`, so callers keep using `Label(title, systemImage:)`
/// and simply attach `.labelStyle(.settingsIcon(.background))`. Rows that put
/// their own content in the label can still wrap a glyph with
/// `SettingsIconBadge`, below.
struct SettingsIconLabelStyle: LabelStyle {
    var tint: SettingsIconTint

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            configuration.icon
                .font(.body)
                .foregroundStyle(tint.color)
        }
    }
}

struct SettingsIconBadge<Glyph: View>: View {
    var tint: SettingsIconTint
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 5.4
    @ViewBuilder var glyph: () -> Glyph

    var body: some View {
        glyph()
            .font(.system(size: size * 0.55, weight: .regular))
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
    static func settingsIcon(_ tint: SettingsIconTint) -> SettingsIconLabelStyle {
        SettingsIconLabelStyle(tint: tint)
    }
}
