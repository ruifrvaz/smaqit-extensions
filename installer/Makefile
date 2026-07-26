.PHONY: build clean test smoke-test prepare

VERSION ?= 1.9.0

prepare:
	@echo "Preparing build environment..."
	@mkdir -p dist
	@mkdir -p templates
	@cp -r ../.smaqit/templates/* templates/ 2>/dev/null || true
	@python3 ../scripts/generate-targets.py

build: prepare
	@echo "Building smaqit-extensions..."
	go build -ldflags="-X main.Version=$(VERSION)" -o dist/smaqit-extensions

clean:
	@echo "Cleaning build artifacts..."
	rm -rf dist/
	rm -rf skills/ agents-copilot/ agents-claude/ agents-codex/ commands-claude/ skills-claude/ skills-codex/

test: build
	@echo "Testing installer..."
	go test ./...
	./dist/smaqit-extensions --version
	./dist/smaqit-extensions --help

smoke-test: test
	@echo "Running installer end-to-end smoke test..."
	@bash ../scripts/smoke-test-installer.sh ./dist/smaqit-extensions
