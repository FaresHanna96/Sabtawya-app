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

  /// Whether a visit on [date] becomes the child's "last visit": only when it
  /// is not older than the one already stored, so back-dating an old call
  /// never hides a newer one.
  static bool isLatest(DateTime date, DateTime? storedLast) =>
      storedLast == null ||
      !DateTime(date.year, date.month, date.day).isBefore(
        DateTime(storedLast.year, storedLast.month, storedLast.day),
      );

  /// Whether the child was contacted (phone or home) since they last attended.
  /// A child who never attended counts as contacted once any visit exists.
  static bool contactedSince(Child child, DateTime? lastPresent) {
    final visits = [child.lastPhoneVisitDate, child.lastHomeVisitDate]
        .whereType<DateTime>();
    if (visits.isEmpty) return false;
    if (lastPresent == null) return true;
    return visits.any((d) => d.isAfter(lastPresent));
  }
}
