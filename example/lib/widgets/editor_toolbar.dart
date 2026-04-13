import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/providers/editor_provider.dart';
import 'package:example/widgets/backdrop_container.dart';
import 'package:example/widgets/code_block_component.dart' show CodeBlockKeys;
import 'package:example/widgets/custom_block_components.dart';
import 'package:example/widgets/math_equation_block_component.dart';
import 'package:example/widgets/mermaid_block_component.dart' show MermaidBlockKeys;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorProvider>().editorState;
    final editorFocus = context.read<EditorProvider>().editorFocus;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: keyboardHeight,
          child: child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Builder(
            builder: (context) {
              final (searchMode, editing) = context.select(
                (EditorProvider p) => (p.searchMode, p.editing),
              );
              if (searchMode || !editing) return const SizedBox.shrink();
              return ListenableBuilder(
                listenable: editorFocus,
                builder: (context, _) => ValueListenableBuilder<Selection?>(
                  valueListenable: editorState.selectionNotifier,
                  builder: (context, selection, _) {
                    return _ToolbarContent(
                      editorState: editorState,
                      editorFocus: editorFocus,
                      selection: selection,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToolbarContent extends StatelessWidget {
  const _ToolbarContent({
    required this.editorState,
    required this.selection,
    required this.editorFocus,
  });

  final EditorState editorState;
  final Selection? selection;
  final FocusNode editorFocus;

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    final bottomMargin = 16.0 + max(editorFocus.hasFocus ? insets.bottom : 0.0, viewPadding.bottom);
    final showDismiss = editorFocus.hasFocus && insets.bottom > 0;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
      child: Row(
        children: [
          Expanded(
            child: StadiumButtonBar(
              buttons: items,
              scrollable: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          if (showDismiss) ...[
            const SizedBox(width: 8),
            StadiumButtonBar(
              buttons: [
                IconButton(
                  icon: const Icon(Icons.keyboard_hide_outlined, size: 20),
                  onPressed: () => FocusScope.of(context).unfocus(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    final sel = selection;

    // No selection: show default block items
    if (sel == null) {
      return _buildNoSelectionItems(context);
    }

    // Text selected: formatting items
    if (!sel.isCollapsed) {
      return _buildTextSelectionItems(context, sel);
    }

    // Find the node at cursor and walk up to find the context block
    final node = editorState.getNodeAtPath(sel.start.path);
    if (node == null) return _buildNoSelectionItems(context);

    // Check if cursor is inside a table cell
    final tableNode = _findAncestor(node, TableBlockKeys.type);
    if (tableNode != null) {
      return _buildTableItems(context, sel, node, tableNode);
    }

    // Code block
    if (node.type == CodeBlockKeys.type) {
      return _buildCodeBlockItems(context, sel);
    }

    // Mermaid block
    if (node.type == MermaidBlockKeys.type) {
      return _buildMermaidItems(context, sel);
    }

    // Math equation
    if (node.type == MathEquationBlockKeys.type) {
      return _buildAtomBlockItems(context, sel, 'Math');
    }

    // List blocks
    if (const [
      BulletedListBlockKeys.type,
      NumberedListBlockKeys.type,
      TodoListBlockKeys.type,
    ].contains(node.type)) {
      return _buildListItems(context, sel);
    }

    return _buildDefaultItems(context, sel);
  }

  /// Walk up the node tree to find an ancestor of the given type.
  Node? _findAncestor(Node node, String type) {
    Node? current = node;
    while (current != null) {
      if (current.type == type) return current;
      current = current.parent;
    }
    return null;
  }

  List<Widget> _mediaItems() => [
    _InsertImageButton(editorState: editorState),
    _InsertVideoButton(editorState: editorState),
    _InsertPdfButton(editorState: editorState),
    _InsertMathButton(editorState: editorState),
    _InsertCalloutButton(editorState: editorState),
    _InsertToggleButton(editorState: editorState),
    _InsertDividerButton(editorState: editorState),
  ];

  // No selection: block type + media
  List<Widget> _buildNoSelectionItems(BuildContext context) {
    return [
      _HeadingPopover(editorState: editorState),
      _BlockTypeButtonNoSelection(editorState: editorState, blockType: TodoListBlockKeys.type, icon: Icons.check_box_outlined),
      _BlockTypeButtonNoSelection(editorState: editorState, blockType: BulletedListBlockKeys.type, icon: Icons.format_list_bulleted),
      _BlockTypeButtonNoSelection(editorState: editorState, blockType: NumberedListBlockKeys.type, icon: Icons.format_list_numbered),
      _BlockTypeButtonNoSelection(editorState: editorState, blockType: QuoteBlockKeys.type, icon: Icons.format_quote),
      _ToolbarDivider(),
      ..._mediaItems(),
    ];
  }

  List<Widget> _buildTextSelectionItems(BuildContext context, Selection sel) {
    return [
      _InlineFormatButton(editorState: editorState, selection: sel, attrKey: AppFlowyRichTextKeys.bold, icon: Icons.format_bold),
      _InlineFormatButton(editorState: editorState, selection: sel, attrKey: AppFlowyRichTextKeys.italic, icon: Icons.format_italic),
      _InlineFormatButton(editorState: editorState, selection: sel, attrKey: AppFlowyRichTextKeys.underline, icon: Icons.format_underline),
      _InlineFormatButton(editorState: editorState, selection: sel, attrKey: AppFlowyRichTextKeys.strikethrough, icon: Icons.format_strikethrough),
      _InlineFormatButton(editorState: editorState, selection: sel, attrKey: AppFlowyRichTextKeys.code, icon: Icons.code),
      _ToolbarDivider(),
      _HeadingPopover(editorState: editorState, selection: sel),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: QuoteBlockKeys.type, icon: Icons.format_quote),
    ];
  }

  // --- Table: add/delete row/col ---
  List<Widget> _buildTableItems(BuildContext context, Selection sel, Node cursorNode, Node tableNode) {
    // Find the cell node containing cursor
    Node? cellNode = cursorNode;
    while (cellNode != null && cellNode.type != TableCellBlockKeys.type) {
      cellNode = cellNode.parent;
    }
    final col = (cellNode?.attributes[TableCellBlockKeys.colPosition] as int?) ?? 0;
    final row = (cellNode?.attributes[TableCellBlockKeys.rowPosition] as int?) ?? 0;

    return [
      _ToolbarIconButton(icon: Icons.add, onPressed: () {
        TableActions.add(tableNode, row + 1, editorState, TableDirection.row);
      }),
      _ToolbarIconButton(icon: Icons.table_rows_outlined, onPressed: () {
        TableActions.add(tableNode, row, editorState, TableDirection.row);
      }),
      _ToolbarIconButton(icon: Icons.remove, onPressed: () {
        TableActions.delete(tableNode, row, editorState, TableDirection.row);
      }),
      _ToolbarDivider(),
      _ToolbarIconButton(icon: Icons.add_box_outlined, onPressed: () {
        TableActions.add(tableNode, col + 1, editorState, TableDirection.col);
      }),
      _ToolbarIconButton(icon: Icons.view_column_outlined, onPressed: () {
        TableActions.add(tableNode, col, editorState, TableDirection.col);
      }),
      _ToolbarIconButton(icon: Icons.remove_circle_outline, onPressed: () {
        TableActions.delete(tableNode, col, editorState, TableDirection.col);
      }),
      _ToolbarDivider(),
      _ToolbarIconButton(icon: Icons.delete_outline, onPressed: () {
        final transaction = editorState.transaction
          ..insertNode(tableNode.path, paragraphNode())
          ..deleteNode(tableNode);
        editorState.apply(transaction);
      }),
    ];
  }

  // --- Code block: language hint + exit ---
  List<Widget> _buildCodeBlockItems(BuildContext context, Selection sel) {
    final node = editorState.getNodeAtPath(sel.start.path);
    final lang = node?.attributes[CodeBlockKeys.language] as String? ?? '';
    return [
      if (lang.isNotEmpty) Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(lang, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ),
      _ToolbarDivider(),
      ..._mediaItems(),
    ];
  }

  // --- Mermaid: just show insert tools ---
  List<Widget> _buildMermaidItems(BuildContext context, Selection sel) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('Mermaid', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ),
      _ToolbarDivider(),
      ..._mediaItems(),
    ];
  }

  // --- Atom blocks (math, image, etc): label + insert ---
  List<Widget> _buildAtomBlockItems(BuildContext context, Selection sel, String label) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ),
      _ToolbarDivider(),
      ..._mediaItems(),
    ];
  }

  List<Widget> _buildListItems(BuildContext context, Selection sel) {
    return [
      _IndentButton(editorState: editorState, indent: true),
      _IndentButton(editorState: editorState, indent: false),
      _ToolbarDivider(),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: TodoListBlockKeys.type, icon: Icons.check_box_outlined),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: BulletedListBlockKeys.type, icon: Icons.format_list_bulleted),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: NumberedListBlockKeys.type, icon: Icons.format_list_numbered),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: QuoteBlockKeys.type, icon: Icons.format_quote),
      _ToolbarDivider(),
      _HeadingPopover(editorState: editorState, selection: sel),
      _ToolbarDivider(),
      ..._mediaItems(),
    ];
  }

  List<Widget> _buildDefaultItems(BuildContext context, Selection sel) {
    return [
      _IndentButton(editorState: editorState, indent: true),
      _IndentButton(editorState: editorState, indent: false),
      _ToolbarDivider(),
      _HeadingPopover(editorState: editorState, selection: sel),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: TodoListBlockKeys.type, icon: Icons.check_box_outlined),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: BulletedListBlockKeys.type, icon: Icons.format_list_bulleted),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: NumberedListBlockKeys.type, icon: Icons.format_list_numbered),
      _BlockTypeButton(editorState: editorState, selection: sel, blockType: QuoteBlockKeys.type, icon: Icons.format_quote),
      _ToolbarDivider(),
      ..._mediaItems(),
    ];
  }
}

// --- Inline format toggle ---
class _InlineFormatButton extends StatelessWidget {
  const _InlineFormatButton({
    required this.editorState,
    required this.selection,
    required this.attrKey,
    required this.icon,
  });

  final EditorState editorState;
  final Selection selection;
  final String attrKey;
  final IconData icon;

  bool get _isActive {
    if (selection.isCollapsed) {
      return editorState.toggledStyle[attrKey] == true;
    }
    final nodes = editorState.getNodesInSelection(selection);
    return nodes.allSatisfyInSelection(selection, (delta) {
      return delta.everyAttributes((attr) => attr[attrKey] == true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: icon,
      isActive: _isActive,
      onPressed: () => editorState.toggleAttribute(attrKey),
    );
  }
}

// --- Block type toggle (with selection) ---
class _BlockTypeButton extends StatelessWidget {
  const _BlockTypeButton({
    required this.editorState,
    required this.selection,
    required this.blockType,
    required this.icon,
  });

  final EditorState editorState;
  final Selection selection;
  final String blockType;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final node = editorState.getNodeAtPath(selection.start.path);
    final isActive = node?.type == blockType;

    return _ToolbarIconButton(
      icon: icon,
      isActive: isActive,
      onPressed: () {
        editorState.formatNode(
          selection,
          (node) {
            if (node.type == blockType) {
              return node.copyWith(type: ParagraphBlockKeys.type);
            }
            return node.copyWith(type: blockType);
          },
          selectionExtraInfo: {
            selectionExtraInfoDoNotAttachTextService: true,
          },
        );
      },
    );
  }
}

// --- Block type button for no-selection state (appends at end) ---
class _BlockTypeButtonNoSelection extends StatelessWidget {
  const _BlockTypeButtonNoSelection({
    required this.editorState,
    required this.blockType,
    required this.icon,
  });

  final EditorState editorState;
  final String blockType;
  final IconData icon;

  Node _createNode() {
    return switch (blockType) {
      TodoListBlockKeys.type => todoListNode(checked: false),
      BulletedListBlockKeys.type => bulletedListNode(),
      NumberedListBlockKeys.type => numberedListNode(),
      QuoteBlockKeys.type => quoteNode(),
      _ => paragraphNode(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: icon,
      onPressed: () {
        final path = [editorState.document.root.children.length];
        final transaction = editorState.transaction
          ..insertNode(path, _createNode())
          ..afterSelection = Selection.collapsed(Position(path: path));
        editorState.apply(transaction);
      },
    );
  }
}

// --- Heading popover (OverlayEntry, does NOT steal focus) ---
class _HeadingPopover extends StatefulWidget {
  const _HeadingPopover({
    required this.editorState,
    this.selection,
  });

  final EditorState editorState;
  final Selection? selection;

  @override
  State<_HeadingPopover> createState() => _HeadingPopoverState();
}

class _HeadingPopoverState extends State<_HeadingPopover> {
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

  void _apply(int level) {
    _dismiss();
    final sel = widget.selection;
    if (sel == null) {
      // No selection: append at end
      final path = [widget.editorState.document.root.children.length];
      final node = level == 0 ? paragraphNode() : headingNode(level: level);
      final transaction = widget.editorState.transaction
        ..insertNode(path, node)
        ..afterSelection = Selection.collapsed(Position(path: path));
      widget.editorState.apply(transaction);
    } else {
      widget.editorState.formatNode(
        sel,
        (node) {
          if (level == 0) {
            return node.copyWith(type: ParagraphBlockKeys.type);
          }
          return node.copyWith(
            type: HeadingBlockKeys.type,
            attributes: {...node.attributes, HeadingBlockKeys.level: level},
          );
        },
        selectionExtraInfo: {
          selectionExtraInfoDoNotAttachTextService: true,
        },
      );
    }
  }

  Widget _item(String text, int level, double fontSize) {
    final sel = widget.selection;
    final node = sel != null ? widget.editorState.getNodeAtPath(sel.start.path) : null;
    final isActive = level == 0
        ? (node != null && node.type != HeadingBlockKeys.type)
        : (node?.type == HeadingBlockKeys.type &&
            node?.attributes[HeadingBlockKeys.level] == level);

    return InkWell(
      onTap: () => _apply(level),
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
    final sel = widget.selection;
    final node = sel != null ? widget.editorState.getNodeAtPath(sel.start.path) : null;
    final isHeading = node?.type == HeadingBlockKeys.type;
    final level = isHeading ? node?.attributes[HeadingBlockKeys.level] : null;

    final label = switch (level) {
      1 => 'H1',
      2 => 'H2',
      3 => 'H3',
      _ => 'Aa',
    };

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isHeading ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ),
      ),
    );
  }
}

// --- Indent / Outdent (for nested lists) ---
class _IndentButton extends StatelessWidget {
  const _IndentButton({
    required this.editorState,
    required this.indent,
  });

  final EditorState editorState;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: indent ? Icons.format_indent_increase : Icons.format_indent_decrease,
      onPressed: () {
        if (indent) {
          indentCommand.execute(editorState);
        } else {
          outdentCommand.execute(editorState);
        }
      },
    );
  }
}

