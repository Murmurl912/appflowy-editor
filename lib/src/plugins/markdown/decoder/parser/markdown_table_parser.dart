import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownTableListParserV2 extends CustomMarkdownParser {
  const MarkdownTableListParserV2();

  @override
  List<Node> transform(
    md.Node element,
    List<CustomMarkdownParser> parsers, {
    MarkdownListType listType = MarkdownListType.unknown,
    int? startNumber,
  }) {
    if (element is! md.Element) {
      return [];
    }

    if (element.tag != 'table') {
      return [];
    }

    final ec = element.children;
    if (ec == null || ec.isEmpty) {
      return [];
    }

    // cells[col][row] = List<Node> (paragraph nodes for that cell)
    final List<List<List<Node>>> cells = [];

    final th = ec
        .whereType<md.Element>()
        .where((e) => e.tag == 'thead')
        .firstOrNull
        ?.children
        ?.whereType<md.Element>()
        .where((e) => e.tag == 'tr')
        .expand((e) => e.children?.whereType<md.Element>().toList() ?? [])
        .where((e) => e.tag == 'th')
        .toList();

    final td = ec
        .whereType<md.Element>()
        .where((e) => e.tag == 'tbody')
        .firstOrNull
        ?.children
        ?.whereType<md.Element>()
        .where((e) => e.tag == 'tr')
        .expand((e) => e.children?.whereType<md.Element>().toList() ?? [])
        .where((e) => e.tag == 'td')
        .toList();

    if (th == null || td == null || th.isEmpty || td.isEmpty) {
      return [];
    }

    for (var i = 0; i < th.length; i++) {
      final List<List<Node>> col = [];

      col.add(_cellChildrenToNodes(th[i].children));

      for (var j = i; j < td.length; j += th.length) {
        col.add(_cellChildrenToNodes(td[j].children));
      }

      cells.add(col);
    }

    // Build table node manually to support multi-paragraph cells
    final colsLen = cells.length;
    final rowsLen = cells.isNotEmpty ? cells[0].length : 0;

    final rawNode = Node(
      type: TableBlockKeys.type,
      attributes: {
        TableBlockKeys.colsLen: colsLen,
        TableBlockKeys.rowsLen: rowsLen,
        TableBlockKeys.colDefaultWidth: TableDefaults.colWidth,
        TableBlockKeys.rowDefaultHeight: TableDefaults.rowHeight,
        TableBlockKeys.colMinimumWidth: TableDefaults.colMinimumWidth,
      },
    );

    for (var i = 0; i < colsLen; i++) {
      for (var j = 0; j < rowsLen; j++) {
        final cell = Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.colPosition: i,
            TableCellBlockKeys.rowPosition: j,
          },
        );
        for (final child in cells[i][j]) {
          cell.insert(child);
        }
        rawNode.insert(cell);
      }
    }

    final tableNode = TableNode(node: rawNode);

    return [
      tableNode.node,
    ];
  }

  /// Convert cell's inline children to paragraph nodes,
  /// splitting by <br> tags for multi-line cell content.
  List<Node> _cellChildrenToNodes(List<md.Node>? children) {
    if (children == null || children.isEmpty) {
      return [paragraphNode()];
    }

    final groups = children
        .fold<List<List<md.Node>>>(
          [[]],
          (acc, node) {
            if (node is md.Element && node.tag == 'br') {
              acc.add([]);
            } else {
              acc.last.add(node);
            }
            return acc;
          },
        )
        .where((group) => group.isNotEmpty)
        .toList();

    if (groups.isEmpty) {
      return [paragraphNode()];
    }

    return groups.map((group) {
      final delta = DeltaMarkdownDecoder().convertNodes(group);
      return paragraphNode(delta: delta);
    }).toList();
  }
}
