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

struct BusyIndicator: View {
    @Binding var progress: Float?

    init(progress: Binding<Float?> = .constant(nil)) {
        _progress = progress
    }

    var body: some View {
        // The system control, nothing else: a determinate circular progress
        // view when a fraction is known, the plain spinner otherwise. The
        // hand-drawn grey card around it is gone — hosts already present the
        // overlay against their own chrome, and the boxed look read as a
        // custom widget rather than system UI.
        if let progress = progress {
            ProgressView(value: Double(progress))
                .progressViewStyle(.circular)
                .controlSize(.large)
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

struct BusyIndicator_Previews: PreviewProvider {
    static var previews: some View {
        BusyIndicator()
    }
}
