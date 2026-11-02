import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/lesson.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../state/session_controller.dart';

/// The grades whose lessons a person prepares: their classes' grades, or all
/// four for أمين الخدمة and خادم عام (who serve every class).
List<int> gradesFor(SessionController session) {
  final grades = <int>{
    for (final c in session.myClasses)
      if (LessonProgramme.gradeOf(c.className) != null)
        LessonProgramme.gradeOf(c.className)!,
  };
  if (grades.isEmpty) return const [3, 4, 5, 6];
  return grades.toList()..sort();
}

/// The first Saturday on or after today.
DateTime upcomingSaturday([DateTime? from]) {
  final today = from ?? DateTime.now();
  final day = DateTime(today.year, today.month, today.day);
  return day.add(Duration(days: (DateTime.saturday - day.weekday) % 7));
}

/// Where the programme starts (the first session day of the Coptic year); the
/// lessons count weekly from it.
DateTime? firstSessionDay(SessionController session) {
  final year = session.currentYear;
  if (year == null) return null;
  return LessonProgramme.programmeStart(year.startDate, year.sessionWeekday);
}

/// "Gregorian date • the programme's month and week" for a lesson day.
String dateLine(DateTime date, DateTime firstDay, LessonProgramme programme) {
  final slot = programme.slotOn(date, firstDay);
  return slot == null
      ? AppDateUtils.formatDayDate(date)
      : '${AppDateUtils.formatDayDate(date)} • ${slot.label}';
}

/// The lesson(s) to prepare for one Saturday, one line per grade.
///
/// Loads the programme itself (it is small and kept for offline use).
class LessonOfDay extends StatefulWidget {
  const LessonOfDay({
    super.key,
    required this.date,
    this.title = AppStrings.lessonOfWeek,
    this.showExtras = true,
  });

  final DateTime date;
  final String title;
  final bool showExtras;

  @override
  State<LessonOfDay> createState() => _LessonOfDayState();
}

class _LessonOfDayState extends State<LessonOfDay> {
  late final Future<LessonProgramme> _programme =
      const LessonRepository().programme();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final grades = gradesFor(session);
    final firstDay = firstSessionDay(session);
    return FutureBuilder<LessonProgramme>(
      future: _programme,
      builder: (context, snapshot) {
        final programme = snapshot.data;
        if (programme == null || programme.isEmpty || firstDay == null) {
          // Loading, no programme loaded yet, or offline without a copy.
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SectionCard(
            title: widget.title,
            icon: Icons.menu_book_rounded,
            accent: AppColors.olive,
            collapsible: true,
            initiallyExpanded: true,
            child: LessonBlock(
              date: widget.date,
              firstDay: firstDay,
              grades: grades,
              programme: programme,
              showExtras: widget.showExtras,
            ),
          ),
        );
      },
    );
  }
}

/// The date line plus each grade's lesson (and the shared pulpit and hymns).
class LessonBlock extends StatelessWidget {
  const LessonBlock({
    super.key,
    required this.date,
    required this.firstDay,
    required this.grades,
    required this.programme,
    this.showExtras = true,
  });

  final DateTime date;
  final DateTime firstDay;
  final List<int> grades;
  final LessonProgramme programme;
  final bool showExtras;

  @override
  Widget build(BuildContext context) {
    final extras = programme.extrasOn(date, firstDay: firstDay);
    final lessons = {
      for (final g in grades)
        g: programme.lessonOn(date, g, firstDay: firstDay),
    };
    final hasAny = lessons.values.any((l) => l != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLine(date, firstDay, programme),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        if (!hasAny)
          Text(
            switch (programme.breakOn(date)) {
              true => AppStrings.lessonPostponed,
              false => AppStrings.lessonCancelled,
              null => AppStrings.noLessonThisWeek,
            },
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        for (final entry in lessons.entries)
          if (entry.value != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.olive.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${entry.key}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.olive,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value!.page == null
                          ? entry.value!.title
                          : '${entry.value!.title} '
                              '(${AppStrings.page} ${entry.value!.page})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (showExtras && extras?.pulpit != null)
          InfoRow(
            label: AppStrings.pulpit,
            value: extras!.pulpit,
            icon: Icons.record_voice_over_outlined,
          ),
        if (showExtras && extras?.hymns != null)
          InfoRow(
            label: AppStrings.hymns,
            value: extras!.hymns,
            icon: Icons.music_note_outlined,
          ),
      ],
    );
  }
}
