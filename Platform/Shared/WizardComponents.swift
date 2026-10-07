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

/// Shared presentation pieces for the new-VM wizard.
///
/// The wizard used to be built out of plain `List` rows: a title, a sentence,
/// and a control, all with identical weight, so every page read as an
/// undifferentiated wall of text and the user had no sense of how far along
/// they were. These three components give the wizard a consistent visual
/// language — a step indicator, tappable cards for choices, and labelled rows
/// for settings — without touching `VMWizardState`, which still drives page
/// order and validation exactly as before.

// MARK: - Cross-platform surface colours

/// Semantic colours for the card surfaces. The wizard runs on iOS, macOS and
/// visionOS, so the UIKit/AppKit distinction has to be made somewhere; keeping
/// it here means the components themselves stay platform-agnostic.
extension Color {
    /// Background for a card sitting on the grouped page background.
    static var wizardCardSurface: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemGroupedBackground)
        #endif
    }

    /// Hairline border drawn around cards.
    static var wizardCardBorder: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(UIColor.separator).opacity(0.5)
        #endif
    }
}

// MARK: - Step indicator

/// The five user-visible stages of the wizard, used only for the progress
/// indicator. This is deliberately *not* `VMWizardPage`: that enum has one case
/// per screen (including the four mutually exclusive boot pages), whereas the
/// progress bar describes the conceptual stages a user walks through. Keeping
/// them separate means adding a boot page never changes the step count.
enum WizardStep: Int, CaseIterable {
    case system
    case hardware
    case storage
    case sharing
    case summary

    var title: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .hardware: return "Hardware"
        case .storage: return "Storage"
        case .sharing: return "Sharing"
        case .summary: return "Summary"
        }
    }

    /// Maps a wizard page onto the stage it belongs to. The entry page counts
    /// as the first step because it is where the OS choice is made.
    static func step(for page: VMWizardPage) -> WizardStep {
        switch page {
        case .start, .operatingSystem:
            return .system
        case .hardware:
            return .hardware
        case .drives:
            return .storage
        case .sharing:
            return .sharing
        case .summary:
            return .summary
        case .macOSBoot, .linuxBoot, .windowsBoot, .classicMacOSBoot, .otherBoot:
            // Boot pages are part of choosing/running the OS, and precede
            // storage, so they read as the back half of the system step.
            return .system
        }
    }
}

/// A segmented bar plus "Step N of 5 · Title" caption, shown under the
/// navigation title on every wizard page.
struct WizardProgressBar: View {
    let page: VMWizardPage

    private var step: WizardStep { WizardStep.step(for: page) }

    private var stepNumber: Int { step.rawValue + 1 }

    private var totalSteps: Int { WizardStep.allCases.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(WizardStep.allCases, id: \.rawValue) { candidate in
                    Capsule()
                        .fill(candidate.rawValue <= step.rawValue
                              ? Color.accentColor
                              : Color.secondary.opacity(0.22))
                        .frame(height: 3)
                }
            }
            Text(stepCaption)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(stepCaption))
    }

    private var stepCaption: String {
        let format = NSLocalizedString("Step %lld of %lld · %@",
                                       comment: "VMWizardProgressBar")
        return String(format: format, stepNumber, totalSteps,
                      step.title.localizedString)
    }
}

// MARK: - Choice card

/// A large tappable card used for the mutually exclusive choices the wizard
/// asks for (OS, engine, machine type). Shows an icon, a title, an optional
/// subtitle, and draws a selection ring when chosen.
///
/// The whole card is the hit target, which is the main usability win over the
/// old `.inList` rows: on a phone the previous rows were only tappable on the
/// text itself.
struct WizardCard<Icon: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var isSelected: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void
    let icon: () -> Icon

    init(title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         isSelected: Bool = false,
         isEnabled: Bool = true,
         action: @escaping () -> Void,
         @ViewBuilder icon: @escaping () -> Icon) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.action = action
        self.icon = icon
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                icon()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.body)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(WizardCardButtonStyle(isSelected: isSelected,
                                           isEnabled: isEnabled))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Card chrome: rounded surface, hairline border, accent ring when selected.
private struct WizardCardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.wizardCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor
                                             : Color.wizardCardBorder,
                                  lineWidth: isSelected ? 2 : 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Setting row

/// One labelled setting inside a grouped card: leading icon, title, optional
/// subtitle, and a trailing control supplied by the caller.
struct WizardRow<Control: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let systemImage: String
    let control: () -> Control

    init(_ title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         systemImage: String,
         @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.control = control
    }

    /// Convenience for subtitles that are only known at runtime (a formatted
    /// byte count, a slug, a machine identifier). Those must not go through
    /// localization lookup, so they are wrapped as a pre-resolved key.
    init(_ title: LocalizedStringKey,
         subtitle: String,
         systemImage: String,
         @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.subtitle = LocalizedStringKey(subtitle)
        self.systemImage = systemImage
        self.control = control
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17))
                .foregroundColor(.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

/// Groups `WizardRow`s into a single rounded card with hairline separators,
/// so a page of settings reads as a few blocks instead of a long list.
struct WizardCardGroup<Content>: View where Content: View {
    let title: LocalizedStringKey?
    let footer: LocalizedStringKey?
    let content: Content

    init(_ title: LocalizedStringKey? = nil,
         footer: LocalizedStringKey? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
            }
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.wizardCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.wizardCardBorder, lineWidth: 1)
            )
            if let footer = footer {
                Text(footer)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A switch row with the same leading icon/title/subtitle layout as
/// `WizardRow`. `Toggle` needs to own the whole row so the switch sits at the
/// trailing edge and the entire row toggles, which is why this is a separate
/// view rather than a `WizardRow` with the switch passed in as a control.
struct WizardToggleRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    let systemImage: String
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey,
         subtitle: LocalizedStringKey? = nil,
         systemImage: String,
         isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17))
                    .foregroundColor(.accentColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        #if os(iOS)
        .toggleStyle(.switch)
        #endif
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }
}

/// Hairline separator sized to line up with `WizardRow` labels (i.e. inset
/// past the icon column).
struct WizardRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 52)
    }
}
