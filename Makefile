APP_NAME = ClaudeNotifier
BUILD_DIR = .build
BINARY = $(BUILD_DIR)/release/$(APP_NAME)
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INSTALL_PATH = /Applications/$(APP_NAME).app

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
		sleep 1; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	cp -R "$(APP_BUNDLE)" "$(INSTALL_PATH)"
	@echo "✅ Installed to $(INSTALL_PATH)"
	@echo "🔄 Configuring Claude Code hooks..."
	@cd scripts && bash install.sh

clean:
	@echo "🧹 Cleaning..."
	rm -rf $(BUILD_DIR)
	@echo "✅ Cleaned"
