import 'dart:convert';

const librarySchema = 1;
const maxImportBytes = 200 * 1024 * 1024;
final documentIdPattern = RegExp(r'^[a-f0-9]{64}$');

class LibraryFormatException implements Exception {
  const LibraryFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum Appearance { system, light, dark }

class PaperSettings {
  const PaperSettings({this.appearance = Appearance.system, this.language = 'en'});
  final Appearance appearance;
  final String language;
  PaperSettings copyWith({Appearance? appearance, String? language}) =>
      PaperSettings(appearance: appearance ?? this.appearance,
          language: language ?? this.language);
  Map<String, Object?> toJson() => {
        'appearance': appearance.name,
        'language': language,
      };
  factory PaperSettings.fromJson(Map<String, dynamic> json) {
    final appearance = json['appearance'];
    final language = json['language'];
    if (!Appearance.values.any((v) => v.name == appearance) ||
        !['en', 'ar'].contains(language)) {
      throw const LibraryFormatException('Invalid settings.');
    }
    return PaperSettings(
      appearance: Appearance.values.firstWhere((v) => v.name == appearance),
      language: language as String,
    );
  }
}

/// PDF coordinates: origin at bottom left; top >= bottom.
class HighlightBox {
  HighlightBox(this.left, this.top, this.right, this.bottom) {
    if (![left, top, right, bottom].every((v) => v.isFinite) ||
        left < 0 || bottom < 0 || right <= left || top <= bottom ||
        right > 100000 || top > 100000) {
      throw const LibraryFormatException('Invalid highlight geometry.');
    }
  }
  final double left, top, right, bottom;
  List<double> toJson() => [left, top, right, bottom];
  factory HighlightBox.fromJson(Object? json) {
    if (json is! List || json.length != 4 || json.any((v) => v is! num)) {
      throw const LibraryFormatException('Invalid highlight geometry.');
    }
    return HighlightBox((json[0] as num).toDouble(), (json[1] as num).toDouble(),
        (json[2] as num).toDouble(), (json[3] as num).toDouble());
  }
}

class PaperNote {
  PaperNote({required this.id, required this.page, required this.text,
    required this.createdAt, List<HighlightBox> boxes = const []})
      : boxes = List.unmodifiable(boxes) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) || page < 1 ||
        page > 100000 || text.length > 10000 || boxes.length > 2000 ||
        (text.trim().isEmpty && boxes.isEmpty)) {
      throw const LibraryFormatException('Invalid note.');
    }
  }
  final String id;
  final int page;
  final String text;
  final DateTime createdAt;
  final List<HighlightBox> boxes;
  Map<String, Object?> toJson() => {'id': id, 'page': page, 'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'boxes': boxes.map((b) => b.toJson()).toList()};
  factory PaperNote.fromJson(Map<String, dynamic> json) => PaperNote(
    id: _string(json, 'id'), page: _integer(json, 'page'), text: _string(json, 'text'),
    createdAt: DateTime.parse(_string(json, 'createdAt')),
    boxes: _list(json, 'boxes').map(HighlightBox.fromJson).toList());
}

class PaperDocument {
  PaperDocument({required this.id, required this.title, required this.byteLength,
    required this.importedAt, this.lastOpenedAt, this.lastPage = 1,
    List<int> bookmarks = const [], List<PaperNote> notes = const []})
      : bookmarks = List.unmodifiable(bookmarks.toSet().toList()..sort()),
        notes = List.unmodifiable(notes) {
    if (!documentIdPattern.hasMatch(id) || title.trim().isEmpty ||
        title.length > 240 || byteLength < 8 || byteLength > maxImportBytes ||
        lastPage < 1 || lastPage > 100000 || bookmarks.length > 10000 ||
        bookmarks.any((p) => p < 1 || p > 100000) || notes.length > 10000 ||
        notes.map((n) => n.id).toSet().length != notes.length) {
      throw const LibraryFormatException('Invalid document metadata.');
    }
  }
  final String id, title;
  final int byteLength, lastPage;
  final DateTime importedAt;
  final DateTime? lastOpenedAt;
  final List<int> bookmarks;
  final List<PaperNote> notes;
  PaperDocument copyWith({String? title, DateTime? lastOpenedAt, int? lastPage,
    List<int>? bookmarks, List<PaperNote>? notes}) => PaperDocument(
    id: id, title: title ?? this.title, byteLength: byteLength,
    importedAt: importedAt, lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    lastPage: lastPage ?? this.lastPage, bookmarks: bookmarks ?? this.bookmarks,
    notes: notes ?? this.notes);
  Map<String, Object?> toJson() => {'id': id, 'title': title,
    'byteLength': byteLength, 'importedAt': importedAt.toUtc().toIso8601String(),
    'lastOpenedAt': lastOpenedAt?.toUtc().toIso8601String(), 'lastPage': lastPage,
    'bookmarks': bookmarks, 'notes': notes.map((n) => n.toJson()).toList()};
  factory PaperDocument.fromJson(Map<String, dynamic> json) => PaperDocument(
    id: _string(json, 'id'), title: _string(json, 'title'),
    byteLength: _integer(json, 'byteLength'),
    importedAt: DateTime.parse(_string(json, 'importedAt')),
    lastOpenedAt: json['lastOpenedAt'] == null ? null :
      DateTime.parse(_string(json, 'lastOpenedAt')),
    lastPage: _integer(json, 'lastPage'),
    bookmarks: _list(json, 'bookmarks').map((v) {
      if (v is! int) throw const LibraryFormatException('Invalid bookmark.');
      return v;
    }).toList(),
    notes: _list(json, 'notes').map((v) => PaperNote.fromJson(_object(v))).toList());
}

