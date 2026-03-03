#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"
cp "$(dirname "$0")/mojave" "$INSTALL_DIR/mojave"
chmod +x "$INSTALL_DIR/mojave"
echo "Installed mojave to $INSTALL_DIR/mojave"
echo "Make sure $INSTALL_DIR is on your PATH."
