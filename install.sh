#!/usr/bin/env bash
set -e

INSTALL_DIR="${1:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building mpd..."
cd "$SCRIPT_DIR"
dart compile exe bin/main.dart -o bin/mpd

echo "Installing to $INSTALL_DIR/mpd..."
cp bin/mpd "$INSTALL_DIR/mpd"
chmod +x "$INSTALL_DIR/mpd"

echo "Done. Run 'mpd --help' to verify."
