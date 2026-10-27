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

@MainActor
struct UTMSingleWindowView: View {
    private var isInteractive: Bool {
        data != nil
    }

    #if WITH_REMOTE
    typealias DataType = UTMRemoteData
    #else
    typealias DataType = UTMData
    #endif
    private let data: DataType?
    @State private var session: VMSessionState?
    @State private var identifier: VMSessionState.WindowID?

    private let vmSessionCreatedNotification = NotificationCenter.default.publisher(for: .vmSessionCreated)
    private let vmSessionEndedNotification = NotificationCenter.default.publisher(for: .vmSessionEnded)
    
    init(data: DataType? = nil) {
        self.data = data
    }
    
    var body: some View {
        ZStack {
            if let session = session {
                VMWindowView(id: identifier!, isInteractive: isInteractive).environmentObject(session)
            } else if isInteractive {
                #if WITH_REMOTE
                RemoteContentView(remoteClientState: data!.remoteClient.state).environmentObject(data!)
                #else
                ContentView().environmentObject(data!)
                #endif
            } else {
                VStack {
                    Text("Waiting for VM to connect to display...")
                        .font(.headline)
                    BusyIndicator()
                }
            }
        }
        .onAppear {
            session = VMSessionState.allActiveSessions.first?.value
            if let session = session {
                identifier = session.newWindow().windowID
            }
        }
        .onReceive(vmSessionCreatedNotification) { output in
            let newSession = output.userInfo!["Session"] as! VMSessionState
            withAnimation {
                session = newSession
                identifier = newSession.newWindow().windowID
            }
        }
        .onReceive(vmSessionEndedNotification) { output in
            let endedSession = output.userInfo!["Session"] as! VMSessionState
            if endedSession == session {
                withAnimation {
                    session = nil
                }
            }
        }
    }
}

struct UTMSingleWindowView_Previews: PreviewProvider {
    static var previews: some View {
        UTMSingleWindowView(data: UTMSingleWindowView.DataType())
    }
}


// MARK: - Launch animation

/// The icon's mark, independent of any choreography: three nested rounded
/// squares around a centre dot, drawn in the current appearance's colours.
///
/// Shared by the launch animation and the JIT spinner so both stay pixel
/// -identical to the App icon — there is exactly one definition of the ring
/// ratios and colours in the app.
struct LiquidGlassMark: View {
    /// Outer ring side.
    var side: CGFloat = 108
    /// 0 = assembled (the icon itself), 1 = fully fanned out.
    var scatter: CGFloat = 0
    /// Extra rotation about the mark's centre, used by the spinner.
    var spin: Angle = .zero
    /// The centre dot is the icon's core; the spinner drops it.
    var showsDot: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    /// Colours come straight from icon.json. Light mode: blue gradient
    /// paper, white layers — exactly the rendered light icon. Dark mode:
    /// near-black paper ("system-dark"), and the layers take the icon's blue
    /// gradient, which is what the dark icon variant does.
    static let glassTop = Color(red: 0.34510, green: 0.56078, blue: 0.93725)
    static let glassBottom = Color(red: 0.00392, green: 0.00784, blue: 0.63922)
    static var glassGradient: LinearGradient {
        LinearGradient(colors: [glassTop, glassBottom],
                       startPoint: .top,
                       endPoint: .bottom)
    }

    var ink: some ShapeStyle {
        colorScheme == .dark
            ? AnyShapeStyle(Self.glassGradient)
            : AnyShapeStyle(Color.white)
    }

