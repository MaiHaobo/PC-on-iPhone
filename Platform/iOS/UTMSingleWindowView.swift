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

/// The launch animation: three concentric rounded squares that spin their
/// corners off their common axis, ending as offset outlines.
///
/// Drawn as vectors rather than played as a clip so it stays crisp at every
/// screen size, costs no bundle weight, and follows the system appearance —
/// white lines on black in dark mode, the inverse in light.
///
/// Only a cold launch shows this: `SplashHost` keeps its `@State` for the
/// process lifetime, so returning from the background goes straight to the
/// UI. Reduce Motion skips the choreography and holds a still frame instead.
struct SplashView: View {
    /// Called once the animation has run its course.
    var onFinished: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scattered = false

    /// Ink and paper invert with the appearance. The reference clip is the
    /// dark variant; light mode mirrors it so the animation does not flash a
    /// black card on a white system.
    private var paper: Color { colorScheme == .dark ? .black : .white }
    private var ink: Color { colorScheme == .dark ? .white : .black }

    private let side: CGFloat = 108

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()

            ZStack {
                ring(index: 0)
                ring(index: 1)
                ring(index: 2)
                Circle()
                    .fill(ink)
                    .frame(width: 9, height: 9)
                    .opacity(scattered ? 0 : 1)
            }
            .frame(width: side * 2, height: side * 2)
        }
        .task {
            guard !reduceMotion else {
                try? await Task.sleep(nanoseconds: 400_000_000)
                onFinished()
                return
            }
            // Let the first frame land before starting, otherwise the opening
            // animation tick competes with the window becoming visible.
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) {
                scattered = true
            }
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            onFinished()
        }
    }

    /// One nested rounded square. The scattered state is pure geometry: each
    /// ring rotates a little further than the one inside it and slides
    /// down-left, so the group fans out the way overlapping cards would.
    private func ring(index: Int) -> some View {
        let shrink: CGFloat = 1 - CGFloat(index) * 0.26
        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(ink, lineWidth: 7)
            .frame(width: side, height: side)
            .scaleEffect(scattered ? shrink * 1.06 : shrink)
            .rotationEffect(.degrees(scattered ? Double(index) * 7 : 0))
            .offset(x: scattered ? -CGFloat(index) * 13 : 0,
                    y: scattered ? CGFloat(index) * 17 : 0)
    }
}

/// Wraps the app's root in the launch animation.
///
/// The flag lives on a view that survives for the whole process, so the
/// animation runs exactly once per cold launch: backgrounding and returning
/// re-runs `body` but not the state initialiser.
struct SplashHost<Content: View>: View {
    @ViewBuilder var content: () -> Content

    /// Never reset, so the animation cannot replay when the scene comes back
    /// from the background — only a fresh process starts at `true`.
    @State private var isVisible = true

    var body: some View {
        ZStack {
            content()

            if isVisible {
                SplashView {
                    withAnimation(.easeOut(duration: 0.28)) {
                        isVisible = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
