import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/child.dart';

/// What the status strip can say, most urgent first.
enum ProfileAlertKind { inactive, absent, noFollowUp, birthday }

/// One line of the strip under the child's name.
class ProfileAlert {
  const ProfileAlert(this.kind, this.text, {this.callToAction = false});

  final ProfileAlertKind kind;
  final String text;

  /// The strip offers «اتصل» for it.
  final bool callToAction;

  Color get color => switch (kind) {
        ProfileAlertKind.inactive => AppColors.muted,
        ProfileAlertKind.absent => AppColors.danger,
        ProfileAlertKind.noFollowUp => AppColors.warning,
        ProfileAlertKind.birthday => AppColors.gold,
      };

  IconData get icon => switch (kind) {
        ProfileAlertKind.inactive => Icons.pause_circle_outline_rounded,
        ProfileAlertKind.absent => Icons.event_busy_rounded,
        ProfileAlertKind.noFollowUp => Icons.phone_missed_rounded,
        ProfileAlertKind.birthday => Icons.cake_rounded,
      };
}

/// How many of the latest Saturdays in a row the child missed. Only Saturdays
/// the class took ([history] holds the child's records; [sessionDates] every
/// Saturday the class met, no-lesson days already left out).
int absentRun(List<ChildSessionScore> history, List<DateTime> sessionDates) {
  final present = <String, bool>{
    for (final h in history)
      if (!h.isBreak) _key(h.sessionDate): h.isPresent,
  };
  final taken = [
    for (final d in sessionDates)
      if (present.containsKey(_key(d))) d,
  ]..sort((a, b) => b.compareTo(a));
  var run = 0;
  for (final d in taken) {
    if (present[_key(d)]!) break;
    run++;
  }
  return run;
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Days until the next birthday (0 = today); null without a birth date.
int? daysToBirthday(DateTime? birth, DateTime today) {
  if (birth == null) return null;
  final t = DateTime(today.year, today.month, today.day);
  for (var i = 0; i <= 366; i++) {
    final day = t.add(Duration(days: i));
    if (birth.month == day.month &&
        (birth.day == day.day ||
            (birth.month == 2 &&
                birth.day == 29 &&
                day.day == 28 &&
                DateTime(day.year, 2, 29).month != 2))) {
      return i;
    }
  }
  return null;
}

/// The strip's lines for [child], most urgent first (at most two are shown).
///
/// - stopped: «المخدوم متوقف»
/// - missed 2+ Saturdays in a row: «غايب آخر N سبوت» (with «اتصل»)
/// - while absent, no call or visit for 30 days (or never)
/// - birthday today or within 7 days
List<ProfileAlert> profileAlerts({
  required Child child,
  required int absentSaturdays,
  required DateTime today,
}) {
  final out = <ProfileAlert>[];
  if (!child.isActive) {
    out.add(const ProfileAlert(
        ProfileAlertKind.inactive, AppStrings.profileInactive));
  }
  if (child.isActive && absentSaturdays >= 2) {
    out.add(ProfileAlert(
      ProfileAlertKind.absent,
      AppStrings.profileAbsentRun(absentSaturdays),
      callToAction: true,
    ));
    final last = [child.lastPhoneVisitDate, child.lastHomeVisitDate]
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final days = last == null ? null : today.difference(last).inDays;
    if (days == null || days > 30) {
      out.add(ProfileAlert(
        ProfileAlertKind.noFollowUp,
        days == null
            ? AppStrings.profileNeverFollowedUp
            : AppStrings.profileLastFollowUp(days),
        callToAction: true,
      ));
    }
  }
  final b = daysToBirthday(child.birthDate, today);
  if (child.isActive && b != null && b <= 7) {
    out.add(ProfileAlert(
      ProfileAlertKind.birthday,
      b == 0
          ? AppStrings.profileBirthdayToday
          : AppStrings.profileBirthdayIn(b),
    ));
  }
  return out;
}

/// The strip under the name: the most urgent one or two alerts, «اتصل» on the
/// first that asks for a call. Nothing at all when all is well.
class ProfileStatusStrip extends StatelessWidget {
  const ProfileStatusStrip({super.key, required this.alerts, this.onCall});

  final List<ProfileAlert> alerts;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final shown = alerts.take(2).toList();
    final first = shown.first;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: statusTint(first.color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(first.icon, size: 20, color: AppColors.readable(first.color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in shown)
                  Text(
                    a.text,
                    style: TextStyle(
                      fontSize: a == first ? 13.5 : 12,
                      fontWeight:
                          a == first ? FontWeight.w800 : FontWeight.w600,
                      color: AppColors.readable(a.color),
                    ),
                  ),
              ],
            ),
          ),
          if (onCall != null && shown.any((a) => a.callToAction))
            FilledButton.icon(
              onPressed: onCall,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.readable(first.color),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text(AppStrings.call),
            ),
        ],
      ),
    );
  }
}
