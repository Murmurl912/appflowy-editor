// Quick test: Dart FFI -> Rust mermaid-rs-renderer
// Run: dart run test_mermaid_ffi.dart

import 'dart:ffi';
import 'dart:convert';
import 'package:ffi/ffi.dart';

typedef RenderMermaidNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef RenderMermaidDart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef RustStringFreeNative = Void Function(Pointer<Utf8>);
typedef RustStringFreeDart = void Function(Pointer<Utf8>);

void main() {
  final lib = DynamicLibrary.open('rust/target/debug/libmermaid_ffi.dylib');

  final renderFn = lib.lookupFunction<RenderMermaidNative, RenderMermaidDart>(
    'render_mermaid',
  );
  final freeFn = lib.lookupFunction<RustStringFreeNative, RustStringFreeDart>(
    'rust_string_free',
  );

  final diagrams = [
    'flowchart LR; A-->B-->C',
    'sequenceDiagram\n    Alice->>Bob: Hello\n    Bob-->>Alice: Hi',
    'pie\n    "Dogs" : 10\n    "Cats" : 5',
  ];

  for (final diagram in diagrams) {
    final input = diagram.toNativeUtf8();
    final resultPtr = renderFn(input);
    calloc.free(input);

    if (resultPtr == nullptr) {
      print('ERROR: null result');
      continue;
    }

    final resultStr = resultPtr.toDartString();
    freeFn(resultPtr);

    final envelope = jsonDecode(resultStr) as Map<String, dynamic>;
    if (envelope.containsKey('err')) {
      print('ERROR: ${envelope['err']}');
    } else {
      final svg = envelope['ok'] as String;
      print('OK (${svg.length} chars): ${svg.substring(0, 60)}...');
    }
  }
}
