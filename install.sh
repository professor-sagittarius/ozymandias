#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${1:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/ozymandias" ]]; then
	echo "install.sh: error: cannot find ozymandias script at $SCRIPT_DIR/ozymandias" >&2
	exit 1
fi
if [[ ! -f "$SCRIPT_DIR/ozymandias-policy.json" ]]; then
	echo "install.sh: error: cannot find ozymandias-policy.json at $SCRIPT_DIR/ozymandias-policy.json" >&2
	exit 1
fi
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/ozymandias" "$INSTALL_DIR/ozymandias"
chmod +x "$INSTALL_DIR/ozymandias"
cp "$SCRIPT_DIR/ozymandias-policy.json" "$INSTALL_DIR/ozymandias-policy.json"
echo "Installed ozymandias to $INSTALL_DIR/ozymandias"
echo "Installed ozymandias-policy.json to $INSTALL_DIR/ozymandias-policy.json"
echo "Make sure $INSTALL_DIR is on your PATH."
