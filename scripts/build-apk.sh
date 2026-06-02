#!/usr/bin/env bash
#
# build-apk.sh — build the Virdan Flutter APK for on-device testing.
#
# Usage:
#   ./scripts/build-apk.sh                              # release APK, default API (virdan.cloud)
#   ./scripts/build-apk.sh --debug                      # debug APK
#   ./scripts/build-apk.sh --api https://x.ngrok.app    # custom API (ngrok / local)
#   API_URL=http://192.168.1.10:8081 ./scripts/build-apk.sh   # via env
#
# API target precedence: --api flag > API_URL env > interactive prompt > default.
# '/api' is appended automatically when missing.
#
set -euo pipefail

DEFAULT_API="https://virdan.cloud/api"

# Resolve the project root from this script's location so it runs from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

MODE="release"
API_URL="${API_URL:-}"   # honor env override; flag below wins over it

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)   MODE="debug"; shift ;;
    --release) MODE="release"; shift ;;
    --api)     API_URL="${2:-}"; shift 2 ;;
    --api=*)   API_URL="${1#*=}"; shift ;;
    -h|--help)
      cat <<EOF
Usage: ./scripts/build-apk.sh [--release|--debug] [--api <url>]

  --release       Build release APK (default)
  --debug         Build debug APK
  --api <url>     API base URL (ngrok / local). '/api' appended if missing.
                  Default: $DEFAULT_API
                  Env API_URL is also honored. Interactive prompt if neither set.
EOF
      exit 0 ;;
    *) echo "Unknown argument: $1 (use --release, --debug, or --api <url>)" >&2; exit 1 ;;
  esac
done

# No flag/env API set: ask interactively when attached to a terminal, else default.
if [[ -z "$API_URL" ]]; then
  if [[ -t 0 ]]; then
    echo "Select API target:"
    echo "  1) Default  — $DEFAULT_API"
    echo "  2) Custom   — ngrok / local (enter URL)"
    read -rp "Choice [1/2] (default 1): " choice
    case "$choice" in
      2) read -rp "API base URL: " API_URL ;;
      *) API_URL="$DEFAULT_API" ;;
    esac
  else
    API_URL="$DEFAULT_API"
  fi
fi

# Trim trailing slash and ensure the '/api' suffix the app expects.
API_URL="${API_URL%/}"
[[ -n "$API_URL" ]] || { echo "ERROR: empty API URL" >&2; exit 1; }
[[ "$API_URL" == */api ]] || API_URL="$API_URL/api"

command -v flutter >/dev/null 2>&1 || { echo "ERROR: flutter not found in PATH" >&2; exit 1; }

echo ">> API_URL = $API_URL"
echo ">> flutter pub get"
flutter pub get

echo ">> flutter build apk --$MODE --dart-define=API_URL=$API_URL"
flutter build apk "--$MODE" --dart-define=API_URL="$API_URL"

OUT_DIR="build/app/outputs/flutter-apk"
echo
echo ">> Build done. APK in $OUT_DIR:"
ls -lh "$OUT_DIR"/*.apk 2>/dev/null || { echo "ERROR: no APK produced in $OUT_DIR" >&2; exit 1; }
