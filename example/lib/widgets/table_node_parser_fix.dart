import 'package:appflowy_editor/appflowy_editor.dart';

/// Fixed table node parser that escapes pipe characters in cell content.
class FixedTableNodeParser extends NodeParser {
  const FixedTableNodeParser();

  @override
  String get id => TableBlockKeys.type;

  @override
  String transform(Node node, DocumentMarkdownEncoder? encoder) {
    final int rowsLen = node.attributes[TableBlockKeys.rowsLen];
    final int colsLen = node.attributes[TableBlockKeys.colsLen];
    final buffer = StringBuffer();

    for (var i = 0; i < rowsLen; i++) {
      for (var j = 0; j < colsLen; j++) {
        final cell = _getCellNode(node, j, i);
        if (cell == null) continue;

        var cellMarkdown = documentToMarkdown(Document(root: cell))
            .trimRight()
            .replaceAll('\n', '<br/>');

        // Escape pipe characters inside cell content
        cellMarkdown = cellMarkdown.replaceAll('|', '\\|');

        if (cellMarkdown.isEmpty) cellMarkdown = ' ';

        buffer.write('|$cellMarkdown');
        if (j == colsLen - 1) {
          buffer.write('|\n');
        }
      }
    }

    // Remove trailing newline
    var result = buffer.toString();
    if (result.endsWith('\n')) {
      result = result.substring(0, result.length - 1);
    }

    // Insert separator after header row
    final separator = StringBuffer();
    for (var j = 0; j < colsLen; j++) {
      separator.write('|---');
    }
    separator.write('|');

    final lines = result.split('\n');
    if (lines.isNotEmpty) {
      lines.insert(1, separator.toString());
    }
    result = lines.join('\n');

    return node.next == null ? result : '$result\n';
  }

  /// Find cell node by column and row position.
  Node? _getCellNode(Node tableNode, int col, int row) {
    for (final child in tableNode.children) {
      if (child.type == TableCellBlockKeys.type &&
          child.attributes[TableCellBlockKeys.colPosition] == col &&
          child.attributes[TableCellBlockKeys.rowPosition] == row) {
        return child;
      }
    }
    return null;
  }
}
