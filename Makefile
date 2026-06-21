APP_NAME = CodeNotifier
BUILD_DIR = .build
BINARY = $(BUILD_DIR)/release/ClaudeNotifier
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_PATH = /Applications/$(APP_NAME).app
OLD_INSTALL_PATH = /Applications/ClaudeNotifier.app

.PHONY: build package install clean

build:
	@echo "🔨 Building $(APP_NAME) with SPM..."
	swift build -c release
	@echo "✅ Binary: $(BINARY)"

package: build
	@echo "📦 Packaging $(APP_NAME).app..."
	@bash scripts/package-app.sh
	@echo "✅ App bundle: $(APP_BUNDLE)"

install: package
	@echo "📦 Installing to /Applications..."
	@if [ -d "$(INSTALL_PATH)" ]; then \
		pkill -f "$(APP_NAME)" 2>/dev/null || true; \
		pkill -f "ClaudeNotifier" 2>/dev/null || true; \
		sleep 1; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	@if [ -d "$(OLD_INSTALL_PATH)" ]; then \
		pkill -f "$(APP_NAME)" 2>/dev/null || true; \
		pkill -f "ClaudeNotifier" 2>/dev/null || true; \
		sleep 1; \
		rm -rf "$(OLD_INSTALL_PATH)"; \
	fi
	cp -R "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@echo "✅ Installed to $(INSTALL_PATH)"
	@echo "🔄 Configuring Claude Code hooks..."
	@cd scripts && bash install.sh

clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)
	@echo "✅ Cleaned"
