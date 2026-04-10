import 'dart:io';

import 'package:example/generated/mermaid_ffi.dart';

/// Native Mermaid diagram renderer powered by mermaid-rs-renderer (Rust).
///
/// ```dart
/// MermaidRenderer.init(); // once
/// final svg = MermaidRenderer.render('flowchart LR; A-->B-->C');
/// ```
class MermaidRenderer {
  static MermaidFfi? _ffi;

  /// Initialize with platform-appropriate library loading.
  /// For development, pass [libraryPath] to a debug dylib.
  static bool get isAvailable => _ffi != null;

  /// Initialize with platform-appropriate library loading.
  /// Returns true if the native library was loaded successfully.
  static bool init({String? libraryPath}) {
    if (_ffi != null) return true;

    try {
      if (libraryPath != null) {
        _ffi = MermaidFfi.open(libraryPath);
      } else if (Platform.isAndroid) {
        _ffi = MermaidFfi.open('libmermaid_ffi.so');
      } else if (Platform.isIOS || Platform.isMacOS) {
        _ffi = MermaidFfi.process();
      } else if (Platform.isLinux) {
        _ffi = MermaidFfi.open('libmermaid_ffi.so');
      } else if (Platform.isWindows) {
        _ffi = MermaidFfi.open('mermaid_ffi.dll');
      }
      return _ffi != null;
    } catch (e) {
      // Native library not available (not compiled/bundled yet)
      _ffi = null;
      return false;
    }
  }

  /// Render a Mermaid diagram to SVG.
  static String render(String mermaidSource, {bool dark = false}) {
    if (_ffi == null) {
      throw StateError('MermaidRenderer.init() must be called first');
    }
    final svg = dark
        ? _ffi!.renderMermaidDark(mermaidSource)
        : _ffi!.renderMermaid(mermaidSource);
    if (svg == null) {
      throw MermaidRenderException('Failed to render: $mermaidSource');
    }
    return svg;
  }

  /// Try to render, returning null on failure instead of throwing.
  static String? tryRender(String mermaidSource, {bool dark = false}) {
    if (_ffi == null) return null;
    return dark
        ? _ffi!.renderMermaidDark(mermaidSource)
        : _ffi!.renderMermaid(mermaidSource);
  }
}

class MermaidRenderException implements Exception {
  final String message;
  MermaidRenderException(this.message);

  @override
  String toString() => 'MermaidRenderException: $message';
}
