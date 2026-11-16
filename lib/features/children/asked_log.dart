import 'package:hive/hive.dart';

/// When each child's family was last asked, on this phone, for what their
/// record is missing. It stops the same family being asked twice in a week.
/// Kept on the device on purpose: no table, nothing to sync; the cost is that
/// two servants' phones do not see each other's asks.
class AskedLog {
  AskedLog({Future<Box<dynamic>> Function()? open})
      : _open = open ?? (() => Hive.openBox<dynamic>(_boxName)),
        _memory = null;

  /// Kept in memory only, for tests.
  AskedLog.memory()
      : _open = null,
        _memory = <String, String>{};

  static const _boxName = 'asked_missing_info';

  /// A family asked more recently than this is asked about before asking again.
  static const askAgainAfterDays = 7;

  /// The one the app uses.
  static final AskedLog instance = AskedLog();

  final Future<Box<dynamic>> Function()? _open;
  final Map<String, String>? _memory;
  Box<dynamic>? _box;

  Future<Box<dynamic>?> _ready() async {
    try {
      return _box ??= await _open!();
    } catch (_) {
      return null; // a missing log only means no "already asked" hint
    }
  }

  /// When [childId]'s family was asked, null when never.
  Future<DateTime?> when(String childId) async {
    if (_memory != null) return _parse(_memory[childId]);
    final box = await _ready();
    return _parse(box?.get(childId));
  }

  /// Every recorded ask, by child id.
  Future<Map<String, DateTime>> all() async {
    if (_memory != null) {
      return {
        for (final e in _memory.entries)
          if (_parse(e.value) != null) e.key: _parse(e.value)!,
      };
    }
    final box = await _ready();
    if (box == null) return const <String, DateTime>{};
    return {
      for (final key in box.keys)
        if (_parse(box.get(key)) != null) '$key': _parse(box.get(key))!,
    };
  }

  Future<void> mark(String childId, {DateTime? at}) async {
    final value = (at ?? DateTime.now()).toIso8601String();
    if (_memory != null) {
      _memory[childId] = value;
      return;
    }
    final box = await _ready();
    await box?.put(childId, value);
  }

  /// Whole days between [asked] and [now]; null when never asked.
  static int? daysAgo(DateTime? asked, DateTime now) {
    if (asked == null) return null;
    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    return day(now).difference(day(asked)).inDays;
  }

  /// True when asking again now would be a repeat.
  static bool isRecent(DateTime? asked, DateTime now) {
    final days = daysAgo(asked, now);
    return days != null && days < askAgainAfterDays;
  }

  static DateTime? _parse(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