class PaperLibrary {
  PaperLibrary({this.revision = 0, this.settings = const PaperSettings(),
    List<PaperDocument> documents = const []}) : documents = List.unmodifiable(documents) {
    if (revision < 0 || documents.length > 10000 ||
        documents.map((d) => d.id).toSet().length != documents.length) {
      throw const LibraryFormatException('Invalid library.');
    }
  }
  final int revision;
  final PaperSettings settings;
  final List<PaperDocument> documents;
  PaperDocument? find(String id) {
    for (final doc in documents) { if (doc.id == id) return doc; }
    return null;
  }
  PaperLibrary copyWith({int? revision, PaperSettings? settings,
    List<PaperDocument>? documents}) => PaperLibrary(
    revision: revision ?? this.revision, settings: settings ?? this.settings,
    documents: documents ?? this.documents);
  Map<String, Object?> toJson() => {'schema': librarySchema, 'revision': revision,
    'settings': settings.toJson(), 'documents': documents.map((d) => d.toJson()).toList()};
  factory PaperLibrary.fromJson(Map<String, dynamic> json) {
    if (json['schema'] != librarySchema) {
      throw const LibraryFormatException('Unsupported library version. Keep your data and update the app.');
    }
    return PaperLibrary(revision: _integer(json, 'revision'),
      settings: PaperSettings.fromJson(_object(json['settings'])),
      documents: _list(json, 'documents').map((v) =>
        PaperDocument.fromJson(_object(v))).toList());
  }
}

class AnnotationBundle {
  AnnotationBundle({required this.documentId, required this.notes,
    required this.bookmarks});
  final String documentId;
  final List<PaperNote> notes;
  final List<int> bookmarks;
  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': 'cave-paper-annotations', 'version': 1,
    'documentSha256': documentId, 'bookmarks': bookmarks,
    'notes': notes.map((n) => n.toJson()).toList()});
  factory AnnotationBundle.decode(String text) {
    if (utf8.encode(text).length > 5 * 1024 * 1024) {
      throw const LibraryFormatException('Annotation file is too large.');
    }
    final json = _object(jsonDecode(text));
    if (json['format'] != 'cave-paper-annotations' || json['version'] != 1 ||
        !documentIdPattern.hasMatch(_string(json, 'documentSha256'))) {
      throw const LibraryFormatException('Invalid annotation file.');
    }
    // Reuse the document validator, including bookmark and note limits.
    final validated = PaperDocument.fromJson({
      'id': json['documentSha256'], 'title': 'annotation import', 'byteLength': 8,
      'importedAt': '2026-01-01T00:00:00Z', 'lastPage': 1,
      'bookmarks': json['bookmarks'], 'notes': json['notes']});
    return AnnotationBundle(documentId: validated.id, notes: validated.notes,
      bookmarks: validated.bookmarks);
  }
}

Map<String, dynamic> _object(Object? v) {
  if (v is! Map<String, dynamic>) throw const LibraryFormatException('Expected an object.');
  return v;
}
String _string(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! String) throw LibraryFormatException('Invalid $key.');
  return v;
}
int _integer(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! int) throw LibraryFormatException('Invalid $key.');
  return v;
}
List<dynamic> _list(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v is! List) throw LibraryFormatException('Invalid $key.');
  return v;
}