// --- Insert image ---
class _InsertImageButton extends StatelessWidget {
  const _InsertImageButton({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.image_outlined,
      onPressed: () async {
        final savedSelection = editorState.selection;
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        if (result == null || result.files.isEmpty) return;
        final filePath = result.files.single.path;
        if (filePath == null) return;

        final imageNode = Node(
          type: ImageBlockKeys.type,
          attributes: {
            ImageBlockKeys.url: filePath,
          },
        );

        final Path insertPath;
        if (savedSelection != null) {
          insertPath = savedSelection.start.path.next;
        } else {
          insertPath = [editorState.document.root.children.length];
        }

        final transaction = editorState.transaction
          ..insertNode(insertPath, imageNode)
          ..insertNode([insertPath.first + 1], paragraphNode())
          ..afterSelection = Selection.collapsed(
            Position(path: [insertPath.first + 1]),
          );
        editorState.apply(transaction);
      },
    );
  }
}

// --- Insert math equation ---
class _InsertMathButton extends StatelessWidget {
  const _InsertMathButton({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.functions,
      onPressed: () {
        final selection = editorState.selection;
        final Path insertPath;
        if (selection != null && selection.isCollapsed) {
          insertPath = selection.start.path.next;
        } else {
          insertPath = [editorState.document.root.children.length];
        }
        final transaction = editorState.transaction
          ..insertNode(insertPath, mathEquationNode())
          ..insertNode([insertPath.first + 1], paragraphNode())
          ..afterSelection = Selection.collapsed(
            Position(path: [insertPath.first + 1]),
          );
        editorState.apply(transaction);
      },
    );
  }
}

