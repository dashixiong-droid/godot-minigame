#!/bin/bash
# pack_tpz.sh — Package Godot WASM build artifacts into a .tpz file
# Usage: ./scripts/pack_tpz.sh <godot_version> <build_dir> [output_name]
#
# The .tpz is a zip archive containing:
#   engine/         — Godot engine WASM + JS files
#   game.js         — WeChat Mini Game entry point
#   game.json       — WeChat Mini Game config
#   godot-loader.js — Godot loader for WeChat
#   weapp-adapter.js — WeChat API adapter
#   project.config.json — WeChat project config
#   README.md       — Usage instructions

set -euo pipefail

GODOT_VERSION="${1:-4.6.2}"
BUILD_DIR="${2:-godot-engine/bin/.web_zip}"
OUTPUT_NAME="${3:-minigame${GODOT_VERSION}.tpz}"
PACK_DIR="/tmp/tpz-pack-$$"

echo "=== Packing tpz: $OUTPUT_NAME ==="
echo "  Godot version: $GODOT_VERSION"
echo "  Build dir: $BUILD_DIR"

# Clean and create pack directory
rm -rf "$PACK_DIR"
mkdir -p "$PACK_DIR/engine"
mkdir -p "$PACK_DIR/images"

# Copy engine files
echo "Copying engine files..."
for f in godot.js godot.wasm godot.wasm.br godot.side.wasm godot.side.wasm.br \
         godot.audio.worklet.js godot.audio.position.worklet.js godot.audio.worker.js \
         godot.service.worker.js godot.html godot.offline.html; do
  if [ -f "$BUILD_DIR/$f" ]; then
    cp -v "$BUILD_DIR/$f" "$PACK_DIR/engine/"
  fi
done

# Create game.js — WeChat Mini Game entry point
cat > "$PACK_DIR/game.js" << 'GAMEJS'
// WeChat Mini Game entry point
require("./weapp-adapter.js");
require("./godot-loader.js");
GAMEJS

# Create game.json — WeChat Mini Game config
cat > "$PACK_DIR/game.json" << GAMEJSON
{
  "deviceOrientation": "landscape",
  "showStatusBar": false,
  "networkTimeout": {
    "request": 10000,
    "connectSocket": 10000,
    "uploadFile": 10000,
    "downloadFile": 10000
  },
  "workers": "workers",
  "subpackages": []
}
GAMEJSON

# Create project.config.json
cat > "$PACK_DIR/project.config.json" << PROJCONFIG
{
  "description": "Godot ${GODOT_VERSION} WeChat Mini Game",
  "packOptions": {
    "ignore": [
      {
        "type": "file",
        "value": "*.md"
      }
    ]
  },
  "setting": {
    "urlCheck": true,
    "es6": true,
    "enhance": true,
    "postcss": true,
    "preloadBackgroundData": false,
    "minified": true,
    "newFeature": true,
    "coverView": true,
    "nodeModules": false,
    "autoAudits": false,
    "showShadowRootInWxmlPanel": true,
    "scopeDataCheck": false,
    "uglifyFileName": false,
    "checkInvalidKey": true,
    "checkSiteMap": true,
    "uploadWithSourceMap": true,
    "compileHotReLoad": false,
    "lazyloadPlaceholderEnable": false,
    "useMultiFrameRuntime": true,
    "useApiHook": true,
    "useApiHostProcess": true,
    "babelSetting": {
      "ignore": [],
      "disablePlugins": [],
      "outputPath": ""
    },
    "enableEngineNative": false,
    "useIsolateContext": true,
    "userConfirmedBundleSwitch": false,
    "packNpmManually": false,
    "packNpmRelationList": [],
    "minifyWXSS": true,
    "disableUseStrict": false,
    "minifyWXML": true,
    "showES6CompileOption": false,
    "useCompilerPlugins": false
  },
  "compileType": "game",
  "libVersion": "3.5.2",
  "appid": "wx0000000000000000",
  "projectname": "godot-minigame-${GODOT_VERSION}",
  "condition": {}
}
PROJCONFIG

# Create README.md
cat > "$PACK_DIR/README.md" << README
# Godot ${GODOT_VERSION} WeChat Mini Game Template

## Usage

1. Open WeChat DevTools
2. Import this directory as a Mini Game project
3. Replace \`engine/demo-pck.bin\` with your game's .pck file
4. Configure \`game.json\` subpackages if needed

## Build Info

- Godot version: ${GODOT_VERSION}
- Build date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Build flags: see CI run for details

## Files

| File | Description |
|------|-------------|
| engine/godot.js | Godot engine JS runtime |
| engine/godot.wasm | Godot engine WebAssembly |
| engine/godot.wasm.br | Brotli-compressed WASM |
| engine/godot.side.wasm | Dynamic link side module |
| game.js | Mini Game entry point |
| godot-loader.js | Godot loader for WeChat |
| weapp-adapter.js | WeChat API adapter |
README

# Copy weapp-adapter.js and godot-loader.js from upstream if available,
# otherwise create minimal stubs
if [ -f "skills/sources/weapp-adapter.js" ]; then
  cp -v "skills/sources/weapp-adapter.js" "$PACK_DIR/"
else
  echo "WARNING: weapp-adapter.js not found, creating stub"
  echo "// WeChat adapter stub — replace with real weapp-adapter.js" > "$PACK_DIR/weapp-adapter.js"
fi

if [ -f "skills/sources/godot-loader.js" ]; then
  cp -v "skills/sources/godot-loader.js" "$PACK_DIR/"
else
  echo "WARNING: godot-loader.js not found, creating stub"
  echo "// Godot loader stub — replace with real godot-loader.js" > "$PACK_DIR/godot-loader.js"
fi

# Create the tpz (zip)
echo "Creating $OUTPUT_NAME..."
cd "$PACK_DIR"
zip -r "/tmp/$OUTPUT_NAME" . -x "*.md" 2>&1
cd -

# Move to output
mkdir -p output
mv "/tmp/$OUTPUT_NAME" "output/$OUTPUT_NAME"

echo "=== Done ==="
ls -lh "output/$OUTPUT_NAME"
echo "Contents:"
unzip -l "output/$OUTPUT_NAME"

# Cleanup
rm -rf "$PACK_DIR"
