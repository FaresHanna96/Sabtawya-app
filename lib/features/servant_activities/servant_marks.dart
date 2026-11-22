import '../../data/models/servant_activity.dart';

/// The servants' marks for one Saturday on the admin's «حضور الخدام» tab, with
/// optimistic toggles: a tap shows at once, and the server's answer then
/// confirms it or puts it back. Only the chip being saved waits; every other
/// chip stays usable.
class ServantMarks {
  ServantMarks([List<ServantAttendance> initial = const []])
      : _items = [...initial];

  final List<ServantAttendance> _items;
  final Set<String> _busy = <String>{};

  List<ServantAttendance> get items => List.unmodifiable(_items);

  static String _key(String servantId, String type) => '$servantId|$type';

  /// This chip is being saved.
  bool isBusy(String servantId, String type) =>
      _busy.contains(_key(servantId, type));

  ServantAttendance? find(String servantId, String type) {
    for (final a in _items) {
      if (a.servantId == servantId && a.activityType == type) return a;
    }
    return null;
  }

  /// Replaces every mark (another Saturday, or a fresh load).
  void reset(List<ServantAttendance> items) {
    _items
      ..clear()
      ..addAll(items);
    _busy.clear();
  }

  /// Flips the mark on screen and returns what to tell the server, or null
  /// while that chip is still being saved.
  MarkToggle? begin({
    required String servantId,
    required String type,
    required DateTime date,
    required String recordedBy,
  }) {
    final key = _key(servantId, type);
    if (_busy.contains(key)) return null;
    _busy.add(key);
    final existing = find(servantId, type);
    if (existing != null) {
      _items.remove(existing);
      return MarkToggle._(servantId, type, existing, adding: false);
    }
    // Shown until the server returns the real row (and its id).
    final placeholder = ServantAttendance(
      id: '',
      servantId: servantId,
      activityType: type,
      date: date,
      recordedBy: recordedBy,
    );
    _items.add(placeholder);
    return MarkToggle._(servantId, type, placeholder, adding: true);
  }

  /// «الكل حضروا» in [type]: adds a mark for each of [servantIds] that has
  /// none and is not being saved, and returns those toggles (empty when
  /// everyone already has it).
  List<MarkToggle> beginAll({
    required List<String> servantIds,
    required String type,
    required DateTime date,
    required String recordedBy,
  }) =>
      [
        for (final id in servantIds)
          if (find(id, type) == null && !isBusy(id, type))
            begin(
              servantId: id,
              type: type,
              date: date,
              recordedBy: recordedBy,
            )!,
      ];

  /// The server agreed. An added mark takes the [saved] row's id.
  void succeed(MarkToggle t, [ServantAttendance? saved]) {
    _busy.remove(_key(t.servantId, t.type));
    if (!t.adding || saved == null) return;
    final i = _items.indexWhere((a) => identical(a, t.row));
    if (i >= 0) _items[i] = saved;
  }

  /// The server refused: the mark goes back to what it was.
  void fail(MarkToggle t) {
    _busy.remove(_key(t.servantId, t.type));
    if (t.adding) {
      _items.removeWhere((a) => identical(a, t.row));
    } else if (find(t.servantId, t.type) == null) {
      _items.add(t.row);
    }
  }
}

/// One toggle in flight: what was added (a placeholder) or removed.
class MarkToggle {
  const MarkToggle._(this.servantId, this.type, this.row,
      {required this.adding});

  final String servantId;
  final String type;
  final ServantAttendance row;
  final bool adding;
}
