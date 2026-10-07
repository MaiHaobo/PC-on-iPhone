#!/bin/bash

set -e

command -v realpath >/dev/null 2>&1 || realpath() {
	[[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}
BASEDIR="$(dirname "$(realpath $0)")"

usage() {
	echo "usage: $0 MODE inputXcarchive outputPath [TEAM_ID PROFILE_NAME SIGNING_METHOD HELPER_PROFILE_NAME]"
	echo "  MODE is one of:"
	echo "          deb (Cydia DEB)"
	echo "          ipa (unsigned IPA of full build with all entitlements)"
	echo "          ipa-se (unsigned IPA of SE build)"
	echo "          ipa-remote (unsigned IPA of Remote build)"
	echo "          ipa-hv (unsigned IPA of full build without JIT entitlement)"
	echo "          ipa-[se-|remote-]signed (signed IPA with valid PROFILE_NAME and TEAM_ID)"
	echo "  inputXcarchive is path to UTM.xcarchive"
	echo "  outputPath is path to an EMPTY output directory for UTM.ipa or UTM.deb"
	echo "  TEAM_ID is only used for ipa-signed and is the name of the team matching the profile"
	echo "  PROFILE_NAME is only used for ipa-signed and is the name of the signing profile"
	echo "  SIGNING_METHOD is only used for ipa-signed and is either 'development' (default) or 'app-store'"
	echo "  HELPER_PROFILE_NAME is only used for ipa-signed and ipa-se-signed and is the name of the signing profile of the helper extension"
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

MODE=$1
INPUT=$2
OUTPUT=$3
BUNDLE_ID=

case $MODE in
deb | ipa | ipa-signed )
	APP_NAME="UTM"
	OUTPUT_NAME="UTM"
	BUNDLE_ID="com.utmapp.poi"
	INPUT_APP="$INPUT/Products/Applications/UTM.app"
	;;
ipa-hv )
	APP_NAME="UTM"
	OUTPUT_NAME="UTM"
	BUNDLE_ID="com.utmapp.poi-HV"
	INPUT_APP="$INPUT/Products/Applications/UTM.app"
	;;
ipa-se | ipa-se-signed )
	APP_NAME="PC on iPhone SE"
	OUTPUT_NAME="UTM SE"
	BUNDLE_ID="com.utmapp.poi-SE"
	INPUT_APP="$INPUT/Products/Applications/PC on iPhone SE.app"
	;;
ipa-remote | ipa-remote-signed )
	APP_NAME="PC on iPhone Remote"
	OUTPUT_NAME="UTM Remote"
	BUNDLE_ID="com.utmapp.UTM-Remote"
	INPUT_APP="$INPUT/Products/Applications/PC on iPhone Remote.app"
	;;
* )
	usage
	;;
esac

# Legacy alias: internal helpers still refer to the bundle name via $NAME.
NAME="$APP_NAME"

# PRODUCT_NAME (and therefore the .app directory name) can change independently
# of the packaging mode. Fall back to the single .app in the archive so a brand
# rename does not silently break packaging with "Invalid xcarchive input!".
if [ ! -d "$INPUT_APP" ]; then
	_fallback=$(find "$INPUT/Products/Applications" -maxdepth 1 -name '*.app' 2>/dev/null | head -1)
	if [ -n "$_fallback" ]; then
		echo "Note: expected '$INPUT_APP', using '$_fallback' instead"
		INPUT_APP="$_fallback"
		APP_NAME="$(basename "$_fallback" .app)"
		NAME="$APP_NAME"
	fi
fi

if [ ! -d "$INPUT_APP" ]; then
	echo "Invalid xcarchive input!"
	usage
fi

if [ -z "$OUTPUT" ]; then
	echo "Invalid output path"
	usage
fi

