#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="MorningWake"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> 1. 编译 Release 版本二进制 (Target: Apple Silicon M4 / arm64)..."
cd "$ROOT_DIR"
swift build -c release --arch arm64

RELEASE_BIN="$(swift build -c release --arch arm64 --show-bin-path)/$APP_NAME"
BUNDLE_RESOURCE_DIR="$(swift build -c release --arch arm64 --show-bin-path)/${APP_NAME}_${APP_NAME}.bundle"

echo "==> 2. 构建 .app 目录结构..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "==> 3. 复制可执行文件与资源..."
cp "$RELEASE_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Support/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -d "$BUNDLE_RESOURCE_DIR" ]; then
    cp -R "$BUNDLE_RESOURCE_DIR" "$APP_BUNDLE/Contents/Resources/"
fi

# 复制高清 AppIcon
if [ ! -f "$ROOT_DIR/Support/AppIcon.icns" ]; then
    echo "==> 生成高清 App 图标..."
    swift "$ROOT_DIR/Support/generate_icon.swift"
fi
cp "$ROOT_DIR/Support/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# 复制备用音频
cp "$ROOT_DIR/Sources/MorningWake/Resources/fallback_alarm.wav" "$APP_BUNDLE/Contents/Resources/"

echo "==> 4. 进行 Ad-hoc 代码签名..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> 5. 构建完成！"
echo "应用包路径: $APP_BUNDLE"
echo ""
echo "如需直接运行，请执行: open \"$APP_BUNDLE\""
echo "如需安装到系统，请执行: cp -R \"$APP_BUNDLE\" /Applications/"
