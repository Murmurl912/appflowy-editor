import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:collection/collection.dart';

/// List block types that should NOT have blank lines between consecutive items.
const _listTypes = {
  BulletedListBlockKeys.type,
  NumberedListBlockKeys.type,
  TodoListBlockKeys.type,
};

/// Encodes a Document to Markdown with smart line breaks:
/// - Blank line between different block types (heading, paragraph, etc.)
/// - NO blank line between consecutive list items of the same type
String smartDocumentToMarkdown(
  Document document, {
  List<NodeParser> customParsers = const [],
}) {
  final parsers = [
    ...customParsers,
    const TextNodeParser(),
    const BulletedListNodeParser(),
    const NumberedListNodeParser(),
    const TodoListNodeParser(),
    const QuoteNodeParser(),
    const CodeBlockNodeParser(),
    const HeadingNodeParser(),
    const ImageNodeParser(),
    const TableNodeParser(),
    const DividerNodeParser(),
  ];

  final buffer = StringBuffer();
  final children = document.root.children.toList();

  for (var i = 0; i < children.length; i++) {
    final node = children[i];
    final parser = parsers.firstWhereOrNull((p) => p.id == node.type);
    if (parser == null) continue;

    buffer.write(parser.transform(node, null));

    // Add blank line between nodes, EXCEPT between consecutive list items
    if (i < children.length - 1) {
      final nextNode = children[i + 1];
      final currentIsList = _listTypes.contains(node.type);
      final nextIsList = _listTypes.contains(nextNode.type);

      if (!(currentIsList && nextIsList)) {
        buffer.write('\n');
      }
    }
  }

  return buffer.toString();
}
