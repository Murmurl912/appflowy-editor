import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Copy.
///
/// - support
///   - desktop
///   - web
///
final CommandShortcutEvent copyCommand = CommandShortcutEvent(
  key: 'copy the selected content',
  getDescription: () => AppFlowyEditorL10n.current.cmdCopySelection,
  command: 'ctrl+c',
  macOSCommand: 'cmd+c',
  handler: _copyCommandHandler,
);

CommandShortcutEventHandler _copyCommandHandler = (editorState) {
  final selection = editorState.selection?.normalized;
  if (selection == null) {
    return KeyEventResult.ignored;
  }

  // block selection (e.g. table/image selected via handle)
  if (selection.isCollapsed &&
      editorState.selectionType == SelectionType.block) {
    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null) {
      return KeyEventResult.ignored;
    }
    final document = Document.blank()..insert([0], [node.copyWith()]);
    final markdown = documentToMarkdown(document);
    final html = documentToHTML(document);
    () async {
      await AppFlowyClipboard.setData(
        text: markdown.isNotEmpty ? markdown : null,
        html: html.isEmpty ? null : html,
      );
    }();
    return KeyEventResult.handled;
  }

  if (selection.isCollapsed) {
    return KeyEventResult.ignored;
  }

  final nodes = editorState.getSelectedNodes(
    selection: selection,
  );
  final document = Document.blank()..insert([0], nodes);

  final markdown = documentToMarkdown(document);
  final html = documentToHTML(document);

  () async {
    await AppFlowyClipboard.setData(
      text: markdown.isNotEmpty ? markdown : null,
      html: html.isEmpty ? null : html,
    );
  }();

  return KeyEventResult.handled;
};
