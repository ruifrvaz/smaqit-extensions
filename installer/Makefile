.PHONY: build clean test prepare mcp-build

VERSION ?= 0.1.0

mcp-build:
	@echo "Building MCP server TypeScript..."
	@cd ../mcp && npm install --silent && npm run build

prepare:
	@echo "Preparing build environment..."
	@mkdir -p dist
	@mkdir -p agents skills templates
	@mkdir -p mcp/src
	@cp -r ../agents/*.md agents/ 2>/dev/null || true
	@cp -rL ../skills/* skills/ 2>/dev/null || true
	@cp -r ../.smaqit/templates/* templates/ 2>/dev/null || true
	@cp ../mcp/package.json mcp/ 2>/dev/null || true
	@cp ../mcp/tsconfig.json mcp/ 2>/dev/null || true
	@cp ../mcp/README.md mcp/ 2>/dev/null || true
	@cp ../mcp/src/index.ts mcp/src/ 2>/dev/null || true

build: prepare
	@echo "Building smaqit-extensions..."
	go build -ldflags="-X main.Version=$(VERSION)" -o dist/smaqit-extensions

clean:
	@echo "Cleaning build artifacts..."
	rm -rf dist/
	rm -rf agents/ skills/ mcp/

test: build
	@echo "Testing installer..."
	./dist/smaqit-extensions --version
	./dist/smaqit-extensions --help