// --- Insert callout ---
class _InsertCalloutButton extends StatelessWidget {
  const _InsertCalloutButton({required this.editorState});
  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.lightbulb_outline,
      onPressed: () => _insertSimpleBlock(editorState, calloutNode()),
    );
  }
}

// --- Insert toggle ---
class _InsertToggleButton extends StatelessWidget {
  const _InsertToggleButton({required this.editorState});
  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.arrow_drop_down_circle_outlined,
      onPressed: () => _insertSimpleBlock(editorState, toggleListNode()),
    );
  }
}

// --- Insert video ---
class _InsertVideoButton extends StatelessWidget {
  const _InsertVideoButton({required this.editorState});
  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.videocam_outlined,
      onPressed: () => _insertSimpleBlock(editorState, videoNode()),
    );
  }
}

// --- Insert PDF ---
class _InsertPdfButton extends StatelessWidget {
  const _InsertPdfButton({required this.editorState});
  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.picture_as_pdf_outlined,
      onPressed: () => _insertSimpleBlock(editorState, pdfNode()),
    );
  }
}

/// Shared helper to insert a non-text block after cursor or at end.
void _insertSimpleBlock(EditorState editorState, Node node) {
  final selection = editorState.selection;
  final Path insertPath;
  if (selection != null && selection.isCollapsed) {
    insertPath = selection.start.path.next;
  } else {
    insertPath = [editorState.document.root.children.length];
  }
  final transaction = editorState.transaction
    ..insertNode(insertPath, node)
    ..insertNode([insertPath.first + 1], paragraphNode())
    ..afterSelection = Selection.collapsed(
      Position(path: [insertPath.first + 1]),
    );
  editorState.apply(transaction);
}

// --- Insert divider ---
class _InsertDividerButton extends StatelessWidget {
  const _InsertDividerButton({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    return _ToolbarIconButton(
      icon: Icons.horizontal_rule,
      onPressed: () {
        final selection = editorState.selection;
        final Path insertPath;
        if (selection != null && selection.isCollapsed) {
          insertPath = selection.start.path.next;
        } else {
          insertPath = [editorState.document.root.children.length];
        }
        final transaction = editorState.transaction
          ..insertNode(insertPath, Node(type: DividerBlockKeys.type))
          ..insertNode([insertPath.first + 1], paragraphNode())
          ..afterSelection = Selection.collapsed(
            Position(path: [insertPath.first + 1]),
          );
        editorState.apply(transaction);
      },
    );
  }
}

// --- Shared icon button ---
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.grey[500]! : Colors.grey[700]!;

    return Container(
      width: 40,
      height: 40,
      decoration: const ShapeDecoration(shape: StadiumBorder()),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: isActive ? activeColor : inactiveColor,
        style: isActive
            ? IconButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            : null,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

// --- Visual separator ---
class _ToolbarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      color: isDark ? Colors.grey[700] : Colors.grey[300],
    );
  }
}
