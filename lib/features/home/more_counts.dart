import '../../core/utils/app_date_utils.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../children/missing_info.dart';
import 'more_entries.dart';

/// The badges on المزيد. Each number loads on its own: one that fails just
/// shows no badge, and none of them holds up the page. Failed sync is known
/// on the phone already, so it is added by the screen, not loaded here.
class MoreCounts {
  const MoreCounts._();

  static Future<Map<MoreCount, int>> load({
    required String? yearId,
    required bool isAdmin,
  }) async {
    const children = ChildRepository();
    const servants = ServantRepository();
    const reports = ReportRepository();

    final out = <MoreCount, int>{};
    Future<void> put(MoreCount key, Future<int> Function() count) async {
      try {
        out[key] = await count();
      } catch (_) {
        // No badge rather than an error on a page of links.
      }
    }

    await Future.wait([
      // The same rule as متابعة الغياب: 2 Saturdays or more in a row.
      if (yearId != null)
        put(MoreCount.absence, () async {
          final streaks = await reports.streaks(
            yearId: yearId,
            minAbsent: 2,
            minPresent: 999,
          );
          return streaks.where((s) => s.absentStreak >= 2).length;
        }),
      // These two ask for the same children at the same moment, which the
      // repository answers with one download.
      put(MoreCount.missingInfo, () async {
        return MissingInfo.filter(await children.all(), null).length;
      }),
      put(MoreCount.birthdays, () async {
        final today = DateTime.now();
        final (kids, staff) =
            await (children.all(), servants.servantsWithBirthdayToday()).wait;
        final kidsToday = kids.where(
          (c) =>
              c.birthDate != null &&
              AppDateUtils.isBirthdayOn(c.birthDate!, today),
        );
        return kidsToday.length + staff.length;
      }),
      if (isAdmin)
        put(MoreCount.invites, () async {
          return (await servants.pendingInvites()).length;
        }),
      if (isAdmin)
        put(
          MoreCount.pendingPreps,
          () => const ServantActivityRepository().pendingPrepsCount(),
        ),
    ]);
    return out;
  }
}
