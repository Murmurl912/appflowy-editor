import 'dart:io';

import 'package:example/models/app_document.dart';
import 'package:example/repo/document_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

enum EditorEngine { flutter, vditor, tiptap }

class DocumentListProvider extends ChangeNotifier {
  DocumentListProvider(this._repo);

  final DocumentRepository _repo;

  List<AppDocument> _documents = [];
  bool _loading = true;
  EditorEngine _editorEngine = EditorEngine.flutter;

  List<AppDocument> get documents => _documents;
  bool get loading => _loading;
  DocumentRepository get repo => _repo;
  EditorEngine get editorEngine => _editorEngine;
  // Keep backward compat
  bool get useWebEditor => _editorEngine != EditorEngine.flutter;

  void setEditorEngine(EditorEngine engine) {
    _editorEngine = engine;
    notifyListeners();
  }

  void toggleEditorMode() {
    _editorEngine = _editorEngine == EditorEngine.flutter
        ? EditorEngine.vditor
        : EditorEngine.flutter;
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _documents = await _repo.listDocuments();
    _loading = false;
    notifyListeners();
  }

  Future<AppDocument> create() async {
    final doc = await _repo.createDocument();
    await load();
    return doc;
  }

  Future<AppDocument?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (result == null || result.files.isEmpty) return null;
    final filePath = result.files.single.path;
    if (filePath == null) return null;
    return importFromPath(filePath);
  }

  Future<AppDocument?> importFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final content = await file.readAsString();
    final fileName = file.path
        .split('/')
        .last
        .replaceAll(RegExp(r'\.(md|markdown|txt)$'), '');
    final doc = await _repo.createDocument(
      title: fileName.isEmpty ? 'Imported' : fileName,
      content: content,
    );
    await load();
    return doc;
  }

  Future<void> delete(String id) async {
    await _repo.deleteDocument(id);
    await load();
  }
}
