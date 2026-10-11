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

import Foundation

extension URL {
    /// Converts a URL handed back by a document picker into one that stays
    /// readable after the picker's completion handler returns.
    ///
    /// A `UIDocumentPicker` grants access to the chosen file only for the
    /// lifetime of its completion handler. Anything that touches the URL later
    /// — a `Task.detached`, an `async` hop through a view model, a save that
    /// happens when the user taps Done minutes later — finds the grant already
    /// revoked, and `startAccessingSecurityScopedResource()` returns `false`.
    ///
    /// The fix is to take a security-scoped bookmark while the grant is still
    /// live and immediately resolve it back into a URL. The round-trip is what
    /// matters: the resolved URL carries its own scope, so it works from any
    /// context afterwards. This is the same sequence `UTMData.importUTM(from:)`
    /// performs, factored out here so the drive and wizard pickers can share it
    /// instead of each re-deriving the trick.
    ///
    /// URLs that are already inside the app's container need no bookmark —
    /// they are readable unconditionally — so they pass through untouched.
    /// That also avoids a pointless bookmark write for every pick out of
    /// the app's own Documents folder.
    ///
    /// - Returns: A URL that remains readable after the picker handler exits.
    /// - Throws: Whatever `bookmarkData()` or the resolver throws if the file
    ///   cannot be bookmarked (for example, if the grant really has expired).
    func withPersistedAccess() throws -> URL {
        guard isFileURL else {
            return self
        }
        // Already ours: no grant is involved, so there is nothing to preserve.
        if isContainedInAppContainer {
            return self
        }
        let isScopedAccess = startAccessingSecurityScopedResource()
        defer {
            if isScopedAccess {
                stopAccessingSecurityScopedResource()
            }
        }
        let bookmark = try persistentBookmarkData()
        return try URL(resolvingPersistentBookmarkData: bookmark)
    }

    /// `true` when the receiver already sits inside this app's container.
    ///
    /// Compares resolved paths rather than raw strings so symlinked temp
    /// directories (`/private/var/...` vs `/var/...`) do not read as outside
    /// the container and trigger an unnecessary bookmark.
    private var isContainedInAppContainer: Bool {
        guard let container = FileManager.default.urls(for: .documentDirectory,
                                                       in: .userDomainMask).first else {
            return false
        }
        let containerPath = container.resolvingSymlinksInPath().path
        let ownPath = resolvingSymlinksInPath().path
        return ownPath == containerPath || ownPath.hasPrefix(containerPath + "/")
    }
}
