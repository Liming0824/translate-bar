#!/bin/bash
set -e

APP_NAME="TranslateBar"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR=".build/release"
INSTALL_DIR="/Applications"

echo "Building release binary..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
cp "Sources/TranslateBar/Resources/Info.plist" "$APP_BUNDLE/Contents/"
cp "Sources/TranslateBar/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

echo "Signing..."
codesign --sign - --force --deep "$APP_BUNDLE"

echo "Installing to ~/Applications..."
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/$APP_BUNDLE"
cp -r "$APP_BUNDLE" "$INSTALL_DIR/"

echo "Resetting Accessibility permission (will re-prompt on launch)..."
tccutil reset Accessibility com.translatebar.app 2>/dev/null || true

echo "Done! Launching..."
open "$INSTALL_DIR/$APP_BUNDLE"
