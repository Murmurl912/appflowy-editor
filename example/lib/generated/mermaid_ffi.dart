/// Dart FFI bindings for mermaid_ffi (pure C API).
///
/// Rust exports:
///   mermaid_render(input: *const c_char) -> *mut c_char  (SVG or null)
///   mermaid_free_string(s: *mut c_char) -> void
library mermaid_ffi;

import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

typedef _MermaidRenderC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);
typedef _MermaidRenderDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

typedef _MermaidFreeC = ffi.Void Function(ffi.Pointer<Utf8>);
typedef _MermaidFreeDart = void Function(ffi.Pointer<Utf8>);

class MermaidFfi {
  MermaidFfi._(this._lib);

  final ffi.DynamicLibrary _lib;

  late final _render = _lib
      .lookupFunction<_MermaidRenderC, _MermaidRenderDart>('mermaid_render');
  late final _renderDark = _lib
      .lookupFunction<_MermaidRenderC, _MermaidRenderDart>('mermaid_render_dark');
  late final _free = _lib
      .lookupFunction<_MermaidFreeC, _MermaidFreeDart>('mermaid_free_string');

  /// Open from a [DynamicLibrary] instance.
  factory MermaidFfi.fromLibrary(ffi.DynamicLibrary lib) = MermaidFfi._;

  /// Open from a file path.
  factory MermaidFfi.open(String path) =>
      MermaidFfi._(ffi.DynamicLibrary.open(path));

  /// Open using [DynamicLibrary.process] (iOS / macOS static linking).
  factory MermaidFfi.process() =>
      MermaidFfi._(ffi.DynamicLibrary.process());

  String? _call(ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>) fn, String input) {
    final inputPtr = input.toNativeUtf8();
    try {
      final resultPtr = fn(inputPtr);
      if (resultPtr == ffi.nullptr) return null;
      try {
        return resultPtr.toDartString();
      } finally {
        _free(resultPtr);
      }
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// Render with light theme.
  String? renderMermaid(String input) => _call(_render, input);

  /// Render with dark theme.
  String? renderMermaidDark(String input) => _call(_renderDark, input);
}
