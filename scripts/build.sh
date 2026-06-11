#!/bin/bash
set -euo pipefail

# ============================================================
# Godot WASM (WeChat Mini Game) Build Script
# Usage: ./scripts/build.sh [--dlink yes] [--threads no] [--simd no]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$REPO_ROOT/skills"

GODOT_REPO_DIR="${GODOT_REPO_DIR:-$REPO_ROOT/godot-engine}"
DLINK="${DLINK:-yes}"
THREADS="${THREADS:-no}"
SIMD="${SIMD:-no}"
AUDIO_WORKER="${AUDIO_WORKER:-yes}"
BROTLI_QUALITY="${BROTLI_QUALITY:-11}"

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dlink) DLINK="$2"; shift 2 ;;
    --threads) THREADS="$2"; shift 2 ;;
    --simd) SIMD="$2"; shift 2 ;;
    --audio-worker) AUDIO_WORKER="$2"; shift 2 ;;
    --brotli-quality) BROTLI_QUALITY="$2"; shift 2 ;;
    --godot-dir) GODOT_REPO_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "=== Build Configuration ==="
echo "Godot dir:   $GODOT_REPO_DIR"
echo "dlink:       $DLINK"
echo "threads:     $THREADS"
echo "simd:        $SIMD"
echo "audio-worker: $AUDIO_WORKER"
echo "brotli q:    $BROTLI_QUALITY"
echo "==========================="

# Step 1: Apply patches
echo ""
echo "[1/5] Applying minigame patches..."
OPTIONAL_FLAGS=""
if [ "$AUDIO_WORKER" = "yes" ]; then
  OPTIONAL_FLAGS="--include-optional audio-worker"
fi
python3 "$SKILL_DIR/scripts/apply_godot_patchset.py" "$GODOT_REPO_DIR" \
  --allow-base-mismatch \
  --allow-dirty \
  $OPTIONAL_FLAGS

# Step 2: SCons build
echo ""
echo "[2/5] Building with SCons..."
SCONS_FLAGS="platform=web target=template_release"
[ "$DLINK" = "yes" ] && SCONS_FLAGS="$SCONS_FLAGS dlink_enabled=yes"
[ "$THREADS" = "yes" ] && SCONS_FLAGS="$SCONS_FLAGS threads=yes"
[ "$SIMD" = "yes" ] && SCONS_FLAGS="$SCONS_FLAGS wasm_simd=yes"
echo "SCons flags: $SCONS_FLAGS"
(cd "$GODOT_REPO_DIR" && scons $SCONS_FLAGS -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4))

# Step 3: Copy artifacts
echo ""
echo "[3/5] Copying artifacts to .web_zip..."
mkdir -p "$GODOT_REPO_DIR/bin/.web_zip"
cd "$GODOT_REPO_DIR/bin"
cp -v godot.web.template_release.wasm32.nothreads.wasm .web_zip/godot.wasm 2>/dev/null || true
for f in godot.web.template_release.wasm32.nothreads.*.wasm; do
  if [ -f "$f" ]; then
    suffix=$(echo "$f" | sed 's/godot\.web\.template_release\.wasm32\.nothreads\.//')
    cp -v "$f" ".web_zip/godot.${suffix}"
  fi
done
cp -v godot.web.template_release.wasm32.nothreads.js .web_zip/godot.js 2>/dev/null || true

# Step 4: Post-process
echo ""
echo "[4/5] Running godot_process.js..."
node "$SKILL_DIR/scripts/godot_process.js"

# Step 5: Brotli compress
echo ""
echo "[5/5] Brotli compressing wasm files..."
cd "$GODOT_REPO_DIR/bin/.web_zip"
for wasm in *.wasm; do
  echo "Compressing $wasm (quality $BROTLI_QUALITY)..."
  brotli -q "$BROTLI_QUALITY" -f "$wasm" -o "${wasm}.br"
done

echo ""
echo "=== Build Complete ==="
ls -la "$GODOT_REPO_DIR/bin/.web_zip/"
