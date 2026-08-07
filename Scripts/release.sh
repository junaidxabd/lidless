#!/bin/bash
# Release build: archive → export → verify → notarization submission zip.
# After a separately authorized notarization/stapling step, `finalize` validates
# the ticket, re-verifies the bundle, and only then creates the release checksum.
#
# Prerequisite: the configured team must have the Developer ID certificates,
# app identifiers, and app-group capability available in Xcode.
set -euo pipefail
cd "$(/usr/bin/dirname "$0")/.."

SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c \
    'Print CFBundleShortVersionString' App/Resources/Info.plist)
DIST=dist
ARCHIVE="$DIST/Lidless.xcarchive"
APP="$DIST/export/Lidless.app"
MODE=${1:-prepare}
RELEASE_ARCHITECTURES="arm64 x86_64"

validate_version() {
    [[ "$1" =~ ^[0-9A-Za-z][0-9A-Za-z._+-]*$ ]] || {
        echo "Unsafe bundle version: $1" >&2
        exit 1
    }
}

case "$MODE" in
prepare)
    VERSION=$SOURCE_VERSION
    validate_version "$VERSION"
    SUBMISSION_ZIP="$DIST/Lidless-$VERSION-notarization.zip"
    /bin/rm -rf "$DIST"
    /bin/mkdir -p "$DIST"

    echo "==> Archiving Lidless $VERSION (Release)"
    /usr/bin/xcodebuild -project Lidless.xcodeproj -scheme Lidless \
        -configuration Release -destination 'generic/platform=macOS' \
        -archivePath "$ARCHIVE" ARCHS="$RELEASE_ARCHITECTURES" \
        ONLY_ACTIVE_ARCH=NO archive | /usr/bin/tail -5

    echo "==> Exporting with Developer ID signing"
    # -exportArchive re-signs for distribution; zipping the raw archive product
    # would ship the development signature and fail the release verifier.
    /usr/bin/xcodebuild -exportArchive -archivePath "$ARCHIVE" \
        -exportOptionsPlist Scripts/ExportOptions.plist \
        -exportPath "$DIST/export" | /usr/bin/tail -5

    echo "==> Verifying exported bundle"
    Scripts/verify_release_bundle.sh "$APP"

    echo "==> Checking notarization-submission policy"
    /usr/bin/syspolicy_check notary-submission "$APP"

    echo "==> Creating notarization submission"
    /usr/bin/ditto -c -k --keepParent "$APP" "$SUBMISSION_ZIP"

    cat <<EOF

Notarization submission: $SUBMISSION_ZIP
No release checksum exists yet: stapling changes the app and final zip bytes.

Under a separately authorized credentialed release gate:
  1. Submit "$SUBMISSION_ZIP" with notarytool and wait for acceptance.
  2. Run: xcrun stapler staple "$APP"
  3. Run: Scripts/release.sh finalize
EOF
    ;;

finalize)
    [[ -d "$APP" ]] || {
        echo "Exported app not found: $APP" >&2
        exit 1
    }

    echo "==> Validating stapled notarization ticket"
    /usr/bin/xcrun stapler validate "$APP"

    echo "==> Assessing notarized executable policy"
    /usr/sbin/spctl --assess --type execute --verbose=4 "$APP"

    echo "==> Re-verifying stapled bundle"
    Scripts/verify_release_bundle.sh "$APP"

    echo "==> Checking local distribution policy"
    /usr/bin/syspolicy_check distribution "$APP"

    VERSION=$(/usr/libexec/PlistBuddy -c \
        'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
    validate_version "$VERSION"
    FINAL_ZIP="$DIST/Lidless-$VERSION.zip"

    echo "==> Creating final release artifact"
    /bin/rm -f "$FINAL_ZIP"
    /usr/bin/ditto -c -k --keepParent "$APP" "$FINAL_ZIP"
    SHA=$(/usr/bin/shasum -a 256 "$FINAL_ZIP" | /usr/bin/cut -d' ' -f1)

    cat <<EOF

Final stapled artifact: $FINAL_ZIP
sha256: $SHA

The app used to create this artifact passed local signature, entitlement,
bundle-layout, hardened-runtime, provisioning-profile, stapled-ticket, and
execution-policy checks.
Publication remains a separate release gate.
EOF
    ;;

*)
    echo "Usage: $0 [prepare|finalize]" >&2
    exit 2
    ;;
esac
