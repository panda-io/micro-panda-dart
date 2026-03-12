#!/usr/bin/env bash
set -e

INSTALL_DIR="${1:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Embedding std library..."
cd "$SCRIPT_DIR"
dart tool/gen_stdlib.dart

echo "Building mpd..."
dart compile exe bin/main.dart -o bin/mpd

echo "Installing to $INSTALL_DIR/mpd..."
cp bin/mpd "$INSTALL_DIR/mpd"
chmod +x "$INSTALL_DIR/mpd"

echo "Done. Run 'mpd --help' to verify."
