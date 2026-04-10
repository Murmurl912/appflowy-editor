import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:example/providers/web_editor_provider.dart';
import 'package:example/widgets/backdrop_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

/// Custom scheme for loading local resources.
///
/// - `app://asset/web/vditor.html` -> Flutter asset `assets/web/vditor.html`
/// - `app://local/path/to/file.png` -> Device file system
const _kScheme = 'app';
const _kAssetHost = 'asset';
const _kLocalHost = 'local';
const _kMarkdownHost = 'markdown';

class WebEditorPage extends StatelessWidget {
  const WebEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          const Positioned.fill(child: _WebEditorBody()),
          Positioned(
            top: MediaQuery.viewPaddingOf(context).top,
            left: 0,
            right: 0,
            child: const _WebEditorAppbar(),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WebToolbar(),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WebView Body
// ============================================================

class _WebEditorBody extends StatefulWidget {
  const _WebEditorBody();

  @override
  State<_WebEditorBody> createState() => _WebEditorBodyState();
}

class _WebEditorBodyState extends State<_WebEditorBody>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateInsets();
    });
  }

  void _updateInsets() {
    final provider = context.read<WebEditorProvider>();
    if (!provider.editorReady) return;
    final mq = MediaQuery.of(context);
    // Top: safe area + appbar height (48 pill + 8 padding)
    final topInset = mq.viewPadding.top + 56.0;
    // Bottom: toolbar height (~56 pill + 24 margin) + safe area or keyboard
    final keyboardHeight = mq.viewInsets.bottom;
    final bottomSafe = max(keyboardHeight, mq.viewPadding.bottom);
    final bottomInset = 72.0 + bottomSafe;
    provider.updateInsets(topInset, bottomInset, keyboardHeight);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WebEditorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('$_kScheme://$_kMarkdownHost/${provider.document.id}'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        supportZoom: false,
        disableHorizontalScroll: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        domStorageEnabled: true,
        isInspectable: true,
        resourceCustomSchemes: [_kScheme],
        useHybridComposition: true,
      ),
      onLoadResourceWithCustomScheme: (controller, request) async {
        final url = request.url;
        final host = url.host;
        final path = url.path;

        if (host == _kMarkdownHost) {
          // app://markdown/{id} -> serve vditor.html
          return _loadAsset('assets/web/vditor.html');
        } else if (host == _kAssetHost) {
          // app://asset/web/... -> assets/web/...
          return _loadAsset('assets$path');
        } else if (host == _kLocalHost) {
          // app://local/absolute/path/to/file
          return _loadLocalFile(path);
        }

        return null;
      },
      onWebViewCreated: (controller) {
        provider.setWebController(controller);

        // Bridge events (names match bridge.ts send() calls)
        controller.addJavaScriptHandler(
          handlerName: 'onReady',
          callback: (_) {
            provider.onReady();
            _updateInsets();
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onContentChanged',
          callback: (args) {
            if (args.isNotEmpty) provider.onContentChanged(args[0].toString());
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onFocus',
          callback: (_) {},
        );
        controller.addJavaScriptHandler(
          handlerName: 'onBlur',
          callback: (_) {},
        );
        controller.addJavaScriptHandler(
          handlerName: 'onSelectionChanged',
          callback: (args) {
            provider.onSelectionChanged(
              args.isNotEmpty ? args[0].toString() : '',
            );
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onFormatStateChanged',
          callback: (args) {
            if (args.isNotEmpty) {
              provider.onFormatStateChanged(args[0].toString());
            }
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onSearchResult',
          callback: (args) {
            if (args.isNotEmpty) {
              provider.onSearchResult(args[0].toString());
            }
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onKeydown',
          callback: (_) {},
        );
      },
      onConsoleMessage: (controller, msg) {
        debugPrint('[WebView] ${msg.messageLevel}: ${msg.message}');
      },
      onLoadStop: (controller, url) {
        final mq = MediaQuery.of(context);
        final topInset = mq.viewPadding.top + 56.0;
        final bottomInset = 72.0 + mq.viewPadding.bottom;
        final config = jsonEncode({
          'content': provider.document.content,
          'dark': isDark,
          'topInset': topInset,
          'bottomInset': bottomInset,
        });
        controller.evaluateJavascript(
          source: "initEditor('${_escapeJs(config)}')",
        );
      },
    );
  }

  /// Load a Flutter asset and return as CustomSchemeResponse.
  Future<CustomSchemeResponse?> _loadAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return CustomSchemeResponse(
        data: data.buffer.asUint8List(),
        contentType: _mimeType(assetPath),
      );
    } catch (e) {
      debugPrint('[CustomScheme] Asset not found: $assetPath');
      return null;
    }
  }

  /// Load a file from the device filesystem.
  Future<CustomSchemeResponse?> _loadLocalFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[CustomScheme] Local file not found: $path');
        return null;
      }
      final data = await file.readAsBytes();
      return CustomSchemeResponse(
        data: data,
        contentType: _mimeType(path),
      );
    } catch (e) {
      debugPrint('[CustomScheme] Error loading local file: $path - $e');
      return null;
    }
  }

  /// Guess MIME type from file extension.
  String _mimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'html' || 'htm' => 'text/html',
      'js' => 'application/javascript',
      'css' => 'text/css',
      'json' => 'application/json',
      'wasm' => 'application/wasm',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'pdf' => 'application/pdf',
      'woff' || 'woff2' => 'font/woff2',
      'ttf' => 'font/ttf',
      'eot' => 'application/vnd.ms-fontobject',
      _ => 'application/octet-stream',
    };
  }

  String _escapeJs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }
}

