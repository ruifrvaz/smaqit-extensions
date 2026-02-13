.PHONY: build clean test prepare

VERSION ?= 0.1.0

prepare:
	@echo "Preparing build environment..."
	@mkdir -p dist
	@mkdir -p prompts agents skills
	@cp -r ../prompts/*.md prompts/ 2>/dev/null || true
	@cp -r ../agents/*.md agents/ 2>/dev/null || true
	@cp -rL ../skills/* skills/ 2>/dev/null || true

build: prepare
	@echo "Building smaqit-extensions..."
	go build -ldflags="-X main.Version=$(VERSION)" -o dist/smaqit-extensions

clean:
	@echo "Cleaning build artifacts..."
	rm -rf dist/
	rm -rf prompts/ agents/ skills/

test: build
	@echo "Testing installer..."
	./dist/smaqit-extensions --version
	./dist/smaqit-extensions --help
