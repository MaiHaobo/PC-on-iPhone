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
/// These deliberately mirror the stock Settings app rather than inventing a
/// look: grouped cards on the system grouped background, one 10pt corner
/// radius, hairline separators that stop where the system's do, and controls
/// drawn by SwiftUI itself. The earlier revision drew its own borders, used
/// uppercase micro-headings and animated a scale on press, which made the
/// wizard read as a foreign surface next to the rest of iOS. Everything the
/// user sees now comes from system semantic colours and system control styles.
///
/// `VMWizardState` is untouched: page order, validation and navigation are
/// exactly as before.

// MARK: - Cross-platform surface colours

/// Semantic colours for grouped content. The wizard runs on iOS, macOS and
/// visionOS, so the UIKit/AppKit distinction has to be made somewhere; keeping
/// it here means the components themselves stay platform-agnostic.
extension Color {
    /// Background of a grouped card. On iOS this is the same colour the
    /// Settings app paints its cells with, so the wizard matches it exactly in
    /// both light and dark mode without hard-coding a grey.
    static var wizardCardSurface: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemGroupedBackground)
        #endif
    }

    /// Background the grouped cards sit on. iOS already paints this behind a
    /// grouped `List`; the wizard scrolls its own content, so it has to fill it
    /// in explicitly to avoid the cards floating on the default window colour.
    static var wizardPageBackground: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
}

// MARK: - Metrics

/// The measurements the stock Settings app uses. Centralised so every card
/// lines up, and so a future change lands in one place.
enum WizardMetrics {
    /// Corner radius of a grouped card. iOS grouped tables use 10pt.
    static let cornerRadius: CGFloat = 10
    /// Horizontal inset of the cards from the page edge.
    static let cardInset: CGFloat = 16
    /// Left inset of row content (icon + label).
    static let rowInset: CGFloat = 16
    /// Vertical padding inside a row.
    static let rowVerticalPadding: CGFloat = 11
    /// Width reserved for a row's leading icon so labels align in a column.
    static let iconWidth: CGFloat = 26
    /// Distance a separator is inset so it starts where the text does.
    static let separatorInset: CGFloat = 52
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

/// A slim progress track plus a caption, drawn to sit under the navigation bar.
///
/// Styled after the system's own progress affordances: a single continuous
/// track with a filled accent portion and a thin callout, rather than five
/// detached segments. The track is 4pt tall, which is the height iOS uses for
/// its own thin bars, and the fill is the standard accent colour.
struct WizardProgressBar: View {
    let page: VMWizardPage

    private var step: WizardStep { WizardStep.step(for: page) }

    private var stepNumber: Int { step.rawValue + 1 }

    private var totalSteps: Int { WizardStep.allCases.count }

    private var fraction: CGFloat {
        CGFloat(stepNumber) / CGFloat(totalSteps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(geo.size.width * fraction, 4))
                }
            }
            .frame(height: 4)

            Text(stepCaption)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, WizardMetrics.cardInset)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.25), value: stepNumber)
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

/// A tappable card used for the mutually exclusive choices the wizard asks for
/// (OS, engine, machine type).
///
/// Visually this is a plain group of rows rather than a bordered tile: leading
/// icon, title, optional subtitle, and — when selected — a stock checkmark at
/// the trailing edge, which is exactly how the Settings app marks a chosen
/// option. There is no custom border or press animation; the system's own
/// highlighted state is used instead.
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
            HStack(alignment: .center, spacing: 12) {
                icon()
                    .frame(width: WizardMetrics.iconWidth, height: WizardMetrics.iconWidth)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, WizardMetrics.rowVerticalPadding)
            .padding(.horizontal, WizardMetrics.rowInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(WizardRowButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Uses the system's own tap feedback (a grey highlight that fades out) rather
/// than a custom opacity/scale animation, which is what makes an in-app row
/// feel like a system row.
private struct WizardRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                ? Color.primary.opacity(0.08)
                : Color.clear
            )
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
                .frame(width: WizardMetrics.iconWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, WizardMetrics.rowVerticalPadding)
        .padding(.horizontal, WizardMetrics.rowInset)
    }
}

/// Groups rows into the single rounded card the Settings app uses for a block
/// of related settings. A section heading, when given, is a plain sentence-case
/// label above the card — not the uppercase micro-caps the previous revision
/// drew, which is not a style iOS uses anywhere.
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
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            VStack(spacing: 0) {
                content
            }
            .background(Color.wizardCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: WizardMetrics.cornerRadius,
                                        style: .continuous))
            if let footer = footer {
                Text(footer)
                    .font(.footnote)
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
                    .frame(width: WizardMetrics.iconWidth)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        #if os(iOS)
        .toggleStyle(.switch)
        #endif
        .padding(.vertical, WizardMetrics.rowVerticalPadding)
        .padding(.horizontal, WizardMetrics.rowInset)
    }
}

/// Hairline separator sized to line up with `WizardRow` labels (i.e. inset
/// past the icon column), matching where the Settings app stops its rules.
struct WizardRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, WizardMetrics.separatorInset)
    }
}
