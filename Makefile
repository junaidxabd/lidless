SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -ec

XCODEPROJ := Lidless.xcodeproj
SCHEME := Lidless
CONFIG := Debug
DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/$(CONFIG)/Lidless.app
LOCAL_CACHE_ROOT := $(CURDIR)/.build/local-cache
LOCAL_CLANG_MODULE_CACHE := $(LOCAL_CACHE_ROOT)/clang-module-cache
LOCAL_SWIFTPM_MODULE_CACHE := $(LOCAL_CACHE_ROOT)/swiftpm-module-cache
LOCAL_SWIFTPM_CACHE := $(LOCAL_CACHE_ROOT)/swiftpm-cache
LOCAL_SWIFTPM_CONFIG := $(LOCAL_CACHE_ROOT)/swiftpm-configuration
LOCAL_SWIFTPM_SECURITY := $(LOCAL_CACHE_ROOT)/swiftpm-security
LOCAL_XDG_CACHE := $(LOCAL_CACHE_ROOT)/xdg-cache
LOCAL_TMP := $(LOCAL_CACHE_ROOT)/tmp

.PHONY: gen build test test-local run simulate screenshots visual-evidence icon clean release

# Regenerate the committed xcodeproj after editing project.yml
# (requires xcodegen: brew install xcodegen).
gen:
	xcodegen generate

# Builds the committed project directly — no xcodegen needed.
build:
	xcodebuild -project $(XCODEPROJ) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(DERIVED) build | tail -20

test:
	swift test --package-path Packages/LidlessCore

# Managed or restricted workspace fallback: keep SwiftPM and compiler caches
# inside this repository and disable only SwiftPM's nested sandbox.
# Normal environments and CI should keep using `make test` with its standard sandbox.
test-local:
	@mkdir -p "$(LOCAL_CLANG_MODULE_CACHE)" \
		"$(LOCAL_SWIFTPM_MODULE_CACHE)" \
		"$(LOCAL_SWIFTPM_CACHE)" \
		"$(LOCAL_SWIFTPM_CONFIG)" \
		"$(LOCAL_SWIFTPM_SECURITY)" \
		"$(LOCAL_XDG_CACHE)" \
		"$(LOCAL_TMP)"
	TMPDIR="$(LOCAL_TMP)" \
	XDG_CACHE_HOME="$(LOCAL_XDG_CACHE)" \
	CLANG_MODULE_CACHE_PATH="$(LOCAL_CLANG_MODULE_CACHE)" \
	SWIFTPM_MODULECACHE_OVERRIDE="$(LOCAL_SWIFTPM_MODULE_CACHE)" \
	swift test --disable-sandbox --package-path Packages/LidlessCore \
		--cache-path "$(LOCAL_SWIFTPM_CACHE)" \
		--config-path "$(LOCAL_SWIFTPM_CONFIG)" \
		--security-path "$(LOCAL_SWIFTPM_SECURITY)" \
		--scratch-path "$(CURDIR)/Packages/LidlessCore/.build"

run: build
	open "$(APP)"

# Dry-run mode: full app against simulated battery/thermal inputs.
simulate: build
	"$(APP)/Contents/MacOS/Lidless" --simulate &

# Regenerate README screenshots from the real UI (simulation-driven).
screenshots: build
	"$(APP)/Contents/MacOS/Lidless" --render-screenshots

# Rebuild the complete simulation-only app/widget/icon evidence matrix.
visual-evidence:
	Scripts/render_visual_evidence.sh

icon:
	swift Scripts/make_icon.swift

release:
	Scripts/release.sh

clean:
	rm -rf build
