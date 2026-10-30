/// Lenient coercion for Supabase JSON values.
///
/// Postgres returns `numeric` as a string, `bigint` as an int, and `date` as a
/// `yyyy-MM-dd` string, so every model funnels through these helpers instead of
/// casting directly.
library;

int asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString()) ?? fallback;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  return text == 'true' || text == 't' || text == '1';
}

String asText(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? asTextOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? asDateOrNull(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

DateTime asDate(dynamic value) =>
    asDateOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
