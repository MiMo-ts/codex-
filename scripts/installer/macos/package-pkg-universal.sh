#!/usr/bin/env bash
# Build a single Universal `.pkg` installer that auto-installs BOTH
# Codex++ (silent launcher) AND Codex++ 管理工具 (Tauri manager) to
# /Applications in one double-click — no drag-and-drop needed.
#
# Architecture support:
#   • Native x86_64 (Intel)
#   • Native arm64 (Apple Silicon)
#   Cross-compiled via lipo into a single fat binary, so one .pkg runs
#   natively on both architectures.
#
# Prereqs:
#   1. cargo build --release --target x86_64-apple-darwin ...
#   2. cargo build --release --target aarch64-apple-darwin ...
#   3. Frontend built (apps/codex-plus-manager/dist/).
#
# Usage:
#   bash scripts/installer/macos/package-pkg-universal.sh [VERSION]
#
# Env:
#   INTEL_BINARY_DIR  (default: $ROOT/target/x86_64-apple-darwin/release)
#   ARM64_BINARY_DIR  (default: $ROOT/target/aarch64-apple-darwin/release)
#   OUT_DIR           (default: $ROOT/dist/macos)
#
# Output:
#   $OUT_DIR/CodexPlusPlus-${VERSION}-macos-universal.pkg

set -euo pipefail

VERSION="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INTEL_BINARY_DIR="${INTEL_BINARY_DIR:-$ROOT/target/x86_64-apple-darwin/release}"
ARM64_BINARY_DIR="${ARM64_BINARY_DIR:-$ROOT/target/aarch64-apple-darwin/release}"
OUT_DIR="${OUT_DIR:-$ROOT/dist/macos}"

ICON_SOURCE="$ROOT/apps/codex-plus-manager/src-tauri/icons/icon.png"
ICON_NAME="codex-plus-plus.icns"
ICON_ICNS="$OUT_DIR/$ICON_NAME"

if [ -z "$VERSION" ]; then
  VERSION="$(grep '^version' "$ROOT/Cargo.toml" | head -1 | cut -d'"' -f2)"
fi

# Sanity checks
for bin in codex-plus-plus codex-plus-plus-manager; do
  for dir in "$INTEL_BINARY_DIR" "$ARM64_BINARY_DIR"; do
    if [ ! -x "$dir/$bin" ]; then
      echo "error: missing executable $dir/$bin — run 'cargo build --release --target ...' first" >&2
      exit 1
    fi
  done
done

if [ ! -f "$ICON_SOURCE" ]; then
  echo "error: icon source not found: $ICON_SOURCE" >&2
  exit 1
fi

# Layout (everything goes under $OUT_DIR):
#   .universal-bin/           — lipo-merged fat binaries
#   .pkg-stage/               — built .app bundles
#   .pkg-root/Applications/   — staging layout for pkgbuild
#   CodexPlusPlus-<ver>-macos-universal.pkg
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

UNIVERSAL_DIR="$OUT_DIR/.universal-bin"
PKG_STAGE="$OUT_DIR/.pkg-stage"
PKG_ROOT="$OUT_DIR/.pkg-root"
mkdir -p "$UNIVERSAL_DIR" "$PKG_STAGE" "$PKG_ROOT/Applications"

# ---------------------------------------------------------------------------
# Step 1: icns icon (sips + iconutil)
# ---------------------------------------------------------------------------
prepare_icon() {
  local iconset="$OUT_DIR/codex-plus-plus.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"

  sips -z 16   16   "$ICON_SOURCE" --out "$iconset/icon_16x16.png"      >/dev/null
  sips -z 32   32   "$ICON_SOURCE" --out "$iconset/icon_16x16@2x.png"   >/dev/null
  sips -z 32   32   "$ICON_SOURCE" --out "$iconset/icon_32x32.png"      >/dev/null
  sips -z 64   64   "$ICON_SOURCE" --out "$iconset/icon_32x32@2x.png"   >/dev/null
  sips -z 128  128  "$ICON_SOURCE" --out "$iconset/icon_128x128.png"    >/dev/null
  sips -z 256  256  "$ICON_SOURCE" --out "$iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256  256  "$ICON_SOURCE" --out "$iconset/icon_256x256.png"    >/dev/null
  sips -z 512  512  "$ICON_SOURCE" --out "$iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512  512  "$ICON_SOURCE" --out "$iconset/icon_512x512.png"    >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$iconset/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset" -o "$ICON_ICNS"
}

# ---------------------------------------------------------------------------
# Step 2: lipo → fat binary
# ---------------------------------------------------------------------------
make_universal_bin() {
  local intel_bin="$1"
  local arm_bin="$2"
  local out="$3"

  lipo -create "$intel_bin" "$arm_bin" -output "$out"
  chmod +x "$out"

  echo "  ✓ lipo: $(basename "$intel_bin") + $(basename "$arm_bin") → $(basename "$out")"
  lipo -info "$out"
}

