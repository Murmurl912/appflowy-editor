import 'package:example/models/app_document.dart';
import 'package:example/repo/document_repository.dart';
import 'package:example/repo/strings.dart';

class InMemoryDocumentRepository implements DocumentRepository {
  final Map<String, AppDocument> _store = {};

  InMemoryDocumentRepository() {
    final now = DateTime.now();
    const id = 'sample';
    _store[id] = AppDocument(
      id: id,
      title: 'Markdown Sample',
      content: kMarkdownSample1,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<List<AppDocument>> listDocuments() async {
    final docs = _store.values.toList();
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  @override
  Future<AppDocument> createDocument({
    String title = 'Untitled',
    String content = '',
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();
    final doc = AppDocument(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    _store[id] = doc;
    return doc;
  }

  @override
  Future<AppDocument?> getDocument(String id) async {
    return _store[id];
  }

  @override
  Future<void> saveDocument(AppDocument document) async {
    _store[document.id] = document.copyWith(updatedAt: DateTime.now());
  }

  @override
  Future<void> deleteDocument(String id) async {
    _store.remove(id);
  }
}