itunes_sign() {
	local INPUT=$1
	local OUTPUT=$2
	local TEAM_ID=$3
	local PROFILE_NAME=$4
	local SIGNING_METHOD=$5
	local HELPER_PROFILE_NAME=$6
	local OPTIONS="/tmp/options.$$.plist"
	local HELPER_PROFILE=

	if [ ! -z "$HELPER_PROFILE_NAME" ]; then
		HELPER_PROFILE="<key>${BUNDLE_ID}.iOSHelper</key><string>${HELPER_PROFILE_NAME}</string>"
	fi

	if [ -z "$PROFILE_NAME" -o -z "$TEAM_ID" ]; then
		echo "Invalid profile name or team id!"
		usage
	fi
	if [ -z "$SIGNING_METHOD" ]; then
		SIGNING_METHOD="development"
	fi

	cat >"$OPTIONS" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>${SIGNING_METHOD}</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>${BUNDLE_ID}</key>
		<string>${PROFILE_NAME}</string>
		${HELPER_PROFILE}
	</dict>
	<key>signingStyle</key>
	<string>manual</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
	<key>thinning</key>
	<string>&lt;none&gt;</string>
</dict>
</plist>
EOL

	xcodebuild -exportArchive -exportOptionsPlist "$OPTIONS" -archivePath "$INPUT" -exportPath "$OUTPUT"
	rm "$OPTIONS"
}

# Rewrites CFBundleIdentifier in an Info.plist to $_bundle_id.
#
# Needed because the build product only ever knows the bundle id its target was
# compiled with, and ldid's -I only stamps the *signature* identifier — it does
# not change the plist. The iOS target builds as com.utmapp.poi, and both the
# JIT and HV IPAs are cut from that same archive, so without this the HV
# package would declare com.utmapp.poi and installing it would replace the
# standard build. (SE is unaffected: its target overrides
# PRODUCT_BUNDLE_IDENTIFIER to com.utmapp.poi-SE at build time, so its plist is
# already correct and the prefix check below skips it.)
#
# Sub-bundles (the helper .appex and any nested .app/.appex) are rewritten by
# swapping the base id for the new one, so they stay in the same ID family as
# the app — which the extension-to-host relationship depends on.
rewrite_bundle_id() {
	local _plist=$1
	local _from=$2
	local _to=$3

	[ -f "$_plist" ] || return 0

	local _current
	_current=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$_plist" 2>/dev/null) || return 0
	[ -z "$_current" ] && return 0
	# Leave unrelated identifiers alone (third-party frameworks, etc).
	case "$_current" in
	"$_from" | "$_from".*) ;;
	*) return 0 ;;
	esac

	local _new=${_current/#$_from/$_to}
	if ! /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${_new}" "$_plist"; then
		echo "error: could not set CFBundleIdentifier in $_plist" >&2
		return 1
	fi
	echo "  bundle id: ${_current} -> ${_new}"
	# Read it back so a silent no-op cannot ship.
	if [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$_plist")" != "$_new" ]; then
		echo "error: CFBundleIdentifier did not stick in $_plist" >&2
		return 1
	fi
}

fake_sign() {
	local _name=$1
	local _bundle_id=$2
	local _input=$3
	local _output=$4
	local _fakeent=$5
	# The identifier the build product was compiled with; the mode's
	# $_bundle_id replaces it everywhere it appears.
	local _base_id="com.utmapp.poi"

	mkdir -p "$_output"
	cp -a "$_input" "$_output/"

	# Rename the bundle identifier on disk before signing, so the signature
	# matches the plist instead of contradicting it. The app's own plist is
	# handled explicitly; nested executables (the helper .appex, plus any
	# .app/.appex a build might add) are walked. The `-mindepth 1` keeps the
	# outer .app from being visited twice.
	#
	# A pipeline would run the body in a subshell and swallow its exit status,
	# so the loop reads from a here-string via a file list instead.
	if [ "$_bundle_id" != "$_base_id" ]; then
		rewrite_bundle_id "$_output/Applications/$_name.app/Info.plist" "$_base_id" "$_bundle_id" || return 1
		while IFS= read -r _nested; do
			rewrite_bundle_id "$_nested/Info.plist" "$_base_id" "$_bundle_id" || return 1
		done < <(find "$_output/Applications/$_name.app" -mindepth 1 -type d \
			\( -name '*.appex' -o -name '*.app' \) -print)
	fi

	find "$_output" -type d -path '*/Frameworks/*.framework' -exec ldid -S \{\} \;
	find "$_output" -type d -path '*/Extensions/*.appex' -exec ldid -S \{\} \;
	if [ ! -z "${_fakeent}" ]; then
		ldid -S${_fakeent} -I${_bundle_id} "$_output/Applications/$_name.app/$_name"
	fi
}

