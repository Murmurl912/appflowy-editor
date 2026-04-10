import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as hi;
import 'package:provider/provider.dart';

class CodeBlockKeys {
  const CodeBlockKeys._();
  static const String type = 'code';
  static const String language = 'language';
}

Node codeBlockNode({String language = '', Delta? delta}) {
  return Node(
    type: CodeBlockKeys.type,
    attributes: {
      CodeBlockKeys.language: language,
      'delta': (delta ?? (Delta()..insert(''))).toJson(),
    },
  );
}

class CodeBlockComponentBuilder extends BlockComponentBuilder {
  CodeBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return CodeBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate => (node) => true;
}

class CodeBlockWidget extends BlockComponentStatefulWidget {
  const CodeBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentTextDirectionMixin,
        BlockComponentBackgroundColorMixin {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  final forwardKey = GlobalKey(debugLabel: 'code_block_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: 'code_block',
  );

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => node.key;

  @override
  late final editorState = context.read<EditorState>();

  String get _language =>
      node.attributes[CodeBlockKeys.language] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget child = AppFlowyRichText(
      key: forwardKey,
      delegate: this,
      node: node,
      editorState: editorState,
      placeholderText: 'Enter code...',
      textDirection: textDirection(),
      cursorHeight: 16,
      lineHeight: 1.5,
      textSpanDecorator: (textSpan) => _highlightCode(textSpan, isDark),
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
    );

    return Padding(
      padding: padding,
      child: Container(
        key: blockComponentKey,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F8FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language label
            if (_language.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Text(
                  _language,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Editable code area
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  /// Apply syntax highlighting via textSpanDecorator
  TextSpan _highlightCode(TextSpan textSpan, bool isDark) {
    final code = node.delta?.toPlainText() ?? '';
    if (code.isEmpty) return textSpan;

    final themeMap = isDark ? _darkTheme : _lightTheme;

    try {
      final lang = _language.isNotEmpty ? _language : null;
      final result = lang != null
          ? hi.highlight.parse(code, language: lang)
          : hi.highlight.parse(code, autoDetection: true);
      final nodes = result.nodes;
      if (nodes != null && nodes.isNotEmpty) {
        return TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.5,
            color: themeMap['root']?.color ??
                (isDark ? Colors.grey[300] : Colors.grey[900]),
          ),
          children: _convertNodes(nodes, themeMap),
        );
      }
    } catch (_) {}

    // Fallback: monospace style, no highlighting
    return textSpan.updateTextStyle(
      const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
    );
  }

  List<TextSpan> _convertNodes(
    List<hi.Node> nodes,
    Map<String, TextStyle> themeMap,
  ) {
    final List<TextSpan> spans = [];
    for (final n in nodes) {
      if (n.value != null) {
        spans.add(TextSpan(
          text: n.value,
          style: n.className != null ? themeMap[n.className] : null,
        ));
      } else if (n.children != null) {
        spans.add(TextSpan(
          children: _convertNodes(n.children!, themeMap),
          style: n.className != null ? themeMap[n.className] : null,
        ));
      }
    }
    return spans;
  }
}

// Minimal syntax highlight themes
const _lightTheme = <String, TextStyle>{
  'root': TextStyle(color: Color(0xFF24292E)),
  'keyword': TextStyle(color: Color(0xFFD73A49)),
  'built_in': TextStyle(color: Color(0xFF005CC5)),
  'type': TextStyle(color: Color(0xFF005CC5)),
  'literal': TextStyle(color: Color(0xFF005CC5)),
  'number': TextStyle(color: Color(0xFF005CC5)),
  'string': TextStyle(color: Color(0xFF032F62)),
  'comment': TextStyle(color: Color(0xFF6A737D), fontStyle: FontStyle.italic),
  'class': TextStyle(color: Color(0xFF6F42C1)),
  'function': TextStyle(color: Color(0xFF6F42C1)),
  'title': TextStyle(color: Color(0xFF6F42C1)),
  'tag': TextStyle(color: Color(0xFF22863A)),
  'name': TextStyle(color: Color(0xFF22863A)),
  'attribute': TextStyle(color: Color(0xFF005CC5)),
  'variable': TextStyle(color: Color(0xFFE36209)),
  'meta': TextStyle(color: Color(0xFF005CC5)),
};

const _darkTheme = <String, TextStyle>{
  'root': TextStyle(color: Color(0xFFF8F8F2)),
  'keyword': TextStyle(color: Color(0xFFF92672)),
  'built_in': TextStyle(color: Color(0xFF66D9EF)),
  'type': TextStyle(color: Color(0xFF66D9EF), fontStyle: FontStyle.italic),
  'literal': TextStyle(color: Color(0xFFAE81FF)),
  'number': TextStyle(color: Color(0xFFAE81FF)),
  'string': TextStyle(color: Color(0xFFE6DB74)),
  'comment': TextStyle(color: Color(0xFF75715E), fontStyle: FontStyle.italic),
  'class': TextStyle(color: Color(0xFFA6E22E)),
  'function': TextStyle(color: Color(0xFFA6E22E)),
  'title': TextStyle(color: Color(0xFFA6E22E)),
  'tag': TextStyle(color: Color(0xFFF92672)),
  'name': TextStyle(color: Color(0xFFF92672)),
  'attribute': TextStyle(color: Color(0xFFA6E22E)),
  'variable': TextStyle(color: Color(0xFFF8F8F2)),
  'meta': TextStyle(color: Color(0xFFF8F8F2)),
};

// ============================================================
// Code Block Shortcut Events
// ============================================================

/// Enter in code block: insert newline into delta instead of creating new block.
final CharacterShortcutEvent enterInCodeBlock = CharacterShortcutEvent(
  key: 'press enter in code block',
  character: '\n',
  handler: (editorState) async {
    final selection = editorState.selection;
    if (selection == null || !selection.isCollapsed) return false;
    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null || node.type != CodeBlockKeys.type) return false;

    // Auto-indent: match leading spaces of current line
    final lines = node.delta?.toPlainText().split('\n') ?? [];
    int spaces = 0;
    int index = 0;
    for (final line in lines) {
      if (index <= selection.endIndex && selection.endIndex <= index + line.length) {
        spaces = line.length - line.trimLeft().length;
        break;
      }
      index += line.length + 1;
    }

    final transaction = editorState.transaction
      ..insertText(node, selection.end.offset, '\n${' ' * spaces}');
    await editorState.apply(transaction);
    return true;
  },
);

/// Ignore markdown shortcut characters inside code blocks.
final List<CharacterShortcutEvent> ignoreKeysInCodeBlock =
    [' ', '/', '_', '*', '~', '-'].map(
      (ch) => CharacterShortcutEvent(
        key: 'ignore $ch in code block',
        character: ch,
        handler: (editorState) async {
          final selection = editorState.selection;
          if (selection == null || !selection.isCollapsed) return false;
          final node = editorState.getNodeAtPath(selection.end.path);
          if (node == null || node.type != CodeBlockKeys.type) return false;
          await editorState.insertTextAtCurrentSelection(ch);
          return true;
        },
      ),
    ).toList();

/// All code block character shortcut events.
List<CharacterShortcutEvent> get codeBlockCharacterEvents => [
  enterInCodeBlock,
  ...ignoreKeysInCodeBlock,
];
