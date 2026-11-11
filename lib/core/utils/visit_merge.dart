import '../../data/models/child.dart';

/// Rules for saving a follow-up (افتقاد) without piling up duplicates.
class VisitMerge {
  const VisitMerge._();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The id of the history entry to update instead of adding a new one: the
  /// caller's own entry for the same child, type and day. Null means insert.
  static String? existingEntry({
    required List<ChildVisitLog> logs,
    required String childId,
    required String visitType,
    required DateTime date,
    required String? myId,
  }) {
    if (myId == null) return null;
    for (final log in logs) {
      if (log.childId == childId &&
          log.visitType == visitType &&
          log.recordedBy == myId &&
          _sameDay(log.visitDate, date)) {
        return log.id;
      }
    }
    return null;
  }
}
