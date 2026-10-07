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

/// Step indicator for the new-VM wizard.
///
/// This is the one piece of the wizard that is not a stock control: the flow
/// has five conceptual stages but the pages are navigated with a plain
/// `NavigationStack`, so nothing in the system reflects "step 3 of 5". It is
/// drawn with system colours and fonts, and lives in its own `List` section so
/// the list's own material and separators apply to it like any other row.
///
/// Everything else in the wizard is a stock control — `Section`, `Toggle`,
/// `Picker`, `Stepper`, toolbar buttons — so the system styles it, including
/// the automated appearance the platform applies to lists and navigation bars.
///
/// `VMWizardState` is untouched by this file.

// MARK: - Step model

/// The five user-visible stages of the wizard. Deliberately *not*
/// `VMWizardPage`: that enum has one case per screen (including the four
/// mutually exclusive boot pages), whereas the progress bar describes the
/// conceptual stages a user walks through. Keeping them separate means adding a
/// boot page never changes the step count.
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

// MARK: - Progress row

/// A slim progress track plus a caption, laid out as a list row.
///
/// Styled after the system's own progress affordances: one continuous track
/// with a filled accent portion and a thin callout, rather than a row of
/// detached segments. The track is 4pt tall, the height the system uses for its
/// thin bars, and the fill is the standard accent colour.
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
        .padding(.vertical, 2)
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
