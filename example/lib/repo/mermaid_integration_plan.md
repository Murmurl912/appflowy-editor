# Mermaid-RS Flutter Integration Plan

## Goal
Use `mermaid-rs-renderer` (pure Rust) to render Mermaid diagrams to SVG natively in Flutter, replacing browser-based mermaid.js.

## Architecture

```
Flutter App
    │ renderMermaid("flowchart LR; A-->B")
    ▼
Dart FFI (flutter_rust_bridge)
    │
    ▼
mermaid-rs-renderer (Rust native library)
    │ parse → layout → render_svg
    ▼
SVG String
    │
    ▼
flutter_svg (SvgPicture.string)
```

## Integration Steps

### Step 1: Setup flutter_rust_bridge
```bash
cargo install flutter_rust_bridge_codegen
flutter pub add flutter_rust_bridge
flutter pub add rust_lib_example  # generated
```

### Step 2: Create Rust FFI module
Create `rust/src/api.rs`:
```rust
use mermaid_rs_renderer::{render, render_with_options, RenderOptions};

pub fn render_mermaid(input: String) -> anyhow::Result<String> {
    render(&input)
}

pub fn render_mermaid_dark(input: String) -> anyhow::Result<String> {
    // TODO: dark theme when mermaid-rs supports it
    render(&input)
}
```

### Step 3: Generate Dart bindings
```bash
flutter_rust_bridge_codegen generate
```

### Step 4: Use in Flutter
```dart
import 'package:flutter_svg/flutter_svg.dart';

final svg = await renderMermaid('flowchart LR; A-->B-->C');
SvgPicture.string(svg);
```

### Step 5: Integrate with editor
- Flutter editor: Custom `MermaidBlockComponent` renders SVG via `flutter_svg`
- Web editor: Vditor's built-in mermaid.js continues to work in WebView

## Dependencies to Add
- `flutter_rust_bridge: ^2.0.0`
- `flutter_svg: ^2.0.0` (for rendering SVG in Flutter)

## Build Configuration
- Android: Rust cross-compile to `aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`
- iOS: Rust cross-compile to `aarch64-apple-ios`, `aarch64-apple-ios-sim`
- Handled automatically by `flutter_rust_bridge`