# ---------------------------------------------------------------------------
# Step 3: assemble .app bundle
# ---------------------------------------------------------------------------
build_app() {
  local app_name="$1"
  local executable_name="$2"
  local binary_path="$3"
  local bundle_id="$4"
  local lsui_element="${5:-false}"
  local app_dir="$PKG_STAGE/$app_name.app"

  if [ ! -x "$binary_path" ]; then
    echo "error: binary not found or not executable: $binary_path" >&2
    return 1
  fi

  rm -rf "$app_dir"
  mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
  cp "$binary_path" "$app_dir/Contents/MacOS/$executable_name"
  cp "$ICON_ICNS" "$app_dir/Contents/Resources/$ICON_NAME"
  chmod +x "$app_dir/Contents/MacOS/$executable_name"
  printf 'APPL????' > "$app_dir/Contents/PkgInfo"
  cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$app_name</string>
  <key>CFBundleDisplayName</key>
  <string>$app_name</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleExecutable</key>
  <string>$executable_name</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSUIElement</key>
  <$lsui_element/>
</dict>
</plist>
PLIST
}

sign_app() {
  local app_dir="$1"
  local executable
  executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_dir/Contents/Info.plist")"
  codesign --force --sign - "$app_dir/Contents/MacOS/$executable"
  codesign --force --sign - "$app_dir"
}

verify_app() {
  local app_dir="$1"
  local plist="$app_dir/Contents/Info.plist"
  local macos_bin
  macos_bin="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"

  if [ -n "$(command -v plutil || true)" ]; then
    plutil -lint "$plist" >/dev/null
  fi
  if [ ! -f "$app_dir/Contents/PkgInfo" ]; then
    echo "error: missing PkgInfo in $app_dir" >&2
    return 1
  fi
  codesign -dv "$app_dir" >/dev/null 2>&1 || {
    echo "error: codesign verification failed for $app_dir" >&2
    return 1
  }
  local archs
  archs="$(lipo -info "$app_dir/Contents/MacOS/$macos_bin")"
  echo "  ✓ verified: $app_dir"
  echo "      $archs"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
echo "==> Preparing icon..."
prepare_icon

echo "==> lipo-merging launcher (x86_64 + arm64)..."
make_universal_bin \
  "$INTEL_BINARY_DIR/codex-plus-plus" \
  "$ARM64_BINARY_DIR/codex-plus-plus" \
  "$UNIVERSAL_DIR/CodexPlusPlus"

echo "==> lipo-merging manager (x86_64 + arm64)..."
make_universal_bin \
  "$INTEL_BINARY_DIR/codex-plus-plus-manager" \
  "$ARM64_BINARY_DIR/codex-plus-plus-manager" \
  "$UNIVERSAL_DIR/CodexPlusPlusManager"

echo "==> Building .app bundles..."
build_app "Codex++" "CodexPlusPlus" \
  "$UNIVERSAL_DIR/CodexPlusPlus" \
  "com.bigpizzav3.codexplusplus" "true"

build_app "Codex++ 管理工具" "CodexPlusPlusManager" \
  "$UNIVERSAL_DIR/CodexPlusPlusManager" \
  "com.bigpizzav3.codexplusplus.manager" "false"

echo "==> Ad-hoc signing..."
sign_app "$PKG_STAGE/Codex++.app"
sign_app "$PKG_STAGE/Codex++ 管理工具.app"

echo "==> Verifying bundles..."
verify_app "$PKG_STAGE/Codex++.app"
verify_app "$PKG_STAGE/Codex++ 管理工具.app"

echo "==> Staging payload (mimics /Applications layout)..."
cp -R "$PKG_STAGE/Codex++.app"          "$PKG_ROOT/Applications/"
cp -R "$PKG_STAGE/Codex++ 管理工具.app" "$PKG_ROOT/Applications/"

PKG="$OUT_DIR/CodexPlusPlus-${VERSION}-macos-universal.pkg"

echo "==> Building .pkg installer via pkgbuild..."
pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "com.bigpizzav3.codexplusplus" \
  --version "$VERSION" \
  --install-location "/" \
  --ownership recommended \
  "$PKG"

echo ""
echo "✓ Universal PKG installer ready: $PKG"
ls -lh "$PKG"

echo ""
echo "==> Payload summary:"
pkgutil --payload-files "$PKG" 2>/dev/null || true
echo ""
echo "Install (one-click):"
echo "    open '$PKG'       # double-click → auto-install both .app to /Applications"
echo "Or via CLI:"
echo "    sudo installer -pkg '$PKG' -target /"
