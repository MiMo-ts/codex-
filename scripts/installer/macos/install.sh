#!/usr/bin/env bash
# Codex++ 一行安装入口：下载 .dmg → 清 quarantine → 挂载 → 拖两个 .app 到 /Applications
#
# 推荐路径（DMG）：
#   bash scripts/installer/macos/install.sh
# 也支持本地 dmg / pkg，或用 PACKAGE=... 强制走 .pkg：
#   bash scripts/installer/macos/install.sh /path/to/CodexPlusPlus-...-macos-universal.dmg
#   PACKAGE=pkg bash scripts/installer/macos/install.sh
#
# 因为 .dmg 内 .app 是 ad-hoc 签名（无 Apple Developer ID），下载会被打 quarantine。
# `xattr -cr` 移除 quarantine 后 Gatekeeper 不会再拦。

set -euo pipefail

RELEASE_TAG="${RELEASE_TAG:-v1.2.21-macos}"
DMG_NAME="CodexPlusPlus-1.2.21-macos-universal.dmg"
PKG_NAME="CodexPlusPlus-1.2.21-macos-universal.pkg"
DMG_URL="https://github.com/MiMo-ts/codex-/releases/download/${RELEASE_TAG}/${DMG_NAME}"
PKG_URL="https://github.com/MiMo-ts/codex-/releases/download/${RELEASE_TAG}/${PKG_NAME}"

FORCE_PKG="${FORCE_PKG:-}"

# Pick source: arg > env > download by format
if [ "${1:-}" != "" ] && [ -f "$1" ]; then
  ARTIFACT="$1"
elif [ "${DMG_PATH:-}" != "" ] && [ -f "${DMG_PATH:-}" ]; then
  ARTIFACT="$DMG_PATH"
elif [ "${PKG_PATH:-}" != "" ] && [ -f "${PKG_PATH:-}" ]; then
  ARTIFACT="$PKG_PATH"
  FORCE_PKG=1
else
  if [ -n "$FORCE_PKG" ]; then
    ARTIFACT="/tmp/${PKG_NAME}"
    echo "==> downloading $PKG_URL"
    curl -fL --retry 3 -o "$ARTIFACT" "$PKG_URL"
  else
    ARTIFACT="/tmp/${DMG_NAME}"
    echo "==> downloading $DMG_URL"
    curl -fL --retry 3 -o "$ARTIFACT" "$DMG_URL"
  fi
fi

echo "==> removing quarantine attribute (Gatekeeper unlock)"
xattr -cr "$ARTIFACT"

case "$ARTIFACT" in
  *.dmg)
    echo "==> mounting $ARTIFACT (read-only)"
    MOUNT_OUT="$(hdiutil attach -readonly -nobrowse "$ARTIFACT" 2>&1 | grep -E '/Volumes/' | tail -1)"
    MOUNT_POINT="$(printf '%s' "$MOUNT_OUT" | awk '{print $NF}')"
    echo "==> mounted at: $MOUNT_POINT"
    ls "$MOUNT_POINT"

    echo "==> copying both .app bundles to /Applications (sudo for first-write)"
    sudo cp -R "$MOUNT_POINT/Codex++.app"          /Applications/
    sudo cp -R "$MOUNT_POINT/Codex++ 管理工具.app" /Applications/

    echo "==> detaching DMG"
    hdiutil detach "$MOUNT_POINT" || true
    ;;

  *.pkg)
    echo "==> installing pkg to /Applications (sudo)"
    sudo installer -pkg "$ARTIFACT" -target /
    ;;

  *)
    echo "error: unsupported artifact: $ARTIFACT (expected .dmg or .pkg)" >&2
    exit 1
    ;;
esac

echo ""
echo "==> verifying"
test -d "/Applications/Codex++.app"          && echo "  ✓ /Applications/Codex++.app"
test -d "/Applications/Codex++ 管理工具.app" && echo "  ✓ /Applications/Codex++ 管理工具.app"
lipo -info "/Applications/Codex++ 管理工具.app/Contents/MacOS/CodexPlusPlusManager" 2>/dev/null \
  | sed 's/^/  /'

echo ""
echo "✓ done. Launch Codex++ 管理工具 from Launchpad or:"
echo "  open '/Applications/Codex++ 管理工具.app'"
echo ""
echo "(If Launchpad shows the warning, right-click the app → Open → Open once.)"
