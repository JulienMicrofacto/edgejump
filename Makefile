APP_NAME = ScreenBridge
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
CONTENTS = $(APP_BUNDLE)/Contents
MACOS = $(CONTENTS)/MacOS

SOURCES = ScreenBridge/main.swift ScreenBridge/AppDelegate.swift
FRAMEWORKS = -framework Cocoa -framework ApplicationServices

.PHONY: all clean run

all: $(MACOS)/$(APP_NAME)

$(MACOS)/$(APP_NAME): $(SOURCES)
	@mkdir -p $(MACOS)
	swiftc -o $@ $(FRAMEWORKS) $(SOURCES)
	@cp ScreenBridge/Info.plist $(CONTENTS)/Info.plist

clean:
	rm -rf $(BUILD_DIR)

run: all
	open $(APP_BUNDLE)
