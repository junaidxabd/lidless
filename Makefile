SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -ec

XCODEPROJ := Lidless.xcodeproj
SCHEME := Lidless
CONFIG := Debug
DERIVED := build/DerivedData
APP := $(DERIVED)/Build/Products/$(CONFIG)/Lidless.app

.PHONY: gen build test run simulate screenshots icon clean release

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

run: build
	open "$(APP)"

# Dry-run mode: full app against simulated battery/thermal inputs.
simulate: build
	"$(APP)/Contents/MacOS/Lidless" --simulate &

# Regenerate README screenshots from the real UI (simulation-driven).
screenshots: build
	"$(APP)/Contents/MacOS/Lidless" --render-screenshots

icon:
	swift Scripts/make_icon.swift

release:
	Scripts/release.sh

clean:
	rm -rf build
