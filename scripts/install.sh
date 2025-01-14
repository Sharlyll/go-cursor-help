#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Check for required commands
check_requirements() {
    local commands=("curl" "jq" "sha256sum")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${RED}Error: $cmd is required but not installed${NC}"
            exit 1
        fi
    done
}

# Detect system information
detect_system() {
    local os arch
    case "$(uname -s)" in
        Linux*) os="linux" ;;
        Darwin*) os="darwin" ;;
        *) echo -e "${RED}Unsupported OS${NC}" && exit 1 ;;
    esac

    case "$(uname -m)" in
        x86_64) arch="x86_64" ;;
        aarch64|arm64) arch="arm64" ;;
        i386|i686) arch="i386" ;;
        *) echo -e "${RED}Unsupported architecture${NC}" && exit 1 ;;
    esac

    echo "$os $arch"
}

# Download a file with verification
download_and_verify() {
    local url="$1"
    local output="$2"
    local checksum_url="${url}.sha256"

    echo -e "${BLUE}Downloading file...${NC}"
    curl -fsSL "$url" -o "$output"

    echo -e "${BLUE}Downloading checksum...${NC}"
    curl -fsSL "$checksum_url" -o "${output}.sha256"

    echo -e "${BLUE}Verifying checksum...${NC}"
    sha256sum -c "${output}.sha256" || {
        echo -e "${RED}Error: Checksum verification failed${NC}"
        exit 1
    }
}

# Create installation directory if needed
setup_install_dir() {
    local install_dir="$1"
    if [ ! -d "$install_dir" ]; then
        mkdir -p "$install_dir" || {
            echo -e "${RED}Failed to create installation directory${NC}"
            exit 1
        }
    fi
}

# Main installation function
main() {
    check_requirements

    echo -e "${BLUE}Starting installation...${NC}"

    # Detect system
    read -r OS ARCH <<< "$(detect_system)"
    echo -e "${GREEN}Detected system: $OS $ARCH${NC}"

    # Set installation directory
    INSTALL_DIR="/usr/local/bin"

    # Setup installation directory
    setup_install_dir "$INSTALL_DIR"

    # Fetch latest release information
    echo -e "${BLUE}Fetching latest release information...${NC}"
    LATEST_URL="https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest"
    RELEASE_INFO=$(curl -fsSL "$LATEST_URL")

    # Get the latest version and binary name
    VERSION=$(echo "$RELEASE_INFO" | jq -r ".tag_name" | sed 's/^v//')
    BINARY_NAME="cursor-id-modifier_${VERSION}_${OS}_${ARCH}"

    echo -e "${BLUE}Looking for binary: $BINARY_NAME${NC}"

    # Get the download URL
    DOWNLOAD_URL=$(echo "$RELEASE_INFO" | jq -r ".assets[] | select(.name == \"$BINARY_NAME\") | .browser_download_url")

    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}Error: Could not find appropriate binary for $OS $ARCH${NC}"
        echo -e "${YELLOW}Available assets:${NC}"
        echo "$RELEASE_INFO" | jq -r ".assets[].name"
        exit 1
    fi

    echo -e "${GREEN}Found matching asset${NC}"
    echo -e "${BLUE}Downloading from: $DOWNLOAD_URL${NC}"

    # Download and verify the binary
    download_and_verify "$DOWNLOAD_URL" "$TMP_DIR/cursor-id-modifier"

    # Install binary
    echo -e "${BLUE}Installing binary...${NC}"
    chmod +x "$TMP_DIR/cursor-id-modifier"
    sudo mv "$TMP_DIR/cursor-id-modifier" "$INSTALL_DIR/"

    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "${BLUE}Running cursor-id-modifier to verify installation...${NC}"

    # Run the program with sudo
    if ! sudo "$INSTALL_DIR/cursor-id-modifier"; then
        echo -e "${RED}Error: Failed to run cursor-id-modifier${NC}"
        exit 1
    fi

    echo -e "${GREEN}Program ran successfully!${NC}"
}

main
