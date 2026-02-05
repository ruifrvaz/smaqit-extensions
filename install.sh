#!/bin/bash
# smaqit-extensions installer script
# Usage: curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | bash
# 
# Options (set as environment variables):
#   SMAQIT_EXT_VERSION=latest      Install latest stable release (default)
#   SMAQIT_EXT_VERSION=prerelease  Install latest pre-release (beta, alpha, etc.)
#   SMAQIT_EXT_VERSION=v0.1.0      Install specific version
#
# Examples:
#   curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | SMAQIT_EXT_VERSION=prerelease bash
#   curl -fsSL https://raw.githubusercontent.com/ruifrvaz/smaqit-extensions/main/install.sh | SMAQIT_EXT_VERSION=v0.1.0 bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO="ruifrvaz/smaqit-extensions"
INSTALL_DIR="${HOME}/.local/bin"
SMAQIT_EXT_VERSION="${SMAQIT_EXT_VERSION:-latest}"  # Default to latest stable

# Helper functions
info() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

# Detect OS and architecture
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        linux)
            OS="linux"
            ;;
        darwin)
            OS="darwin"
            ;;
        mingw*|msys*|cygwin*)
            OS="windows"
            ;;
        *)
            error "Unsupported operating system: $os"
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            error "Unsupported architecture: $arch"
            ;;
    esac
    
    info "Detected platform: ${OS}/${ARCH}"
}

# Get latest release version from GitHub API
get_latest_version() {
    info "Fetching release version..."
    
    local api_url="https://api.github.com/repos/${REPO}/releases"
    
    case "$SMAQIT_EXT_VERSION" in
        latest)
            # Get latest stable release (excludes pre-releases)
            VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
            
            # Fallback: if no stable release, get most recent (including pre-release)
            if [ -z "$VERSION" ]; then
                warn "No stable release found, using latest pre-release"
                VERSION=$(curl -fsSL "$api_url" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
            fi
            ;;
        prerelease)
            # Get most recent release (including pre-releases)
            VERSION=$(curl -fsSL "$api_url" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
            ;;
        v*.*.*)
            # Use specific version provided
            VERSION="$SMAQIT_EXT_VERSION"
            ;;
        *)
            error "Invalid SMAQIT_EXT_VERSION: $SMAQIT_EXT_VERSION (use 'latest', 'prerelease', or 'vX.Y.Z')"
            ;;
    esac
    
    if [ -z "$VERSION" ]; then
        error "Failed to fetch release version"
    fi
    
    info "Installing version: ${VERSION}"
}

# Download binary
download_binary() {
    local binary_name="smaqit-extensions_${OS}_${ARCH}"
    
    if [ "$OS" = "windows" ]; then
        binary_name="${binary_name}.exe"
    fi
    
    local download_url="https://github.com/${REPO}/releases/download/${VERSION}/${binary_name}"
    TEMP_FILE="/tmp/smaqit-extensions_${VERSION}"
    
    info "Downloading from ${download_url}..."
    
    if ! curl -fsSL -o "$TEMP_FILE" "$download_url"; then
        error "Failed to download binary"
    fi
    
    info "Download complete"
}

# Install binary
install_binary() {
    local target="${INSTALL_DIR}/smaqit-extensions"
    
    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"
    
    # Make executable
    chmod +x "$TEMP_FILE"
    
    # Move to install directory
    mv "$TEMP_FILE" "$target"
    
    info "Installed to ${target}"
}

# Verify installation
verify_installation() {
    local target="${INSTALL_DIR}/smaqit-extensions"
    
    if ! "$target" --version &>/dev/null; then
        error "Installation verification failed"
    fi
    
    local installed_version=$("$target" --version 2>&1 || echo "unknown")
    info "Verified installation: ${installed_version}"
}

# Check if install directory is in PATH
check_path() {
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        warn "${INSTALL_DIR} is not in your PATH"
        echo ""
        echo "Add to your shell config (~/.bashrc, ~/.zshrc, etc.):"
        echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo ""
        echo "Then reload your shell:"
        echo "  source ~/.bashrc  # or ~/.zshrc"
        echo ""
    fi
}

# Main installation flow
main() {
    echo "smaqit-extensions installer"
    echo "==========================="
    echo ""
    
    detect_platform
    get_latest_version
    
    download_binary
    install_binary
    verify_installation
    check_path
    
    echo ""
    info "Installation complete!"
    echo ""
    echo "Get started:"
    echo "  cd your-project"
    echo "  smaqit-extensions      # Install extensions in current project"
    echo "  smaqit-extensions --help   # View available options"
    echo ""
}

main
