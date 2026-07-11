#!/usr/bin/env bash
#
# FoxyCo build helper — produces a uniquely-named APK so copies never collide
# on your phone. Instead of the generic `app-release.apk`, you get e.g.:
#
#     FoxyCo-v1.0.0+3-release-20260710-1327.apk
#
# The name carries the pubspec version (name+code), the build flavor, and a
# timestamp — so sorting by name = sorting by build, and nothing ever needs
# a "(1)" / "(2)" suffix.
#
# Usage (args are order-independent):
#     ./scripts/build.sh                 # release APK (default)
#     ./scripts/build.sh debug           # debug APK
#     ./scripts/build.sh release         # release APK (explicit)
#     ./scripts/build.sh split           # per-ABI release APKs (smaller)
#     ./scripts/build.sh --bump          # bump build number (+N) first, then build
#     ./scripts/build.sh release --bump  # combine freely
#
# --bump increments the "+N" build code in pubspec.yaml (1.0.0+3 -> 1.0.0+4)
# BEFORE building, so the new number shows up in the APK name and inside the app.
#
# Output lands in:  dist/
set -euo pipefail

# --- resolve project root (this script's parent dir) ---------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
cd "$ROOT"

# --- parse args (order-independent) -------------------------------------------
MODE="release"      # debug | release
SPLIT=""            # "split" -> --split-per-abi
BUMP=0              # 1 -> increment build number first
for arg in "$@"; do
  case "$arg" in
    debug|release) MODE="$arg" ;;
    split)         SPLIT="split" ;;
    --bump|-b)     BUMP=1 ;;
    *) echo "✗ unknown arg: $arg" >&2
       echo "  valid: debug | release | split | --bump" >&2
       exit 2 ;;
  esac
done

# --- optionally bump the build number in pubspec.yaml -------------------------
if [[ "$BUMP" == "1" ]]; then
  cur="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
  name="${cur%%+*}"                                  # 1.0.0
  code="${cur##*+}"                                  # 3
  if ! [[ "$code" =~ ^[0-9]+$ ]]; then
    echo "✗ can't bump: build code '$code' is not a number (version: $cur)" >&2
    exit 1
  fi
  next="$name+$((code+1))"
  # Replace only the version: line, keep everything else untouched.
  sed -i -E "s|^version:.*|version: $next|" pubspec.yaml
  echo "⬆ version bumped: $cur → $next"
fi

# --- read (possibly bumped) version from pubspec.yaml -------------------------
VERSION_LINE="$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"                 # 1.0.0
VERSION_CODE="${VERSION_LINE##*+}"                 # 4
STAMP="$(date +%Y%m%d-%H%M)"                        # 20260710-1327
LABEL="v${VERSION_NAME}+${VERSION_CODE}-${MODE}-${STAMP}"

DIST="$ROOT/dist"
mkdir -p "$DIST"

echo "▶ FoxyCo build: $MODE${SPLIT:+ ($SPLIT)}  →  $LABEL"

# --- build --------------------------------------------------------------------
# NB: the flavor is a FLAG (--release / --debug), not a positional arg — passing
# it bare makes Flutter treat it as a target file ("Target file release not found").
BUILD_ARGS=("--$MODE")
[[ "$SPLIT" == "split" ]] && BUILD_ARGS+=("--split-per-abi")

flutter build apk "${BUILD_ARGS[@]}"

APK_DIR="$ROOT/build/app/outputs/flutter-apk"

# --- copy out with a unique name ----------------------------------------------
copied=0
if [[ "$SPLIT" == "split" ]]; then
  # per-ABI: app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, ...
  for apk in "$APK_DIR"/app-*-"$MODE".apk; do
    [[ -e "$apk" ]] || continue
    base="$(basename "$apk")"
    abi="${base#app-}"; abi="${abi%-$MODE.apk}"      # arm64-v8a
    dest="$DIST/FoxyCo-${LABEL}-${abi}.apk"
    cp "$apk" "$dest"
    echo "  ✓ $(basename "$dest")  ($(du -h "$dest" | cut -f1))"
    copied=$((copied+1))
  done
else
  src="$APK_DIR/app-$MODE.apk"
  dest="$DIST/FoxyCo-${LABEL}.apk"
  cp "$src" "$dest"
  echo "  ✓ $(basename "$dest")  ($(du -h "$dest" | cut -f1))"
  copied=1
fi

echo ""
echo "Done — $copied APK(s) in: $DIST"
echo "Latest:"
ls -1t "$DIST"/*.apk | head -3 | sed 's/^/  /'
