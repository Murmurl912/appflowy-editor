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
cp node_modules/katex/dist/katex.min.css dist/katex.min.css
mkdir -p dist/fonts
cp node_modules/katex/dist/fonts/*.woff2 dist/fonts/

echo "Copying to Flutter assets..."
ASSETS="../assets/web/tiptap"
mkdir -p "$ASSETS/fonts"
cp dist/tiptap-bundle.js dist/tiptap.css dist/katex.min.css "$ASSETS/"
cp dist/fonts/*.woff2 "$ASSETS/fonts/"

echo "Done! Bundle size:"
ls -lh dist/tiptap-bundle.js