    /// Inner rings follow the icon's measured nesting: Ring2/Ring1 = 0.703,
    /// Ring3/Ring1 = 0.423; the stroke is ~7% of a ring's side and the centre
    /// dot ~11% of the outer side.
    private var ringSides: [CGFloat] { [side, side * 0.703, side * 0.423] }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring(index: $0) }
            Circle()
                .fill(ink)
                .frame(width: side * 0.11, height: side * 0.11)
                .opacity(showsDot ? (1 - scatter) : 0)
        }
        .frame(width: side * 2, height: side * 2)
        .rotationEffect(spin)
    }

    /// One nested rounded square. The fanned-out state is pure geometry: each
    /// ring shrinks by a step, rotates a little further than the one inside
    /// it and slides down-left, so the group fans out the way overlapping
    /// cards would.
    private func ring(index: Int) -> some View {
        let ringSide = ringSides[index] * (1 - 0.26 * scatter)
        return RoundedRectangle(cornerRadius: ringSide * 0.22, style: .continuous)
            .strokeBorder(ink, lineWidth: ringSides[index] * 0.065)
            .frame(width: ringSide, height: ringSide)
            .rotationEffect(.degrees(Double(index) * 7 * scatter))
            .offset(x: -CGFloat(index) * 13 * scatter,
                    y: CGFloat(index) * 17 * scatter)
    }
}

/// Plain colour pair for a full-bleed backdrop matching the icon.
struct LiquidGlassPaper: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark
                  ? AnyShapeStyle(Color.black)
                  : AnyShapeStyle(LiquidGlassMark.glassGradient))
            .ignoresSafeArea()
    }
}

/// The launch animation: the icon assembles, then fans the rings apart.
///
/// Drawn as vectors rather than played as a clip so it stays crisp at every
/// screen size, costs no bundle weight, and replicates the liquid-glass App
/// icon: blue-gradient paper with white layers in light mode, black paper
/// with blue-gradient layers in dark mode.
///
/// Only a cold launch shows this: `SplashHost` keeps its `@State` for the
/// process lifetime, so returning from the background goes straight to the
/// UI. Reduce Motion skips the choreography and holds a still frame instead.
struct SplashView: View {
    /// Called once the animation has run its course.
    var onFinished: () -> Void
    /// Hold the last frame instead of dismissing, so the JIT guide can hand
    /// over from the very image the launch ended on.
    var holdsLastFrame: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scattered = false

    var body: some View {
        ZStack {
            LiquidGlassPaper()
            LiquidGlassMark(scatter: scattered ? 1 : 0)
        }
        .task {
            guard !reduceMotion else {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !holdsLastFrame { onFinished() }
                return
            }
            // Let the first frame land before starting, otherwise the opening
            // animation tick competes with the window becoming visible.
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) {
                scattered = true
            }
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            if !holdsLastFrame { onFinished() }
        }
        // Re-running is harmless, but keeping this out of the initial
        // transition avoids a flash if the guide appears mid-animation.
        .onDisappear { scattered = false }
    }
}

/// Wraps the app's root in the launch animation.
///
/// The flag lives on a view that survives for the whole process, so the
/// animation runs exactly once per cold launch: backgrounding and returning
/// re-runs `body` but not the state initialiser.
///
/// When the build needs JIT and does not have it, the opening animation is
/// held on its last frame instead of dismissing, and the JIT guide fades in
/// over that same image — the rings the user just watched fan apart become
/// the spinner, so the hand-off reads as one continuous motion.
struct SplashHost<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @StateObject private var jitGuide = JITGuideCoordinator()

    /// Never reset, so the animation cannot replay when the scene comes back
    /// from the background — only a fresh process starts at `true`.
    @State private var isVisible = true

    private var needsJITGuide: Bool { JITGuideCoordinator.isNeeded }

    var body: some View {
        ZStack {
            content()

            if isVisible {
                SplashView(holdsLastFrame: needsJITGuide, onFinished: {
                    withAnimation(.easeOut(duration: 0.28)) {
                        isVisible = false
                    }
                })
                .transition(.opacity)
                .zIndex(1)
            }

            if jitGuide.isPresented {
                JITGuideView(reason: jitGuide.reason) {
                    // If the user closed the guide themselves, the launch
                    // animation must not resume underneath: it already played
                    // and is holding its last frame.
                    withAnimation(.easeOut(duration: 0.35)) {
                        jitGuide.isPresented = false
                        isVisible = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .onAppear {
            guard needsJITGuide else { return }
            jitGuide.present(reason: .launch)
        }
        // Second entry point: reaching for a new virtual machine. Every "new
        // VM" affordance funnels through `UTMData.newVM`, which posts this.
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.NewVirtualMachineRequested)) { _ in
            jitGuide.present(reason: .newVirtualMachine)
        }
    }
}
