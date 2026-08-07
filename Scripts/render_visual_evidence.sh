#!/bin/bash
# Rebuild the complete deterministic app, widget, icon, and contact-sheet
# evidence matrix without installing a helper or mutating system settings.
set -euo pipefail

cd "$(/usr/bin/dirname "$0")/.."

LIDLESS_VISUAL_ROOT="$PWD/build/visual-qa"
LIDLESS_CORE_SCRATCH="$LIDLESS_VISUAL_ROOT/core"
LIDLESS_CACHE_ROOT="$LIDLESS_VISUAL_ROOT/cache"
LIDLESS_TMP_ROOT="$LIDLESS_CACHE_ROOT/tmp"
LIDLESS_HOST_ARCH=$(/usr/bin/uname -m)

case "$LIDLESS_HOST_ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported host architecture: $LIDLESS_HOST_ARCH" >&2
        exit 1
        ;;
esac

/bin/mkdir -p \
    "$LIDLESS_VISUAL_ROOT" \
    "$LIDLESS_CACHE_ROOT/clang" \
    "$LIDLESS_CACHE_ROOT/swiftpm" \
    "$LIDLESS_CACHE_ROOT/swiftpm-configuration" \
    "$LIDLESS_CACHE_ROOT/swiftpm-security" \
    "$LIDLESS_CACHE_ROOT/xdg" \
    "$LIDLESS_TMP_ROOT"

export TMPDIR="$LIDLESS_TMP_ROOT"

CLANG_MODULE_CACHE_PATH="$LIDLESS_CACHE_ROOT/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$LIDLESS_CACHE_ROOT/swiftpm" \
XDG_CACHE_HOME="$LIDLESS_CACHE_ROOT/xdg" \
/usr/bin/xcrun swift build \
    --package-path Packages/LidlessCore \
    --disable-sandbox \
    --cache-path "$LIDLESS_CACHE_ROOT/swiftpm-cache" \
    --config-path "$LIDLESS_CACHE_ROOT/swiftpm-configuration" \
    --security-path "$LIDLESS_CACHE_ROOT/swiftpm-security" \
    --scratch-path "$LIDLESS_CORE_SCRATCH"

LIDLESS_CORE_BUILD="$LIDLESS_CORE_SCRATCH/$LIDLESS_HOST_ARCH-apple-macosx/debug"
LIDLESS_CORE_MODULES="$LIDLESS_CORE_BUILD/Modules"
LIDLESS_CORE_OBJECTS=("$LIDLESS_CORE_BUILD/LidlessCore.build"/*.o)

[[ -f "$LIDLESS_CORE_MODULES/LidlessCore.swiftmodule" ]] || {
    echo "Core module was not produced at $LIDLESS_CORE_MODULES" >&2
    exit 1
}
[[ -e "${LIDLESS_CORE_OBJECTS[0]}" ]] || {
    echo "Core objects were not produced at $LIDLESS_CORE_BUILD" >&2
    exit 1
}

LIDLESS_APP_SOURCES=()
while IFS= read -r LIDLESS_SOURCE; do
    LIDLESS_APP_SOURCES+=("$LIDLESS_SOURCE")
done < <(/usr/bin/find App/Sources -type f -name '*.swift' -print | /usr/bin/sort)

[[ "${#LIDLESS_APP_SOURCES[@]}" -gt 0 ]] || {
    echo "No app sources were found" >&2
    exit 1
}

/usr/bin/xcrun swiftc \
    -parse-as-library \
    -disable-sandbox \
    -D LIDLESS_APP_RENDER_HARNESS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -target "$LIDLESS_HOST_ARCH-apple-macosx15.0" \
    -module-name LidlessVisualEvidence \
    -module-cache-path "$LIDLESS_CACHE_ROOT/clang" \
    -I "$LIDLESS_CORE_MODULES" \
    "${LIDLESS_APP_SOURCES[@]}" \
    Scripts/VisualQA/AppRenderHarness.swift \
    "${LIDLESS_CORE_OBJECTS[@]}" \
    -o "$LIDLESS_VISUAL_ROOT/AppRenderHarness"

"$LIDLESS_VISUAL_ROOT/AppRenderHarness" --render-screenshots

/usr/bin/xcrun swiftc \
    -parse-as-library \
    -D LIDLESS_WIDGET_RENDER_HARNESS \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -target "$LIDLESS_HOST_ARCH-apple-macosx15.0" \
    -module-cache-path "$LIDLESS_CACHE_ROOT/clang" \
    -I "$LIDLESS_CORE_MODULES" \
    Widget/Sources/LidlessWidget.swift \
    Scripts/VisualQA/WidgetRenderHarness.swift \
    "${LIDLESS_CORE_OBJECTS[@]}" \
    -o "$LIDLESS_VISUAL_ROOT/WidgetRenderHarness"

"$LIDLESS_VISUAL_ROOT/WidgetRenderHarness"

CLANG_MODULE_CACHE_PATH="$LIDLESS_CACHE_ROOT/clang" \
/usr/bin/xcrun swift \
    -module-cache-path "$LIDLESS_CACHE_ROOT/clang" \
    Scripts/make_icon.swift \
    App/Resources/Assets.xcassets/AppIcon.appiconset \
    Docs/screenshots/icon-contact-sheet.png

/usr/bin/xcrun swiftc \
    -parse-as-library \
    -swift-version 6 \
    -strict-concurrency=complete \
    -warnings-as-errors \
    -target "$LIDLESS_HOST_ARCH-apple-macosx15.0" \
    -module-cache-path "$LIDLESS_CACHE_ROOT/clang" \
    Scripts/VisualQA/ContactSheet.swift \
    -o "$LIDLESS_VISUAL_ROOT/ContactSheet"

"$LIDLESS_VISUAL_ROOT/ContactSheet"

echo "Visual evidence regenerated under Docs/screenshots."
