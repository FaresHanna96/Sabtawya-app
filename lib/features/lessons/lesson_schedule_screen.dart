import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/lesson.dart';
import 'lesson_editor.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../state/session_controller.dart';
import 'lesson_widgets.dart';

/// The whole year's programme: every Saturday with its Gregorian date, the
/// programme's month and week, and the lesson of each grade. The upcoming one
/// is highlighted; أمين الخدمة can postpone or cancel a week from its menu.
class LessonScheduleScreen extends StatefulWidget {
  const LessonScheduleScreen({super.key});

  @override
  State<LessonScheduleScreen> createState() => _LessonScheduleScreenState();
}

class _LessonScheduleScreenState extends State<LessonScheduleScreen> {
  static const _repository = LessonRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<LessonProgramme>>();

  Future<void> _change(Future<void> Function() action) async {
    final ok = await Ui.runGuarded(
      context,
      action,
      successMessage: AppStrings.saved,
    );
    if (ok) await _sectionKey.currentState?.reload();
  }

  Future<void> _edit(
      LessonProgramme programme, DateTime day, DateTime firstDay) async {
    final slot = programme.slotOn(day, firstDay);
    if (slot == null) return;
    final saved = await showLessonEditor(
      context,
      date: day,
      slot: slot,
      lessons: programme.lessonsAt(slot),
      extras: programme.extrasAt(slot),
    );
    if (saved == true) await _sectionKey.currentState?.reload();
  }

  Future<void> _apply(String action, DateTime day) {
    switch (action) {
      case 'postpone':
        return _repository.setBreak(day, shift: true);
      case 'cancel':
        return _repository.setBreak(day, shift: false);
      default:
        return _repository.clearBreak(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final year = session.currentYear;
    final grades = gradesFor(session);
    final firstDay = firstSessionDay(session);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = upcomingSaturday();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.lessonSchedule)),
      body: SafeArea(
        child: AsyncSection<LessonProgramme>(
          key: _sectionKey,
          load: _repository.programme,
          builder: (context, programme, _) {
            if (year == null || firstDay == null || programme.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: AppStrings.noLessonThisWeek,
                    body: '',
                  ),
                ],
              );
            }

            // Every session day of the attendance year.
            final days = <DateTime>[];
            var d = DateTime(
              year.startDate.year,
              year.startDate.month,
              year.startDate.day,
            );
            while (d.weekday != year.sessionWeekday) {
              d = DateTime(d.year, d.month, d.day + 1);
            }
            while (!d.isAfter(year.endDate)) {
              days.add(d);
              d = DateTime(d.year, d.month, d.day + 7);
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final day = days[i];
                final brk = programme.breakOn(day);
                return Opacity(
                  opacity: day.isBefore(today) ? 0.6 : 1,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: day == upcoming ? AppColors.goldTint : null,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(14, 14, 6, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LessonBlock(
                              date: day,
                              firstDay: firstDay,
                              grades: grades,
                              programme: programme,
                            ),
                          ),
                          if (session.isAdmin)
                            PopupMenuButton<String>(
                              onSelected: (value) => value == 'edit'
                                  ? _edit(programme, day, firstDay)
                                  : _change(() => _apply(value, day)),
                              itemBuilder: (_) => [
                                if (programme.slotOn(day, firstDay) != null)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text(AppStrings.editLesson),
                                  ),
                                if (brk != true)
                                  const PopupMenuItem(
                                    value: 'postpone',
                                    child: Text(AppStrings.postponeLesson),
                                  ),
                                if (brk != false)
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Text(AppStrings.cancelLesson),
                                  ),
                                if (brk != null)
                                  const PopupMenuItem(
                                    value: 'restore',
                                    child: Text(AppStrings.restoreLesson),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
