#!/bin/bash
# Release build: archive → export → zip (Homebrew-cask-friendly) → checksum,
# with notarization commands printed at the end.
#
# Prerequisites: a Developer ID team configured in project.yml
# (DEVELOPMENT_TEAM + CODE_SIGN_STYLE: Automatic + the two
# CODE_SIGN_ENTITLEMENTS lines uncommented), then `make gen`.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' App/Resources/Info.plist)
DIST=dist
ARCHIVE="$DIST/Lidless.xcarchive"
APP="$DIST/export/Lidless.app"
ZIP="$DIST/Lidless-$VERSION.zip"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "==> Archiving Lidless $VERSION (Release)"
xcodebuild -project Lidless.xcodeproj -scheme Lidless -configuration Release \
    archive -archivePath "$ARCHIVE" | tail -5

echo "==> Exporting with Developer ID signing"
# -exportArchive re-signs for distribution; zipping the raw archive product
# would ship the development signature and always fail notarization.
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist Scripts/ExportOptions.plist \
    -exportPath "$DIST/export" | tail -5

echo "==> Verifying signatures"
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier|TeamIdentifier|Authority' | head -4

echo "==> Zipping"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
SHA=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

cat <<EOF

Release artifact: $ZIP
sha256: $SHA

Next steps:
  1. Notarize:
       xcrun notarytool submit "$ZIP" --keychain-profile lidless-notary --wait
       xcrun stapler staple "$APP" && /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
     (Create the keychain profile once with:
       xcrun notarytool store-credentials lidless-notary \\
         --apple-id YOU@example.com --team-id TEAMID --password app-specific-pw)
  2. Upload $ZIP to the GitHub release for v$VERSION.
  3. Update Casks/lidless.rb: version "$VERSION", sha256 "$SHA".
EOF
