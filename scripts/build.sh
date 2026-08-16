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
#     ./scripts/build.sh apk             # release APK (explicit)
#     ./scripts/build.sh aab             # Play App Bundle (.aab, smallest per device)
#     ./scripts/build.sh --bump          # bump build number (+N) first, then build
#     ./scripts/build.sh release --bump  # combine freely
#     ./scripts/build.sh aab --bump      # bump + build production Play bundle
#
# For the Play Store upload use `aab` — Google re-splits it per device, so
# installs land ~25MB instead of the ~60MB universal APK. Use `split` for
# hand-installing a smaller APK on your own phone.
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
BUNDLE=0            # 1 -> build .aab (Play App Bundle) instead of APK
BUMP=0              # 1 -> increment build number first
for arg in "$@"; do
  case "$arg" in
    debug|release) MODE="$arg" ;;
    apk)           MODE="release" ;;
    split)         SPLIT="split" ;;
    aab)           BUNDLE=1 ;;
    --bump|-b)     BUMP=1 ;;
    *) echo "✗ unknown arg: $arg" >&2
       echo "  valid: debug | release | apk | split | aab | --bump" >&2
       exit 2 ;;
  esac
done

# App Bundles are always release, and per-ABI splitting is Play's job.
if [[ "$BUNDLE" == "1" ]]; then
  MODE="release"
  SPLIT=""
fi

# Uploadable/versioned artifacts must prove both app behavior and backend
# access control before the version changes or Gradle starts.
if [[ "$BUMP" == "1" || "$BUNDLE" == "1" ]]; then
  echo "▶ Preflight: analyze + Flutter tests + Firestore rules tests"
  test_log="$(mktemp)"
  if flutter pub get >"$test_log" 2>&1; then
    echo "✓ Dependencies ready"
  else
    echo "✗ Dependency resolution failed"
    tail -40 "$test_log"
    rm -f "$test_log"
    exit 1
  fi
  if flutter analyze --no-pub >"$test_log" 2>&1; then
    echo "✓ Analysis passed"
  else
    echo "✗ Analysis failed"
    tail -60 "$test_log"
    rm -f "$test_log"
    exit 1
  fi
  if flutter test --no-pub >"$test_log" 2>&1; then
    echo "✓ Flutter tests passed"
  else
    echo "✗ Flutter tests failed"
    tail -120 "$test_log"
    rm -f "$test_log"
    exit 1
  fi
  if npm run test:rules >"$test_log" 2>&1; then
    echo "✓ Firestore rules tests passed"
  else
    echo "✗ Firestore rules tests failed"
    tail -60 "$test_log"
    rm -f "$test_log"
    exit 1
  fi
  rm -f "$test_log"
fi

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

# Keep the one user-visible version label synchronized with pubspec metadata.
# This runs on every build, so a manual pubspec edit cannot leave About stale.
ABOUT_FILE="$ROOT/lib/ui/settings/about_content.dart"
if [[ -f "$ABOUT_FILE" ]]; then
  sed -i -E \
    "s|^const aboutVersion = .*;|const aboutVersion = '${VERSION_NAME} (build ${VERSION_CODE})';|" \
    "$ABOUT_FILE"
fi

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

# PurchaseVerifier deliberately defaults to no entitlement when the licensing
# key is absent. Keep the key outside source control and command output, but do
# not allow an uploadable Play bundle that can never validate a purchase.
DEFINE_ARGS=()
# The Play licensing key is public and already recorded in the release guide.
# Load it by content instead of a line number so documentation edits are safe.
if [[ "$BUNDLE" == "1" && -z "${PLAY_PUBLIC_KEY:-}" ]]; then
  PLAY_PUBLIC_KEY="$(sed -n -E \
    's|^flutter build appbundle --dart-define=PLAY_PUBLIC_KEY=(.*)$|\1|p' \
    "$ROOT/docs/PLAY_RELEASE.md" | head -1)"
fi
if [[ -n "${PLAY_PUBLIC_KEY:-}" ]]; then
  DEFINE_ARGS+=("--dart-define=PLAY_PUBLIC_KEY=${PLAY_PUBLIC_KEY}")
elif [[ "$BUNDLE" == "1" ]]; then
  echo "✗ PLAY_PUBLIC_KEY is required for a Play App Bundle." >&2
  echo "  Set it or restore its canonical command in docs/PLAY_RELEASE.md." >&2
  exit 1
elif [[ "$MODE" == "release" ]]; then
  echo "⚠ PLAY_PUBLIC_KEY not set; Play purchase verification is disabled in this APK."
fi

if [[ "$BUNDLE" == "1" ]]; then
  flutter build appbundle --release --no-pub "${DEFINE_ARGS[@]}"
  src="$ROOT/build/app/outputs/bundle/release/app-release.aab"
  dest="$DIST/FoxyCo-${LABEL}.aab"
  cp "$src" "$dest"
  echo "  ✓ $(basename "$dest")  ($(du -h "$dest" | cut -f1))"
  echo ""
  echo "Done — App Bundle in: $DIST"
  echo "Upload this .aab to the Play Console (Google re-splits it per device)."
  exit 0
fi

flutter build apk "${BUILD_ARGS[@]}" "${DEFINE_ARGS[@]}"

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
