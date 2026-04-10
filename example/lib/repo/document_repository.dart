import 'package:example/models/app_document.dart';

abstract class DocumentRepository {
  Future<List<AppDocument>> listDocuments();
  Future<AppDocument> createDocument({String title, String content});
  Future<AppDocument?> getDocument(String id);
  Future<void> saveDocument(AppDocument document);
  Future<void> deleteDocument(String id);
}
