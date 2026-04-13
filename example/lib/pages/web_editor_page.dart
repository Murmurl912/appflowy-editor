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
/// - `app://asset/web/vditor/vditor.html` -> Flutter asset `assets/web/vditor/vditor.html`
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
        debugPrint('[CustomScheme] $url (host=$host, path=$path)');

        if (host == _kMarkdownHost) {
          final engine = provider.engineType;
          final htmlAsset = engine == WebEngineType.tiptap
              ? 'assets/web/tiptap/tiptap.html'
              : 'assets/web/vditor/vditor.html';
          return _loadAsset(htmlAsset);
        } else if (host == _kAssetHost) {
          return _loadAsset('assets$path');
        } else if (host == _kLocalHost) {
          return _loadLocalFile(path);
        }

        debugPrint('[CustomScheme] Unhandled: $url');
        return null;
      },
      onReceivedError: (controller, request, error) {
        debugPrint('[WebView Error] ${request.url} -> ${error.description}');
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
        const SizedBox(width: 8),
        Text(
          provider.engineType == WebEngineType.tiptap ? 'TipTap' : 'Vditor',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[500]
                : Colors.grey[400],
          ),
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

    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final items = _buildItems(provider);

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
              buttons: items,
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

  List<Widget> _buildItems(WebEditorProvider p) {
    final hasSelection = p.hasSelection;
    final nodeType = p.nodeType;

    // Text selected: show inline formatting
    if (hasSelection) {
      return _textSelectionItems(p);
    }

    // Inside a list item: show indent + list types + block types + insert
    if (const ['listItem', 'taskItem'].contains(nodeType)) {
      return _listItems(p);
    }

    // Inside table: show table-specific tools
    if (nodeType == 'table') {
      return _tableItems(p);
    }

    // Inside code block / image / math / mermaid: minimal
    if (const ['codeBlock', 'mathBlock', 'mermaidBlock', 'image']
        .contains(nodeType)) {
      return _atomBlockItems(p);
    }

    // Default (paragraph / heading / blockquote): block types + alignment + insert
    return _defaultItems(p);
  }

  // --- Text selected: inline marks ---
  List<Widget> _textSelectionItems(WebEditorProvider p) {
    return [
      _Btn(Icons.format_bold, p.isFormatActive('bold'), p.formatBold),
      _Btn(Icons.format_italic, p.isFormatActive('italic'), p.formatItalic),
      _Btn(Icons.format_underline, p.isFormatActive('underline'), p.formatUnderline),
      _Btn(Icons.format_strikethrough, p.isFormatActive('strike'), p.formatStrikethrough),
      _Btn(Icons.code, p.isFormatActive('inline-code'), p.formatInlineCode),
      _Btn(Icons.link, p.isFormatActive('link'), p.formatLink),
      _D(),
      _headingLabel(p),
      _Btn(Icons.format_quote, p.isFormatActive('quote'), p.formatQuote),
    ];
  }

  // --- Inside list: indent + list type switching ---
  List<Widget> _listItems(WebEditorProvider p) {
    return [
      _Btn(Icons.format_indent_increase, false, p.formatIndent),
      _Btn(Icons.format_indent_decrease, false, p.formatOutdent),
      _D(),
      _Btn(Icons.format_list_bulleted, p.isFormatActive('list'), p.formatList),
      _Btn(Icons.format_list_numbered, p.isFormatActive('ordered-list'), p.formatOrderedList),
      _Btn(Icons.check_box_outlined, p.isFormatActive('check'), p.formatCheck),
      _D(),
      _headingLabel(p),
      _Btn(Icons.format_quote, p.isFormatActive('quote'), p.formatQuote),
      _D(),
      ..._insertItems(p),
    ];
  }

  // --- Inside table: table operations ---
  List<Widget> _tableItems(WebEditorProvider p) {
    return [
      _Btn(Icons.add, false, p.tableAddRowAfter),           // add row below
      _Btn(Icons.table_rows_outlined, false, p.tableAddRowBefore),  // add row above
      _Btn(Icons.remove, false, p.tableDeleteRow),           // delete row
      _D(),
      _Btn(Icons.add_box_outlined, false, p.tableAddColAfter),    // add col right
      _Btn(Icons.view_column_outlined, false, p.tableAddColBefore), // add col left
      _Btn(Icons.remove_circle_outline, false, p.tableDeleteCol),  // delete col
      _D(),
      _Btn(Icons.border_top, false, p.tableToggleHeader),
      _Btn(Icons.delete_outline, false, p.tableDeleteTable),
    ];
  }

  // --- Atom blocks (code, etc): minimal ---
  List<Widget> _atomBlockItems(WebEditorProvider p) {
    return [
      _headingLabel(p),
      _Btn(Icons.format_list_bulleted, p.isFormatActive('list'), p.formatList),
      _Btn(Icons.format_list_numbered, p.isFormatActive('ordered-list'), p.formatOrderedList),
      _Btn(Icons.check_box_outlined, p.isFormatActive('check'), p.formatCheck),
      _D(),
      ..._insertItems(p),
    ];
  }

  // --- Default (paragraph / heading): block types + alignment + insert ---
  List<Widget> _defaultItems(WebEditorProvider p) {
    return [
      _Btn(Icons.format_indent_increase, false, p.formatIndent),
      _Btn(Icons.format_indent_decrease, false, p.formatOutdent),
      _D(),
      _headingLabel(p),
      _Btn(Icons.format_list_bulleted, p.isFormatActive('list'), p.formatList),
      _Btn(Icons.format_list_numbered, p.isFormatActive('ordered-list'), p.formatOrderedList),
      _Btn(Icons.check_box_outlined, p.isFormatActive('check'), p.formatCheck),
      _Btn(Icons.format_quote, p.isFormatActive('quote'), p.formatQuote),
      _D(),
      _Btn(Icons.format_align_left, p.textAlign == 'left', p.alignLeft),
      _Btn(Icons.format_align_center, p.textAlign == 'center', p.alignCenter),
      _Btn(Icons.format_align_right, p.textAlign == 'right', p.alignRight),
      _D(),
      ..._insertItems(p),
    ];
  }

  // --- Insert items (shared across modes) ---
  List<Widget> _insertItems(WebEditorProvider p) {
    return [
      _Btn(Icons.data_object, p.isFormatActive('code'), p.formatCode),
      _Btn(Icons.table_chart_outlined, false, p.formatTable),
      _Btn(Icons.horizontal_rule, false, p.formatLine),
      _Btn(Icons.functions, false, p.insertMathBlock),
      _Btn(Icons.account_tree_outlined, false, p.insertMermaid),
    ];
  }

  // --- Heading label button (H1/H2/H3/Aa) ---
  Widget _headingLabel(WebEditorProvider p) {
    final level = p.headingLevel;
    final label = switch (level) {
      1 => 'H1',
      2 => 'H2',
      3 => 'H3',
      4 => 'H4',
      5 => 'H5',
      6 => 'H6',
      _ => 'Aa',
    };
    final isActive = level > 0;
    return _HeadingBtn(label: label, active: isActive, provider: p);
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

class _HeadingBtn extends StatefulWidget {
  const _HeadingBtn({
    required this.label,
    required this.active,
    required this.provider,
  });

  final String label;
  final bool active;
  final WebEditorProvider provider;

  @override
  State<_HeadingBtn> createState() => _HeadingBtnState();
}

class _HeadingBtnState extends State<_HeadingBtn> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _toggle() {
    if (_overlayEntry != null) {
      _dismiss();
    } else {
      _show();
    }
  }

  void _show() {
    _overlayEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -8),
            child: ExcludeFocus(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _item('Heading 1', 1, 20.0),
                      _item('Heading 2', 2, 18.0),
                      _item('Heading 3', 3, 16.0),
                      _item('Text', 0, 14.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _dismiss() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  Widget _item(String text, int level, double fontSize) {
    final currentLevel = widget.provider.headingLevel;
    final isActive =
        level == 0 ? currentLevel == 0 : currentLevel == level;
    return InkWell(
      onTap: () {
        _dismiss();
        if (level == 0) {
          // Convert to paragraph (toggle off heading)
          if (widget.provider.headingLevel > 0) {
            widget.provider.insertHeading(widget.provider.headingLevel);
          }
        } else {
          widget.provider.insertHeading(level);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.active
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[500] : Colors.grey[700]),
            ),
          ),
        ),
      ),
    );
  }
}
