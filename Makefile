PROJECT := skills.xcodeproj
SCHEME := Skills
CONFIGURATION ?= Debug
BUILD_DIR ?= .build
APP := $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/Skills.app

.PHONY: build test run clean

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -derivedDataPath "$(BUILD_DIR)" build

test:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -configuration "$(CONFIGURATION)" -derivedDataPath "$(BUILD_DIR)" test

run: build
	open "$(APP)"

clean:
	rm -rf "$(BUILD_DIR)" .build-release
