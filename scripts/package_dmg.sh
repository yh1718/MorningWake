#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/MorningWake.app"
DMG_STAGE="$BUILD_DIR/dmg_stage"
DMG_OUTPUT="$BUILD_DIR/MorningWake.dmg"
ZIP_OUTPUT="$BUILD_DIR/MorningWake.zip"

echo "==> 1. 确保最新应用包已构建..."
"$SCRIPT_DIR/build_app.sh"

echo "==> 2. 准备 DMG 镜像内容（含拖拽至 Applications 快捷方式）..."
rm -rf "$DMG_STAGE" "$DMG_OUTPUT" "$ZIP_OUTPUT"
mkdir -p "$DMG_STAGE"

cp -R "$APP_BUNDLE" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

echo "==> 3. 生成压缩版 macOS 原生 .dmg 磁盘镜像..."
hdiutil create -volname "MorningWake" \
               -srcfolder "$DMG_STAGE" \
               -ov \
               -format UDZO \
               "$DMG_OUTPUT"

rm -rf "$DMG_STAGE"

echo "==> 4. 同时生成保留 macOS 元数据的 .zip 归档..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_OUTPUT"

echo "==> 5. 打包完成！"
echo "DMG 文件: $DMG_OUTPUT ($(du -h "$DMG_OUTPUT" | cut -f1))"
echo "ZIP 文件: $ZIP_OUTPUT ($(du -h "$ZIP_OUTPUT" | cut -f1))"