// ============================================================
// Appbar
// ============================================================

class _WebEditorAppbar extends StatelessWidget {
  const _WebEditorAppbar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WebEditorProvider>();
    return Row(
      children: [
        StadiumButtonBar(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          buttons: [
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_sharp),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
        const Spacer(),
        StadiumButtonBar(
          buttons: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: provider.canUndo ? provider.undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: provider.canRedo ? provider.redo : null,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: provider.enterSearch,
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Bottom Toolbar (format state from bridge, commands via bridge)
// ============================================================

class _WebToolbar extends StatelessWidget {
  const _WebToolbar();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WebEditorProvider>();
    if (!provider.editorReady) return const SizedBox.shrink();

    final fs = provider.formatState;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 12 + max<double>(keyboardHeight, bottomPadding),
      ),
      child: Row(
        children: [
          Expanded(
            child: StadiumButtonBar(
              scrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              buttons: [
                _Btn(Icons.format_bold, fs['bold'] == true, provider.formatBold),
                _Btn(Icons.format_italic, fs['italic'] == true, provider.formatItalic),
                _Btn(Icons.format_strikethrough, fs['strike'] == true, provider.formatStrikethrough),
                _Btn(Icons.code, fs['inline-code'] == true, provider.formatInlineCode),
                _Btn(Icons.link, fs['link'] == true, provider.formatLink),
                _D(),
                _Btn(Icons.format_list_bulleted, fs['list'] == true, provider.formatList),
                _Btn(Icons.format_list_numbered, fs['ordered-list'] == true, provider.formatOrderedList),
                _Btn(Icons.check_box_outlined, fs['check'] == true, provider.formatCheck),
                _Btn(Icons.format_indent_increase, false, provider.formatIndent),
                _Btn(Icons.format_indent_decrease, false, provider.formatOutdent),
                _D(),
                _Btn(Icons.title, fs['headings'] == true, provider.formatHeadings),
                _Btn(Icons.format_quote, fs['quote'] == true, provider.formatQuote),
                _Btn(Icons.data_object, fs['code'] == true, provider.formatCode),
                _Btn(Icons.table_chart_outlined, false, provider.formatTable),
                _Btn(Icons.horizontal_rule, false, provider.formatLine),
                _D(),
                _Btn(Icons.functions, false, provider.insertMathBlock),
                _Btn(Icons.account_tree_outlined, false, provider.insertMermaid),
              ],
            ),
          ),
          if (keyboardHeight > 0) ...[
            const SizedBox(width: 8),
            StadiumButtonBar(
              buttons: [
                IconButton(
                  icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                  onPressed: provider.blur,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.active, this.onTap);
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: active
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? Colors.grey[500] : Colors.grey[700]),
        style: active
            ? IconButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            : null,
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _D extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }
}
