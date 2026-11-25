import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'lesson_materials_sheet.dart';
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
DateTime upcomingSaturday([DateTime? from]) =>
    AppDateUtils.nextSaturday(from);

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
    this.reloadToken = 0,
    this.initiallyExpanded = true,
  });

  final DateTime date;
  final String title;
  final bool showExtras;

  /// The admin home opens it closed, to keep the page short.
  final bool initiallyExpanded;

  /// Changes when the home reloads (pull-to-refresh, or data changed
  /// elsewhere); the card then fetches again, keeping what it shows meanwhile.
  final int reloadToken;

  @override
  State<LessonOfDay> createState() => _LessonOfDayState();
}

class _LessonOfDayState extends State<LessonOfDay> {
  late Future<LessonProgramme> _programme =
      const LessonRepository().programme();

  @override
  void didUpdateWidget(LessonOfDay old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) {
      _programme = const LessonRepository().programme();
    }
  }

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
            initiallyExpanded: widget.initiallyExpanded,
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
    this.showDate = true,
  });

  final DateTime date;
  final DateTime firstDay;
  final List<int> grades;
  final LessonProgramme programme;
  final bool showExtras;

  /// The date line on top; the programme page draws its own header.
  final bool showDate;

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
        if (showDate) ...[
          Text(
            dateLine(date, firstDay, programme),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
        ],
        if (!hasAny)
          Text(
            switch (programme.breakOn(date)) {
              final shift? => AppStrings.breakSummary(
                  (programme.breakKindOn(date) ?? LessonBreakKind.holiday)
                      .label,
                  holiday: (programme.breakKindOn(date) ??
                          LessonBreakKind.holiday) ==
                      LessonBreakKind.holiday,
                  postponed: shift,
                ),
              null => AppStrings.noLessonThisWeek,
            },
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        if (lessons.values.where((l) => l != null).length == 1)
          for (final entry in lessons.entries.where((e) => e.value != null))
            LessonSingle(grade: entry.key, lesson: entry.value!)
        else
        for (final entry in lessons.entries.where((e) => e.value != null))
          LessonRow(
            grade: entry.key,
            lesson: entry.value!,
            last: entry.key ==
                lessons.entries.where((e) => e.value != null).last.key,
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

/// One grade's lesson in a list of several, as ONE compact line: the «صف 3»
/// tag, the title (it wraps to a second line only when it must), the page
/// (kept whole, never «ص / 94») and a small paperclip for the teaching aids.
class LessonRow extends StatelessWidget {
  const LessonRow({
    super.key,
    required this.grade,
    required this.lesson,
    required this.last,
  });

  final int grade;
  final Lesson lesson;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.navy.withValues(alpha: 0.06),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.olive.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              AppStrings.gradeLabel(grade),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.oliveText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                lesson.title,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (lesson.page != null) ...[
            const SizedBox(width: 6),
            Text(
              '${AppStrings.page} ${lesson.page}',
              softWrap: false,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
          // What أمين الخدمة attached, and shared preps.
          Tooltip(
            message: AppStrings.materialsLink,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => showLessonMaterials(context, lesson: lesson),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.skyTint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.attach_file_rounded,
                        size: 14, color: AppColors.skyText),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lone lesson (a servant's own grade) with room to read: the «صف 3» tag
/// and its page on one line, the title in a larger size, and the teaching
/// aids as a labelled button (an unlabelled paperclip says nothing when it is
/// the only thing there).
class LessonSingle extends StatelessWidget {
  const LessonSingle({super.key, required this.grade, required this.lesson});

  final int grade;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.olive.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.olive.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  AppStrings.gradeLabel(grade),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.oliveText,
                  ),
                ),
              ),
              if (lesson.page != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${AppStrings.page} ${lesson.page}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lesson.title,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: AppColors.skyTint,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => showLessonMaterials(context, lesson: lesson),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.attach_file_rounded,
                          size: 18, color: AppColors.skyText),
                      SizedBox(width: 6),
                      Text(
                        AppStrings.materialsLink,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.skyText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
