import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/attendance.dart';

/// The Saturdays a shared file can go to: from two weeks back to four ahead,
/// one per date, the coming one first and then the nearest others.
List<AttendanceSession> sharedFileDates(
  List<AttendanceSession> sessions, {
  DateTime? now,
}) {
  final today = AppDateUtils.dateOnly(now ?? DateTime.now());
  final byDate = <String, AttendanceSession>{};
  for (final s in sessions) {
    final away = AppDateUtils.daysBetween(today, s.sessionDate);
    if (away < -14 || away > 28) continue;
    byDate.putIfAbsent(AppDateUtils.toIsoDate(s.sessionDate), () => s);
  }
  // Coming ones by how soon, then past ones by how recent.
  int rank(AttendanceSession s) {
    final away = AppDateUtils.daysBetween(today, s.sessionDate);
    return away >= 0 ? away : 100 - away;
  }

  return byDate.values.toList()..sort((a, b) => rank(a) - rank(b));
}

/// «التحضير ده لأنهي سبت؟» for files shared to the app. Null when dismissed.
Future<AttendanceSession?> pickSharedFileDate(
  BuildContext context, {
  required List<AttendanceSession> dates,
  required int files,
}) =>
    showModalBottomSheet<AttendanceSession>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  AppStrings.sharedPickDate(files),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
              ),
              for (final s in dates)
                ListTile(
                  leading: const Icon(Icons.event_rounded),
                  title: Text(AppDateUtils.formatDayDate(s.sessionDate)),
                  onTap: () => Navigator.of(sheet).pop(s),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
