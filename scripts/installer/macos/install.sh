#!/usr/bin/env bash
# Codex++ 一行安装入口：下载 → 清 quarantine → 调 installer CLI 装到 /Applications
#
# Default: 从 GitHub Release 下载最新 macOS Universal .pkg
# 也支持本地文件：bash install.sh /path/to/CodexPlusPlus-...-macos-universal.pkg
#
# 因为 .pkg 是 ad-hoc 签名（无 Apple Developer ID），下载后会被打 quarantine。
# \`xattr -cr\` 移除 quarantine 后 \`installer\` 不会再被 Gatekeeper 拦截。

set -euo pipefail

RELEASE_TAG="${RELEASE_TAG:-v1.2.21-macos}"
PKG_NAME="CodexPlusPlus-1.2.21-macos-universal.pkg"
DOWNLOAD_URL="https://github.com/MiMo-ts/codex-/releases/download/${RELEASE_TAG}/${PKG_NAME}"

# Pick source: arg > env PKG_PATH > download latest
if [ "${1:-}" != "" ] && [ -f "$1" ]; then
  PKG="$1"
elif [ "${PKG_PATH:-}" != "" ] && [ -f "$PKG_PATH" ]; then
  PKG="$PKG_PATH"
else
  PKG="/tmp/${PKG_NAME}"
  echo "==> downloading $DOWNLOAD_URL"
  curl -fL --retry 3 -o "$PKG" "$DOWNLOAD_URL"
fi

echo "==> removing quarantine attribute (Gatekeeper unlock)"
xattr -cr "$PKG"
xattr "$PKG" || true

echo "==> installing $PKG to /Applications (sudo required)"
sudo installer -pkg "$PKG" -target /

echo ""
echo "==> verifying"
test -d "/Applications/Codex++.app"          && echo "  ✓ /Applications/Codex++.app"
test -d "/Applications/Codex++ 管理工具.app" && echo "  ✓ /Applications/Codex++ 管理工具.app"
lipo -info "/Applications/Codex++ 管理工具.app/Contents/MacOS/CodexPlusPlusManager" 2>/dev/null \
  | sed 's/^/  /'

echo ""
echo "✓ done. Launch Codex++ 管理工具 from Launchpad or:"
echo "  open '/Applications/Codex++ 管理工具.app'"
