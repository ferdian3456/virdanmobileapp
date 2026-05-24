#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$PROJECT_ROOT/src-capacitor/android"
APK_SRC="$ANDROID_DIR/app/build/outputs/apk/debug/app-debug.apk"
APK_OUT_DIR="$PROJECT_ROOT/dist-apk"
NODE_VERSION="22.22.2"

cd "$PROJECT_ROOT"

# Load nvm (non-interactive shell needs explicit source)
unset npm_config_prefix
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use "$NODE_VERSION" >/dev/null

# Parse args
CLEAN=0
RELEASE=0
for arg in "$@"; do
  case "$arg" in
    --clean)   CLEAN=1 ;;
    --release) RELEASE=1 ;;
    -h|--help)
      echo "Usage: $0 [--clean] [--release]"
      echo "  --clean    gradle clean before build"
      echo "  --release  build release APK (needs signing config) instead of debug"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

echo "==> Node: $(node -v)"
echo "==> Project: $PROJECT_ROOT"

# Step 1: build web + sync ke native android project
echo "==> [1/3] quasar build (web + capacitor sync)"
quasar build -m capacitor -T android --skip-pkg

# Step 2: gradle assemble
cd "$ANDROID_DIR"

if [ "$CLEAN" -eq 1 ]; then
  echo "==> gradle clean"
  ./gradlew clean
fi

if [ "$RELEASE" -eq 1 ]; then
  echo "==> [2/3] gradle assembleRelease"
  ./gradlew assembleRelease
  APK_SRC="$ANDROID_DIR/app/build/outputs/apk/release/app-release.apk"
  [ -f "$APK_SRC" ] || APK_SRC="$ANDROID_DIR/app/build/outputs/apk/release/app-release-unsigned.apk"
else
  echo "==> [2/3] gradle assembleDebug"
  ./gradlew assembleDebug
fi

cd "$PROJECT_ROOT"

# Step 3: copy APK ke dist-apk dengan timestamp
echo "==> [3/3] copy APK to $APK_OUT_DIR"
mkdir -p "$APK_OUT_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BUILD_TYPE="debug"
[ "$RELEASE" -eq 1 ] && BUILD_TYPE="release"
APK_DEST="$APK_OUT_DIR/virdan-${BUILD_TYPE}-${TIMESTAMP}.apk"
LATEST_LINK="$APK_OUT_DIR/virdan-${BUILD_TYPE}-latest.apk"

cp "$APK_SRC" "$APK_DEST"
ln -sf "$(basename "$APK_DEST")" "$LATEST_LINK"

SIZE="$(du -h "$APK_DEST" | cut -f1)"
echo ""
echo "Build success."
echo "  APK : $APK_DEST"
echo "  Link: $LATEST_LINK"
echo "  Size: $SIZE"
