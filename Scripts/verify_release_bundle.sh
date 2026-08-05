#!/bin/bash

# Offline structural and signing verification for an exported Lidless.app.
# This never installs, registers, launches, notarizes, or staples the product.
set -euo pipefail
export LC_ALL=C

fail() {
    echo "Release verification failed: $*" >&2
    exit 1
}

require_equal() {
    local label=$1
    local expected=$2
    local actual=$3
    [[ "$actual" == "$expected" ]] \
        || fail "$label: expected '$expected', observed '$actual'"
}

has_owner_executable_mode() {
    local path=$1
    local mode
    mode=$(/usr/bin/stat -f '%p' "$path") \
        || fail "could not read file mode: $path"
    [[ "$mode" =~ ^[0-7]+$ ]] \
        || fail "invalid file mode for $path: $mode"
    (( (8#$mode & 07000) == 0 )) \
        || fail "special file mode is forbidden: $path"
    (( (8#$mode & 0100) != 0 ))
}

has_any_executable_mode() {
    local path=$1
    local mode
    mode=$(/usr/bin/stat -f '%p' "$path") \
        || fail "could not read file mode: $path"
    [[ "$mode" =~ ^[0-7]+$ ]] \
        || fail "invalid file mode for $path: $mode"
    (( (8#$mode & 07000) == 0 )) \
        || fail "special file mode is forbidden: $path"
    (( (8#$mode & 0111) != 0 ))
}

[[ $# -eq 1 ]] || fail "usage: $0 /path/to/Lidless.app"

case $1 in
    /*) APP=$1 ;;
    *) APP="$PWD/$1" ;;
esac

SCRIPT_DIR=$(cd "$(/usr/bin/dirname "$0")" && pwd)
REPOSITORY_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
HELPER="$APP/Contents/MacOS/LidlessHelper"
WIDGET="$APP/Contents/PlugIns/LidlessWidget.appex"
LAUNCHD_PLIST="$APP/Contents/Library/LaunchDaemons/com.lidless.helper.plist"
APP_INFO="$APP/Contents/Info.plist"
WIDGET_INFO="$WIDGET/Contents/Info.plist"

[[ -d "$APP" ]] || fail "app bundle not found: $APP"
[[ -f "$APP/Contents/MacOS/Lidless" ]] \
    && has_owner_executable_mode "$APP/Contents/MacOS/Lidless" \
    || fail "app executable is missing or not owner-executable"
[[ -f "$HELPER" ]] && has_owner_executable_mode "$HELPER" \
    || fail "embedded privileged helper is missing or not owner-executable"
[[ -d "$WIDGET" ]] || fail "embedded widget is missing"
[[ -f "$WIDGET/Contents/MacOS/LidlessWidget" ]] \
    && has_owner_executable_mode "$WIDGET/Contents/MacOS/LidlessWidget" \
    || fail "widget executable is missing or not owner-executable"
[[ -f "$LAUNCHD_PLIST" ]] || fail "embedded launchd plist is missing"
[[ -f "$APP_INFO" && -f "$WIDGET_INFO" ]] || fail "built Info.plist is missing"

VERIFY_TMP=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/lidless-release-verify.XXXXXX")
trap '/bin/rm -rf "$VERIFY_TMP"' EXIT

EXPECTED_TEAM=$(/usr/bin/sed -n \
    's/^[[:space:]]*DEVELOPMENT_TEAM:[[:space:]]*\([A-Z0-9][A-Z0-9]*\)[[:space:]]*$/\1/p' \
    "$REPOSITORY_ROOT/project.yml")
[[ "$EXPECTED_TEAM" =~ ^[A-Z0-9]{10}$ ]] \
    || fail "configured signing team is missing, duplicated, or malformed"

inspect_executable_architectures() {
    local label=$1
    local executable_path=$2
    local architectures
    local arch
    local architectures_file="$VERIFY_TMP/$label.architectures"

    architectures=$(/usr/bin/lipo -archs "$executable_path") \
        || fail "$label executable is not readable Mach-O code"
    [[ -n "$architectures" ]] || fail "$label executable has no architecture"
    : > "$architectures_file"

    for arch in $architectures; do
        /usr/bin/printf '%s\n' "$arch" >> "$architectures_file"
        /usr/bin/otool -arch "$arch" -hv "$executable_path" \
            > "$VERIFY_TMP/$label-$arch-mach-header.txt" \
            || fail "$label architecture $arch Mach header is unreadable"
        /usr/bin/grep -Eq '[[:space:]]EXECUTE([[:space:]]|$)' \
            "$VERIFY_TMP/$label-$arch-mach-header.txt" \
            || fail "$label architecture $arch is not an executable Mach-O file"
    done
    /usr/bin/sort -u -o "$architectures_file" "$architectures_file"
}

verify_code() {
    local label=$1
    local code_path=$2
    local expected_identifier=$3

    local arch
    local arch_info
    local identifier
    local team
    local authority
    local timestamp
    local normalized_timestamp
    local certificate_prefix
    local canonical_leaf="$VERIFY_TMP/$label-leaf.cer"
    local architectures_file="$VERIFY_TMP/$label.architectures"

    while IFS= read -r arch; do
        arch_info="$VERIFY_TMP/$label-$arch.codesign.txt"
        /usr/bin/codesign --display --architecture "$arch" --verbose=4 \
            "$code_path" > /dev/null 2> "$arch_info" \
            || fail "$label architecture $arch signing information is unreadable"

        identifier=$(/usr/bin/sed -n 's/^Identifier=//p' "$arch_info" | /usr/bin/head -n 1)
        team=$(/usr/bin/sed -n 's/^TeamIdentifier=//p' "$arch_info" | /usr/bin/head -n 1)
        authority=$(/usr/bin/sed -n 's/^Authority=//p' "$arch_info" | /usr/bin/head -n 1)
        timestamp=$(/usr/bin/sed -n 's/^Timestamp=//p' "$arch_info" | /usr/bin/head -n 1)
        normalized_timestamp=$(/usr/bin/printf '%s' "$timestamp" \
            | /usr/bin/tr '[:upper:]' '[:lower:]')

        require_equal "$label architecture $arch identifier" \
            "$expected_identifier" "$identifier"
        require_equal "$label architecture $arch TeamIdentifier" \
            "$EXPECTED_TEAM" "$team"
        [[ "$authority" == "Developer ID Application:"* ]] \
            || fail "$label architecture $arch is not signed by a Developer ID Application identity"
        case "$normalized_timestamp" in
            ""|none|"not set")
                fail "$label architecture $arch has no secure signing timestamp"
                ;;
        esac
        /usr/bin/grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)' "$arch_info" \
            || fail "$label architecture $arch does not enable hardened runtime"

        certificate_prefix="$VERIFY_TMP/$label-$arch-certificate-"
        /usr/bin/codesign --display --architecture "$arch" \
            --extract-certificates="$certificate_prefix" "$code_path" \
            > /dev/null 2> "$VERIFY_TMP/$label-$arch-certificates.txt" \
            || fail "$label architecture $arch certificate extraction failed"
        [[ -s "${certificate_prefix}0" ]] \
            || fail "$label architecture $arch has no embedded signing leaf certificate"
        if [[ ! -e "$canonical_leaf" ]]; then
            /bin/cp "${certificate_prefix}0" "$canonical_leaf"
        else
            /usr/bin/cmp -s "$canonical_leaf" "${certificate_prefix}0" \
                || fail "$label architectures use different signing leaf certificates"
        fi
    done < "$architectures_file"

    local requirement
    requirement="anchor apple generic and identifier \"$expected_identifier\" and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"$EXPECTED_TEAM\""
    /usr/bin/codesign --verify --strict=all --all-architectures --verbose=2 \
        -R="$requirement" "$code_path" \
        || fail "$label failed its pinned Developer ID requirement"
}

APP_EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_INFO")
WIDGET_EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$WIDGET_INFO")
require_equal "app executable name" Lidless "$APP_EXECUTABLE"
require_equal "widget executable name" LidlessWidget "$WIDGET_EXECUTABLE"

LINK_LIST="$VERIFY_TMP/bundle-links.nul"
/usr/bin/find "$APP/Contents" -type l -print0 > "$LINK_LIST" \
    || fail "could not enumerate release bundle links"
if IFS= read -r -d '' UNEXPECTED_LINK < "$LINK_LIST"; then
    fail "unexpected symbolic link in release bundle: $UNEXPECTED_LINK"
fi

EXPECTED_MACHO="$VERIFY_TMP/expected-mach-o.txt"
ACTUAL_MACHO="$VERIFY_TMP/actual-mach-o.txt"
: > "$ACTUAL_MACHO"
/usr/bin/printf '%s\n' \
    "Contents/MacOS/Lidless" \
    "Contents/MacOS/LidlessHelper" \
    "Contents/PlugIns/LidlessWidget.appex/Contents/MacOS/LidlessWidget" \
    | /usr/bin/sort > "$EXPECTED_MACHO"

BUNDLE_FILE_LIST="$VERIFY_TMP/bundle-files.nul"
/usr/bin/find "$APP/Contents" -type f -print0 > "$BUNDLE_FILE_LIST" \
    || fail "could not enumerate release bundle files"
while IFS= read -r -d '' candidate; do
    [[ -r "$candidate" ]] \
        || fail "could not inspect bundle file: $candidate is unreadable"
    kind=$(/usr/bin/file -E -b "$candidate") \
        || fail "could not inspect bundle file: $candidate"
    case "$kind" in
        "cannot open:"*|ERROR:*)
            fail "could not inspect bundle file: $candidate ($kind)"
            ;;
        Mach-O*)
            relative_path=${candidate#"$APP/"}
            [[ "$relative_path" != *$'\n'* ]] \
                || fail "newline in Mach-O bundle path"
            /usr/bin/printf '%s\n' "$relative_path" >> "$ACTUAL_MACHO"
            ;;
        *)
            if has_any_executable_mode "$candidate"; then
                fail "unexpected executable non-Mach-O file: $candidate"
            fi
            ;;
    esac
done < "$BUNDLE_FILE_LIST"
/usr/bin/sort -o "$ACTUAL_MACHO" "$ACTUAL_MACHO"

if ! /usr/bin/cmp -s "$EXPECTED_MACHO" "$ACTUAL_MACHO"; then
    echo "Expected Mach-O paths:" >&2
    /bin/cat "$EXPECTED_MACHO" >&2
    echo "Observed Mach-O paths:" >&2
    /bin/cat "$ACTUAL_MACHO" >&2
    fail "release bundle contains missing or unexpected Mach-O code"
fi

inspect_executable_architectures app "$APP/Contents/MacOS/Lidless"
inspect_executable_architectures helper "$HELPER"
inspect_executable_architectures widget \
    "$WIDGET/Contents/MacOS/$WIDGET_EXECUTABLE"
for nested_label in helper widget; do
    /usr/bin/cmp -s "$VERIFY_TMP/app.architectures" \
        "$VERIFY_TMP/$nested_label.architectures" \
        || fail "$nested_label architectures do not match app architectures"
done

verify_code app "$APP" com.lidless.app
verify_code helper "$HELPER" com.lidless.helper
verify_code widget "$WIDGET" com.lidless.app.widget

# Supplement the explicit nested checks with recursive containment validation.
/usr/bin/codesign --verify --deep --strict=all --all-architectures --verbose=2 "$APP" \
    || fail "app recursive signature containment verification failed"

SOURCE_APP_ENTITLEMENTS="$REPOSITORY_ROOT/App/Resources/Lidless.entitlements"
SOURCE_WIDGET_ENTITLEMENTS="$REPOSITORY_ROOT/Widget/Resources/LidlessWidget.entitlements"
require_equal "source app group" '["group.com.lidless.shared"]' \
    "$(/usr/bin/plutil -extract 'com\.apple\.security\.application-groups' json -o - "$SOURCE_APP_ENTITLEMENTS")"
require_equal "source widget group" '["group.com.lidless.shared"]' \
    "$(/usr/bin/plutil -extract 'com\.apple\.security\.application-groups' json -o - "$SOURCE_WIDGET_ENTITLEMENTS")"
require_equal "source widget sandbox" true \
    "$(/usr/bin/plutil -extract 'com\.apple\.security\.app-sandbox' raw -o - "$SOURCE_WIDGET_ENTITLEMENTS")"

verify_entitlements() {
    local label=$1
    local entitlements=$2
    local expected_bundle_id=$3
    local require_sandbox=$4
    local remainder="$VERIFY_TMP/$label-entitlements-remainder.plist"

    require_equal "$label application identifier" "$EXPECTED_TEAM.$expected_bundle_id" \
        "$(/usr/bin/plutil -extract 'com\.apple\.application-identifier' raw -o - "$entitlements")"
    require_equal "$label entitlement team" "$EXPECTED_TEAM" \
        "$(/usr/bin/plutil -extract 'com\.apple\.developer\.team-identifier' raw -o - "$entitlements")"
    require_equal "$label app group" '["group.com.lidless.shared"]' \
        "$(/usr/bin/plutil -extract 'com\.apple\.security\.application-groups' json -o - "$entitlements")"

    if [[ "$require_sandbox" == true ]]; then
        require_equal "$label sandbox" true \
            "$(/usr/bin/plutil -extract 'com\.apple\.security\.app-sandbox' \
                raw -expect bool -o - "$entitlements")"
    elif /usr/bin/plutil -extract 'com\.apple\.security\.app-sandbox' raw -o - \
        "$entitlements" > /dev/null 2>&1; then
        fail "$label unexpectedly carries the app-sandbox entitlement"
    fi

    /bin/cp "$entitlements" "$remainder"
    /usr/bin/plutil -remove 'com\.apple\.application-identifier' "$remainder"
    /usr/bin/plutil -remove 'com\.apple\.developer\.team-identifier' "$remainder"
    /usr/bin/plutil -remove 'com\.apple\.security\.application-groups' "$remainder"
    if [[ "$require_sandbox" == true ]]; then
        /usr/bin/plutil -remove 'com\.apple\.security\.app-sandbox' "$remainder"
    fi

    if /usr/bin/plutil -type 'com\.apple\.security\.get-task-allow' \
        "$remainder" > /dev/null 2>&1; then
        require_equal "$label get-task-allow" false \
            "$(/usr/bin/plutil -extract 'com\.apple\.security\.get-task-allow' \
                raw -expect bool -o - "$remainder")"
        /usr/bin/plutil -remove 'com\.apple\.security\.get-task-allow' "$remainder"
    fi

    if /usr/bin/plutil -extract keychain-access-groups json -o - \
        "$remainder" > "$VERIFY_TMP/$label-keychain-groups.json" 2>/dev/null; then
        require_equal "$label keychain groups" "[\"$EXPECTED_TEAM.*\"]" \
            "$(< "$VERIFY_TMP/$label-keychain-groups.json")"
        /usr/bin/plutil -remove keychain-access-groups "$remainder"
    fi

    require_equal "$label unexpected entitlements" '{}' \
        "$(/usr/bin/plutil -convert json -o - "$remainder")"
}

extract_and_verify_entitlements() {
    local label=$1
    local code_path=$2
    local expected_bundle_id=$3
    local require_sandbox=$4
    local architectures_file="$VERIFY_TMP/$label.architectures"
    local canonical="$VERIFY_TMP/$label-entitlements.plist"
    local canonical_json="$VERIFY_TMP/$label-entitlements.json"
    local arch
    local output
    local normalized
    local diagnostics

    while IFS= read -r arch; do
        output="$VERIFY_TMP/$label-$arch-entitlements.plist"
        diagnostics="$VERIFY_TMP/$label-$arch-entitlements.txt"
        /usr/bin/codesign --display --architecture "$arch" --xml \
            --entitlements "$output" "$code_path" \
            > /dev/null 2> "$diagnostics" \
            || fail "$label architecture $arch entitlements are unreadable"
        [[ -s "$output" ]] \
            || fail "$label architecture $arch has no signed entitlements"
        /usr/bin/plutil -lint "$output" > /dev/null \
            || fail "$label architecture $arch entitlements are not a valid plist"
        verify_entitlements "$label architecture $arch" "$output" \
            "$expected_bundle_id" "$require_sandbox"
        normalized="$VERIFY_TMP/$label-$arch-entitlements.json"
        /usr/bin/plutil -convert json -o "$normalized" "$output" \
            || fail "$label architecture $arch entitlements cannot be normalized"

        if [[ ! -e "$canonical" ]]; then
            /bin/cp "$output" "$canonical"
            /bin/cp "$normalized" "$canonical_json"
        else
            /usr/bin/cmp -s "$canonical_json" "$normalized" \
                || fail "$label architectures carry different signed entitlements"
        fi
    done < "$architectures_file"
}

verify_no_entitlements() {
    local label=$1
    local code_path=$2
    local architectures_file="$VERIFY_TMP/$label.architectures"
    local arch
    local output
    local diagnostics

    while IFS= read -r arch; do
        output="$VERIFY_TMP/$label-$arch-entitlements.plist"
        diagnostics="$VERIFY_TMP/$label-$arch-entitlements.txt"
        /usr/bin/codesign --display --architecture "$arch" --xml \
            --entitlements "$output" "$code_path" \
            > /dev/null 2> "$diagnostics" \
            || fail "$label architecture $arch entitlement inspection failed"

        [[ ! -s "$output" ]] \
            || fail "$label architecture $arch unexpectedly carries signed entitlements"
    done < "$architectures_file"
}

APP_ENTITLEMENTS="$VERIFY_TMP/app-entitlements.plist"
WIDGET_ENTITLEMENTS="$VERIFY_TMP/widget-entitlements.plist"
extract_and_verify_entitlements app "$APP" com.lidless.app false
extract_and_verify_entitlements widget "$WIDGET" com.lidless.app.widget true

# The root helper needs no entitlement. Rejecting any entitlement keeps its
# privileged surface smaller and catches accidental debug/signing exceptions.
verify_no_entitlements helper "$HELPER"

SOURCE_APP_INFO="$REPOSITORY_ROOT/App/Resources/Info.plist"
SOURCE_WIDGET_INFO="$REPOSITORY_ROOT/Widget/Resources/Info.plist"
/usr/bin/plutil -lint "$APP_INFO" "$WIDGET_INFO" "$SOURCE_APP_INFO" \
    "$SOURCE_WIDGET_INFO" "$LAUNCHD_PLIST" > /dev/null
require_equal "app bundle identifier" com.lidless.app \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_INFO")"
require_equal "widget bundle identifier" com.lidless.app.widget \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$WIDGET_INFO")"
require_equal "widget marketing version" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_INFO")" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$WIDGET_INFO")"
require_equal "widget build version" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_INFO")" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$WIDGET_INFO")"
require_equal "source app marketing version" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP_INFO")" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_INFO")"
require_equal "source app build version" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_APP_INFO")" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_INFO")"
require_equal "source widget marketing version" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_WIDGET_INFO")" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$WIDGET_INFO")"
require_equal "source widget build version" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SOURCE_WIDGET_INFO")" \
    "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$WIDGET_INFO")"

SOURCE_LAUNCHD_PLIST="$REPOSITORY_ROOT/Helper/Resources/com.lidless.helper.plist"
/usr/bin/cmp -s "$SOURCE_LAUNCHD_PLIST" "$LAUNCHD_PLIST" \
    || fail "embedded launchd plist differs from the reviewed source plist"
require_equal "launchd label" com.lidless.helper \
    "$(/usr/bin/plutil -extract Label raw -o - "$LAUNCHD_PLIST")"
require_equal "launchd program" Contents/MacOS/LidlessHelper \
    "$(/usr/bin/plutil -extract BundleProgram raw -o - "$LAUNCHD_PLIST")"
require_equal "launchd associated app" '["com.lidless.app"]' \
    "$(/usr/bin/plutil -extract AssociatedBundleIdentifiers json -o - "$LAUNCHD_PLIST")"
require_equal "launchd Mach service" '{"com.lidless.helper":true}' \
    "$(/usr/bin/plutil -extract MachServices json -o - "$LAUNCHD_PLIST")"
require_equal "launchd sentinel supervision" \
    '{"/var/db/lidless/override-active":true}' \
    "$(/usr/bin/plutil -extract KeepAlive.PathState json -o - "$LAUNCHD_PLIST")"
require_equal "launchd RunAtLoad" true \
    "$(/usr/bin/plutil -extract RunAtLoad raw -o - "$LAUNCHD_PLIST")"

verify_profile() {
    local label=$1
    local profile_path=$2
    local expected_bundle_id=$3
    local leaf_certificate=$4
    local signed_entitlements=$5
    local decoded="$VERIFY_TMP/$label-profile.plist"
    local certificate_count
    local certificate_index
    local leaf_base64
    local profile_certificate
    local certificate_found=false
    local signed_keychain_groups
    local profile_keychain_groups

    [[ -f "$profile_path" ]] || fail "$label embedded provisioning profile is missing"
    /usr/bin/profiles validate -type provisioning -path "$profile_path" \
        > "$VERIFY_TMP/$label-profile-validation.txt" 2>&1 \
        || fail "$label provisioning profile failed system validation"
    /usr/bin/security cms -D -i "$profile_path" -o "$decoded" \
        || fail "$label provisioning profile CMS is invalid"
    /usr/bin/plutil -lint "$decoded" > /dev/null \
        || fail "$label provisioning profile is not a valid plist"

    require_equal "$label profile platform" '["OSX"]' \
        "$(/usr/bin/plutil -extract Platform json -expect array -o - "$decoded")"
    require_equal "$label profile distribution scope" true \
        "$(/usr/bin/plutil -extract ProvisionsAllDevices raw -expect bool -o - "$decoded")"
    if /usr/bin/plutil -type ProvisionedDevices "$decoded" > /dev/null 2>&1; then
        fail "$label provisioning profile is device-scoped"
    fi
    require_equal "$label profile get-task-allow" false \
        "$(/usr/bin/plutil -extract 'Entitlements.get-task-allow' raw \
            -expect bool -o - "$decoded")"

    require_equal "$label profile team list" "[\"$EXPECTED_TEAM\"]" \
        "$(/usr/bin/plutil -extract TeamIdentifier json -expect array -o - "$decoded")"
    require_equal "$label profile application identifier" \
        "$EXPECTED_TEAM.$expected_bundle_id" \
        "$(/usr/bin/plutil -extract 'Entitlements.com\.apple\.application-identifier' \
            raw -expect string -o - "$decoded")"
    require_equal "$label profile entitlement team" "$EXPECTED_TEAM" \
        "$(/usr/bin/plutil -extract 'Entitlements.com\.apple\.developer\.team-identifier' \
            raw -expect string -o - "$decoded")"
    require_equal "$label profile app groups" '["group.com.lidless.shared"]' \
        "$(/usr/bin/plutil -extract 'Entitlements.com\.apple\.security\.application-groups' \
            json -expect array -o - "$decoded")"

    [[ -s "$leaf_certificate" ]] \
        || fail "$label signing leaf certificate is unavailable"
    leaf_base64=$(/usr/bin/base64 < "$leaf_certificate" \
        | /usr/bin/tr -d '[:space:]')
    certificate_count=$(/usr/bin/plutil -extract DeveloperCertificates raw \
        -expect array -o - "$decoded") \
        || fail "$label profile has no DeveloperCertificates array"
    [[ "$certificate_count" =~ ^[0-9]+$ ]] && (( certificate_count > 0 )) \
        || fail "$label profile has no developer certificates"
    certificate_index=0
    while (( certificate_index < certificate_count )); do
        profile_certificate=$(/usr/bin/plutil -extract \
            "DeveloperCertificates.$certificate_index" raw -expect data -o - "$decoded") \
            || fail "$label profile developer certificate $certificate_index is unreadable"
        profile_certificate=$(/usr/bin/printf '%s' "$profile_certificate" \
            | /usr/bin/tr -d '[:space:]')
        if [[ "$profile_certificate" == "$leaf_base64" ]]; then
            certificate_found=true
        fi
        certificate_index=$((certificate_index + 1))
    done
    [[ "$certificate_found" == true ]] \
        || fail "$label signing leaf certificate is not authorized by its profile"

    if /usr/bin/plutil -type keychain-access-groups \
        "$signed_entitlements" > /dev/null 2>&1; then
        signed_keychain_groups=$(/usr/bin/plutil -extract keychain-access-groups \
            json -expect array -o - "$signed_entitlements") \
            || fail "$label signed keychain groups are malformed"
        profile_keychain_groups=$(/usr/bin/plutil -extract \
            Entitlements.keychain-access-groups json -expect array -o - "$decoded") \
            || fail "$label profile does not authorize signed keychain groups"
        require_equal "$label profile keychain groups" \
            "$signed_keychain_groups" "$profile_keychain_groups"
    fi

    local expiration
    local expiration_epoch
    local now_epoch
    expiration=$(/usr/bin/plutil -extract ExpirationDate raw -expect date -o - "$decoded") \
        || fail "$label provisioning profile has no expiration date"
    expiration_epoch=$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' \
        "$expiration" '+%s') \
        || fail "$label provisioning profile expiration date is unreadable"
    now_epoch=$(/bin/date -u '+%s')
    (( expiration_epoch > now_epoch )) \
        || fail "$label provisioning profile is expired"
}

verify_profile app "$APP/Contents/embedded.provisionprofile" com.lidless.app \
    "$VERIFY_TMP/app-leaf.cer" "$APP_ENTITLEMENTS"
verify_profile widget "$WIDGET/Contents/embedded.provisionprofile" \
    com.lidless.app.widget "$VERIFY_TMP/widget-leaf.cer" "$WIDGET_ENTITLEMENTS"

echo "Release bundle verification passed for team $EXPECTED_TEAM."
