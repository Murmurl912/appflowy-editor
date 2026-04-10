import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:example/models/app_document.dart';
import 'package:example/repo/document_repository.dart';
import 'package:example/widgets/math_equation_markdown.dart';
import 'package:example/widgets/smart_markdown_encoder.dart';
import 'package:example/widgets/table_node_parser_fix.dart';
import 'package:flutter/cupertino.dart';

class EditorProvider extends ChangeNotifier {
  EditorProvider({
    required DocumentRepository repo,
    required AppDocument document,
    bool initialEditing = false,
  })  : _repo = repo,
        _document = document,
        _editing = initialEditing {
    _initEditor();
  }

  final FocusNode editorFocus = FocusNode(debugLabel: "EditorFocus");
  final DocumentRepository _repo;
  AppDocument _document;
  late EditorState _editorState;
  EditorScrollController? _scrollController;
  Timer? _saveTimer;
  bool _loading = true;
  StreamSubscription? _transactionSub;
  bool _searchMode = false;
  bool _editing = false;

  AppDocument get document => _document;
  EditorState get editorState => _editorState;
  EditorScrollController? get scrollController => _scrollController;
  bool get loading => _loading;

  bool get canUndo => _editorState.undoManager.undoStack.isNonEmpty;
  bool get canRedo => _editorState.undoManager.redoStack.isNonEmpty;

  bool get searchMode => _searchMode;
  bool get editing => _editing;

  String get title {
    final docTitle = _extractTitleFromDocument();
    return docTitle ?? _document.title;
  }

  void undo() {
    _editorState.undoManager.undo();
    notifyListeners();
  }

  void redo() {
    _editorState.undoManager.redo();
    notifyListeners();
  }

  void enterSearch() {
    _searchMode = true;
    notifyListeners();
  }

  void exitSearch() {
    _searchMode = false;
    notifyListeners();
  }

  void enterEditing() {
    _editing = true;
    _editorState.editableNotifier.value = true;
    notifyListeners();
  }

  void exitEditing() {
    _editing = false;
    _editorState.editableNotifier.value = false;
    editorFocus.unfocus();
    notifyListeners();
  }

  void _initEditor() {
    final doc = _document.content.trim().isEmpty
        ? Document.blank(withInitialText: true)
        : markdownToDocument(
            _document.content,
            markdownParsers: const [
              MarkdownCodeBlockParser(),
              MarkdownMathEquationParser(),
            ],
          );

    _editorState = EditorState(document: doc);
    _editorState.editableNotifier.value = _editing;
    _transactionSub = _editorState.transactionStream.listen((_) => _scheduleSave());
    _scrollController = EditorScrollController(
      editorState: _editorState,
      shrinkWrap: false,
    );
    _loading = false;
    notifyListeners();
  }

  String? _extractTitleFromDocument() {
    for (final node in _editorState.document.root.children) {
      final text = node.delta?.toPlainText().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
    notifyListeners();
  }

  Future<void> _save() async {
    final markdown = smartDocumentToMarkdown(
      _editorState.document,
      customParsers: const [FixedTableNodeParser(), MermaidNodeParser(), MathEquationNodeParser()],
    );
    final docTitle = _extractTitleFromDocument() ?? _document.title;
    _document = _document.copyWith(
      title: docTitle,
      content: markdown,
      updatedAt: DateTime.now(),
    );
    await _repo.saveDocument(_document);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final markdown = smartDocumentToMarkdown(
      _editorState.document,
      customParsers: const [FixedTableNodeParser(), MermaidNodeParser(), MathEquationNodeParser()],
    );
    final docTitle = _extractTitleFromDocument() ?? _document.title;
    _document = _document.copyWith(
      title: docTitle,
      content: markdown,
      updatedAt: DateTime.now(),
    );
    _repo.saveDocument(_document);
      _transactionSub?.cancel();
    _scrollController?.dispose();
    _editorState.dispose();
    super.dispose();
  }
}
