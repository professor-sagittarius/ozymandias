#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/mojave" ]]; then
	echo "install.sh: error: cannot find mojave script at $SCRIPT_DIR/mojave" >&2
	exit 1
fi
if [[ ! -f "$SCRIPT_DIR/mojave-policy.json" ]]; then
	echo "install.sh: error: cannot find mojave-policy.json at $SCRIPT_DIR/mojave-policy.json" >&2
	exit 1
fi
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/mojave" "$INSTALL_DIR/mojave"
chmod +x "$INSTALL_DIR/mojave"
cp "$SCRIPT_DIR/mojave-policy.json" "$INSTALL_DIR/mojave-policy.json"
echo "Installed mojave to $INSTALL_DIR/mojave"
echo "Installed mojave-policy.json to $INSTALL_DIR/mojave-policy.json"
echo "Make sure $INSTALL_DIR is on your PATH."