create_deb() {
	local INPUT=$1
	local INPUT_APP="$INPUT/Products/Applications/UTM.app"
	local OUTPUT=$2
	local FAKEENT=$3
	local DEB_TMP="$OUTPUT/deb"
	local IPA_PATH="$DEB_TMP/var/tmp/com.utmapp.UTM"
	local SIZE_KIB=`du -sk "$INPUT_APP"| cut -f 1`
	local VERSION=`/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INPUT_APP/Info.plist"`

	mkdir -p "$OUTPUT"
	rm -rf "$DEB_TMP"
	mkdir -p "$DEB_TMP/DEBIAN"
cat >"$DEB_TMP/DEBIAN/control" <<EOL
Package: com.utmapp.UTM
Version: ${VERSION}
Section: Productivity
Architecture: all
Depends: firmware (>=15.0), net.angelxwind.appsyncunified
Installed-Size: ${SIZE_KIB}
Maintainer: osy <dev@getutm.app>
Description: Virtual machines for iOS
Homepage: https://getutm.app/
Name: UTM
Author: osy
Depiction: https://cydia.getutm.app/depiction/web/com.utmapp.UTM.html
Icon: https://cydia.getutm.app/assets/com.utmapp.UTM/icon.png
Moderndepiction: https://cydia.getutm.app/depiction/native/com.utmapp.UTM.json
Sileodepiction: https://cydia.getutm.app/depiction/native/com.utmapp.UTM.json
Tags: compatible_min::ios15.0
EOL
	xcrun -sdk iphoneos clang -arch arm64 -fobjc-arc -miphoneos-version-min=15.0 "$BASEDIR/deb/postinst.m" "$BASEDIR/deb/MobileCoreServices.tbd" -o "$DEB_TMP/DEBIAN/postinst"
	strip "$DEB_TMP/DEBIAN/postinst"
	ldid -S"$BASEDIR/deb/postinst.xml" "$DEB_TMP/DEBIAN/postinst"
	xcrun -sdk iphoneos clang -arch arm64 -fobjc-arc -miphoneos-version-min=15.0 "$BASEDIR/deb/prerm.m" "$BASEDIR/deb/MobileCoreServices.tbd" -o "$DEB_TMP/DEBIAN/prerm"
	strip "$DEB_TMP/DEBIAN/prerm"
	ldid -S"$BASEDIR/deb/prerm.xml" "$DEB_TMP/DEBIAN/prerm"
	mkdir -p "$IPA_PATH"
	create_fake_ipa "UTM" "com.utmapp.UTM" "$INPUT" "$IPA_PATH" "$FAKEENT"
	dpkg-deb -b -Zgzip -z9 "$DEB_TMP" "$OUTPUT/UTM.deb"
	rm -r "$DEB_TMP"
}

