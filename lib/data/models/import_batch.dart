import 'parsers.dart';

/// One Excel import that can still be undone: when, by whom, and how many
/// children it added and changed.
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.createdAt,
    required this.inserted,
    required this.updated,
    this.actorName,
  });

  final String id;
  final DateTime createdAt;
  final int inserted;
  final int updated;
  final String? actorName;

  factory ImportBatch.fromMap(Map<String, dynamic> map) => ImportBatch(
        id: asText(map['id']),
        createdAt: asDate(map['created_at']).toLocal(),
        inserted: asInt(map['inserted']),
        updated: asInt(map['updated']),
        actorName: asTextOrNull(map['actor_name']),
      );
}
