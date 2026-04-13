#!/bin/bash
# Build TipTap bundle and copy to Flutter assets
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building TipTap bundle..."
npx esbuild src/index.ts \
  --bundle --minify \
  --outfile=dist/tiptap-bundle.js \
  --format=iife \
  --global-name=TiptapEditor \
  --target=es2020

cp src/style.css dist/tiptap.css

echo "Copying to Flutter assets..."
mkdir -p ../assets/web/tiptap
cp dist/tiptap-bundle.js dist/tiptap.css ../assets/web/tiptap/

echo "Done! Bundle size:"
ls -lh dist/tiptap-bundle.js
