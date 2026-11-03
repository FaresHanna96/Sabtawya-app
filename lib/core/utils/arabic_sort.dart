/// Alphabetical ordering for Arabic names.
///
/// The database's collation does not follow the Arabic alphabet, so lists that
/// must read A-to-Z (the attendance sheet) are sorted here. Variants of a
/// letter sort together (أ إ آ as ا, ى as ي, ة as ه) and diacritics and
/// tatweel are ignored.
class ArabicSort {
  const ArabicSort._();

  static final _marks = RegExp('[ً-ٰٟـ]');

  static String key(String name) {
    final cleaned = name
        .trim()
        .replaceAll(_marks, '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.toLowerCase();
  }

  static int compare(String a, String b) => key(a).compareTo(key(b));
}
