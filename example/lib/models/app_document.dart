import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_document.freezed.dart';
part 'app_document.g.dart';

@freezed
abstract class AppDocument with _$AppDocument {
  const factory AppDocument({
    required String id,
    required String title,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AppDocument;

  factory AppDocument.fromJson(Map<String, dynamic> json) =>
      _$AppDocumentFromJson(json);
}