create_fake_ipa() {
	local NAME=$1
	local BUNDLE_ID=$2
	local INPUT=$3
	local OUTPUT=$4
	local FAKEENT=$5
	# Filename of the produced IPA. Defaults to the bundle name for the legacy
	# callers (deb); IPA modes pass it explicitly so a brand rename of
	# PRODUCT_NAME does not silently change the release artifact names.
	local IPA_NAME=${6:-$NAME}

	pwd="$(pwd)"
	mkdir -p "$OUTPUT"
	# Clear the previous run's leftovers. The IPA name depends on the caller,
	# so glob rather than hardcoding "UTM.ipa" — the old hardcoded name left a
	# stale "UTM SE.ipa" behind on reruns.
	rm -rf "$OUTPUT/Applications" "$OUTPUT/Payload" "$OUTPUT"/*.ipa
	fake_sign "$NAME" "$BUNDLE_ID" "$INPUT/Products/Applications" "$OUTPUT" "$FAKEENT" || return 1
	mv "$OUTPUT/Applications" "$OUTPUT/Payload"
	cd "$OUTPUT"
	zip -r "$IPA_NAME.ipa" "Payload" -x "._*" -x ".DS_Store" -x "__MACOSX"
	rm -r "Payload"
	cd "$pwd"
}

case $MODE in
deb )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
	<key>dynamic-codesigning</key>
	<true/>
	<key>com.apple.private.iokit.IOServiceSetAuthorizationID</key>
	<true/>
	<key>com.apple.security.exception.iokit-user-client-class</key>
	<array>
		<string>AppleUSBHostDeviceUserClient</string>
		<string>AppleUSBHostInterfaceUserClient</string>
	</array>
	<key>com.apple.system.diagnostics.iokit-properties</key>
	<true/>
	<key>com.apple.vm.device-access</key>
	<true/>
	<key>com.apple.private.hypervisor</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
</dict>
</plist>
EOL
	create_deb "$INPUT" "$OUTPUT" "$FAKEENT"
	rm "$FAKEENT"
	;;
ipa )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
	<key>dynamic-codesigning</key>
	<true/>
	<key>com.apple.private.iokit.IOServiceSetAuthorizationID</key>
	<true/>
	<key>com.apple.security.exception.iokit-user-client-class</key>
	<array>
		<string>AppleUSBHostDeviceUserClient</string>
		<string>AppleUSBHostInterfaceUserClient</string>
	</array>
	<key>com.apple.system.diagnostics.iokit-properties</key>
	<true/>
	<key>com.apple.vm.device-access</key>
	<true/>
	<key>com.apple.private.hypervisor</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "$FAKEENT" "$OUTPUT_NAME"
	rm "$FAKEENT"
	;;
ipa-hv )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
	<key>com.apple.private.iokit.IOServiceSetAuthorizationID</key>
	<true/>
	<key>com.apple.security.exception.iokit-user-client-class</key>
	<array>
		<string>AGXCommandQueue</string>
		<string>AGXDevice</string>
		<string>AGXDeviceUserClient</string>
		<string>AGXSharedUserClient</string>
		<string>AppleUSBHostDeviceUserClient</string>
		<string>AppleUSBHostInterfaceUserClient</string>
		<string>IOSurfaceRootUserClient</string>
		<string>IOAccelContext</string>
		<string>IOAccelContext2</string>
		<string>IOAccelDevice</string>
		<string>IOAccelDevice2</string>
		<string>IOAccelSharedUserClient</string>
		<string>IOAccelSharedUserClient2</string>
		<string>IOAccelSubmitter2</string>
	</array>
	<key>com.apple.system.diagnostics.iokit-properties</key>
	<true/>
	<key>com.apple.vm.device-access</key>
	<true/>
	<key>com.apple.private.hypervisor</key>
	<true/>
	<key>com.apple.private.memorystatus</key>
	<true/>
	<key>com.apple.private.security.no-sandbox</key>
	<true/>
	<key>com.apple.private.security.storage.AppDataContainers</key>
	<true/>
	<key>com.apple.private.security.storage.MobileDocuments</key>
	<true/>
	<key>platform-application</key>
	<true/>
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "$FAKEENT" "$OUTPUT_NAME"
	rm "$FAKEENT"
	;;
ipa-se )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
</dict>
</plist>
EOL
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "$FAKEENT" "$OUTPUT_NAME"
	rm "$FAKEENT"
	;;
ipa-remote )
	create_fake_ipa "$NAME" "$BUNDLE_ID" "$INPUT" "$OUTPUT" "" "$OUTPUT_NAME"
	;;
ipa-signed | ipa-se-signed )
	FAKEENT="/tmp/fakeent.$$.plist"
	cat >"$FAKEENT" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.kernel.increased-memory-limit</key>
	<true/>
	<key>com.apple.developer.kernel.extended-virtual-addressing</key>
	<true/>
</dict>
</plist>
EOL
	TMPINPUT="/tmp/UTM.$$.xcarchive"
	cp -a "$INPUT" "$TMPINPUT"
	BUILT_PATH=$(find "$TMPINPUT" -name '*.app' -type d | head -1)
	PLATFORM="$(/usr/libexec/PlistBuddy -c "Print :DTPlatformName" "$BUILT_PATH/Info.plist")"
	if [ "$PLATFORM" != "xros" ]; then
		codesign --force --sign - --entitlements "$FAKEENT" --timestamp=none "$BUILT_PATH"
	fi
	itunes_sign "$TMPINPUT" "$OUTPUT" $4 $5 $6 $7
	rm -rf "$TMPINPUT"
	;;
ipa-remote-signed )
	itunes_sign "$INPUT" "$OUTPUT" $4 $5 $6
	;;
esac
