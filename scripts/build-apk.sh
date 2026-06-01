#!/usr/bin/env bash
#
# build-apk.sh — build the Virdan Flutter APK for on-device testing.
#
# Usage:
#   ./scripts/build-apk.sh            # release APK (default)
#   ./scripts/build-apk.sh --debug    # debug APK
#
set -euo pipefail

# Resolve the project root from this script's location so it runs from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

MODE="release"
for arg in "$@"; do
  case "$arg" in
    --debug)   MODE="debug" ;;
    --release) MODE="release" ;;
    -h|--help)
      echo "Usage: ./scripts/build-apk.sh [--release|--debug]   (default: release)"
      exit 0 ;;
    *) echo "Unknown argument: $arg (use --release or --debug)" >&2; exit 1 ;;
  esac
done

command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter not found in PATH" >&2; exit 1; }

echo ">> flutter pub get"
flutter pub get

echo ">> flutter build apk --$MODE"
flutter build apk "--$MODE"

OUT_DIR="build/app/outputs/flutter-apk"
echo
echo ">> Build done. APK in $OUT_DIR:"
ls -lh "$OUT_DIR"/*.apk 2>/dev/null || { echo "ERROR: no APK produced in $OUT_DIR" >&2; exit 1; }
