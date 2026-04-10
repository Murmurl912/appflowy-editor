// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AppDocumentImpl _$$AppDocumentImplFromJson(Map<String, dynamic> json) =>
    _$AppDocumentImpl(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$AppDocumentImplToJson(_$AppDocumentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'content': instance.content,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
