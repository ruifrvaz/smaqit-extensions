.PHONY: build clean test prepare

VERSION ?= 1.5.0

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
	rm -rf skills/ agents-copilot/ agents-claude/ commands-claude/ skills-claude/

test: build
	@echo "Testing installer..."
	./dist/smaqit-extensions --version
	./dist/smaqit-extensions --help
