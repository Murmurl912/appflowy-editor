import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/services/mermaid_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class MermaidBlockKeys {
  const MermaidBlockKeys._();
  static const String type = 'mermaid';
  static const String content = 'content';
}

Node mermaidNode({String content = ''}) {
  return Node(
    type: MermaidBlockKeys.type,
    attributes: {MermaidBlockKeys.content: content},
  );
}

class MermaidBlockComponentBuilder extends BlockComponentBuilder {
  MermaidBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return MermaidBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.attributes[MermaidBlockKeys.content] is String;
}

class MermaidBlockWidget extends BlockComponentStatefulWidget {
  const MermaidBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<MermaidBlockWidget> createState() => _MermaidBlockWidgetState();
}

class _MermaidBlockWidgetState extends State<MermaidBlockWidget>
    with BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  late final editorState = context.read<EditorState>();

  String get _content =>
      node.attributes[MermaidBlockKeys.content] as String? ?? '';

  String? _cachedSvg;
  String? _cachedInput;

  bool _cachedDark = false;

  void _tryRender(bool isDark) {
    if (_content.isEmpty || !MermaidRenderer.isAvailable) {
      _cachedSvg = null;
      return;
    }
    if (_content == _cachedInput && isDark == _cachedDark) return;
    _cachedInput = _content;
    _cachedDark = isDark;

    try {
      _cachedSvg = MermaidRenderer.tryRender(_content, dark: isDark);
    } catch (e) {
      debugPrint('Mermaid render error: $e');
      _cachedSvg = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _tryRender(isDark);

    return Padding(
      padding: padding,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark
                ? Colors.indigo.withValues(alpha: 0.3)
                : Colors.indigo.withValues(alpha: 0.15),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.indigo.withValues(alpha: 0.2)
                        : Colors.indigo.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 14,
                      color: isDark ? Colors.indigo[300] : Colors.indigo[700]),
                  const SizedBox(width: 6),
                  Text('Mermaid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                      color: isDark ? Colors.indigo[300] : Colors.indigo[700])),
                ],
              ),
            ),
            // Preview (top)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildPreview(isDark),
            ),
            // Divider
            Container(
              height: 1,
              color: isDark
                  ? Colors.indigo.withValues(alpha: 0.2)
                  : Colors.indigo.withValues(alpha: 0.1),
            ),
            // Source editor (bottom)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildEditor(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    if (_content.isEmpty) {
      return Center(
        child: Text(
          'Preview',
          style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
        ),
      );
    }

    if (_cachedSvg != null) {
      return Center(
        child: SvgPicture.string(_cachedSvg!, fit: BoxFit.contain),
      );
    }

    // Fallback: show rendered text
    return Center(
      child: Text(
        'Preview not available',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    return TextField(
      controller: TextEditingController(text: _content),
      maxLines: null,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
        color: isDark ? Colors.grey[300] : Colors.grey[800],
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        hintText: 'flowchart LR\n    A-->B-->C',
      ),
      onChanged: (value) {
        final transaction = editorState.transaction
          ..updateNode(node, {MermaidBlockKeys.content: value});
        editorState.apply(transaction);
      },
    );
  }
}
