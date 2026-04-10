import 'dart:convert';

import 'package:example/models/app_document.dart';
import 'package:example/repo/document_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebEditorProvider extends ChangeNotifier {
  WebEditorProvider({
    required DocumentRepository repo,
    required AppDocument document,
    bool initialEditing = false,
  })  : _repo = repo,
        _document = document;

  final DocumentRepository _repo;
  AppDocument _document;
  bool _searchMode = false;
  bool _editorReady = false;
  String _selectedText = '';
  Map<String, dynamic> _formatState = {};
  InAppWebViewController? _webController;

  AppDocument get document => _document;
  bool get searchMode => _searchMode;
  bool get editorReady => _editorReady;
  String get selectedText => _selectedText;
  Map<String, dynamic> get formatState => _formatState;

  bool isFormatActive(String name) => _formatState[name] == true;
  int get headingLevel => (_formatState['headingLevel'] as int?) ?? 0;
  bool get canUndo => _formatState['canUndo'] == true;
  bool get canRedo => _formatState['canRedo'] == true;

  String get title {
    final lines = _document.content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#')) {
        return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      }
      if (trimmed.isNotEmpty) return trimmed;
    }
    return _document.title;
  }

  void setWebController(InAppWebViewController controller) {
    _webController = controller;
  }

  // --- JS → Flutter event handlers ---

  void onReady() {
    _editorReady = true;
    notifyListeners();
  }

  void onContentChanged(String content) {
    _document = _document.copyWith(content: content, updatedAt: DateTime.now());
    _repo.saveDocument(_document);
    notifyListeners();
  }

  void onSelectionChanged(String text) {
    _selectedText = text;
    notifyListeners();
  }

  void onFormatStateChanged(String json) {
    try {
      _formatState = jsonDecode(json) as Map<String, dynamic>;
      notifyListeners();
    } catch (_) {}
  }

  // --- Insets ---

  void updateInsets(double top, double bottom, double keyboardHeight) {
    _callBridge('setInsets', [top.toInt(), bottom.toInt(), keyboardHeight.toInt()]);
  }

  // --- Commands (Flutter → JS via VditorBridge) ---

  void focus() => _callBridge('focus');
  void blur() => _callBridge('blur');
  void setReadOnly(bool v) => _callBridge('setReadOnly', [v]);
  void setTheme(bool isDark) => _callBridge('setTheme', [isDark]);

  void undo() => _callBridge('undo');
  void redo() => _callBridge('redo');

  void formatBold() => _callBridge('formatBold');
  void formatItalic() => _callBridge('formatItalic');
  void formatStrikethrough() => _callBridge('formatStrikethrough');
  void formatInlineCode() => _callBridge('formatInlineCode');
  void formatLink() => _callBridge('formatLink');
  void formatQuote() => _callBridge('formatQuote');
  void formatCode() => _callBridge('formatCode');
  void formatList() => _callBridge('formatList');
  void formatOrderedList() => _callBridge('formatOrderedList');
  void formatCheck() => _callBridge('formatCheck');
  void formatIndent() => _callBridge('formatIndent');
  void formatOutdent() => _callBridge('formatOutdent');
  void formatTable() => _callBridge('formatTable');
  void formatLine() => _callBridge('formatLine');
  void formatHeadings() => _callBridge('formatHeadings');

  void insertHeading(int level) => _callBridge('insertHeading', [level]);
  void insertMathBlock() => _callBridge('insertMathBlock');
  void insertMermaid() => _callBridge('insertMermaid');
  void insertImage(String url) => _callBridge('insertImage', [url]);

  // --- Search ---

  int _searchTotal = 0;
  int _searchCurrent = 0;

  int get searchTotal => _searchTotal;
  int get searchCurrent => _searchCurrent;

  void enterSearch() {
    _searchMode = true;
    _searchTotal = 0;
    _searchCurrent = 0;
    notifyListeners();
  }

  void exitSearch() {
    _searchMode = false;
    _callBridge('searchClear');
    _searchTotal = 0;
    _searchCurrent = 0;
    notifyListeners();
  }

  void searchFind(String query) => _callBridge('searchFind', [query]);
  void searchNext() => _callBridge('searchNext');
  void searchPrev() => _callBridge('searchPrev');

  void onSearchResult(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      _searchTotal = (map['total'] as num?)?.toInt() ?? 0;
      _searchCurrent = (map['current'] as num?)?.toInt() ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  // --- Content ---

  Future<String> getContent() async {
    final result = await _webController?.evaluateJavascript(
      source: 'window.VditorBridge.getContent()',
    );
    return result?.toString() ?? _document.content;
  }

  // --- Internal ---

  void _callBridge(String method, [List<dynamic>? args]) {
    final argsStr = args != null
        ? args.map((a) => a is String ? "'${_escapeJs(a)}'" : a.toString()).join(', ')
        : '';
    _webController?.evaluateJavascript(
      source: 'window.VditorBridge.$method($argsStr)',
    );
  }

  String _escapeJs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  Future<void> _saveContent() async {
    final content = await getContent();
    _document = _document.copyWith(content: content, updatedAt: DateTime.now());
    await _repo.saveDocument(_document);
  }

  @override
  void dispose() {
    _saveContent();
    super.dispose();
  }
}
