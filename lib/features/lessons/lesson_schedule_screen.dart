import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/lesson.dart';
import '../attendance/break_sheet.dart';
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

  /// The card of the coming Saturday: opened on at first, and the button's
  /// target.
  final _upcomingKey = GlobalKey();
  bool _scrolled = false;

  void _showUpcoming({bool animate = true}) {
    final ctx = _upcomingKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.1,
      duration: animate ? const Duration(milliseconds: 450) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

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

  /// أمين الخدمة: the same sheet as the attendance screen: normal day,
  /// إجازة or نشاط ترفيهي, and whether the lesson is postponed or cancelled.
  Future<void> _setBreak(LessonProgramme programme, DateTime day) async {
    final kind = programme.breakKindOn(day);
    final picked = await showBreakSheet(
      context,
      date: day,
      current: kind == null
          ? null
          : LessonBreak(kind: kind, shift: programme.breakOn(day) ?? true),
    );
    if (picked == null || !mounted) return;
    await _change(() => picked.kind == null
        ? _repository.clearBreak(day)
        : _repository.setBreak(day, shift: picked.shift, kind: picked.kind));
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showUpcoming,
        icon: const Icon(Icons.my_location_rounded),
        label: const Text(AppStrings.jumpToUpcomingLesson),
      ),
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

            // Open on the coming Saturday, once.
            if (!_scrolled) {
              _scrolled = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _showUpcoming(animate: false),
              );
            }

            final children = <Widget>[];
            int? lastMonth;
            for (final (i, day) in days.indexed) {
              if (day.month != lastMonth) {
                lastMonth = day.month;
                children.add(Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 8),
                  child: Text(
                    AppDateUtils.formatMonth(day),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                ));
              }
              final brk = programme.breakOn(day);
              final isUpcoming = day == upcoming;
              final isPast = day.isBefore(today);
              final slot = programme.slotOn(day, firstDay);
              children.add(Padding(
                key: isUpcoming ? _upcomingKey : null,
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: isPast ? 0.62 : 1,
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: isUpcoming ? AppColors.goldTint : null,
                    shape: isUpcoming
                        ? RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                                color: AppColors.gold, width: 1.5),
                          )
                        : null,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DayHeader(
                                  day: day,
                                  slotLabel: slot?.label,
                                  upcoming: isUpcoming,
                                  past: isPast,
                                  broken: brk != null,
                                  breakKind: programme.breakKindOn(day),
                                ),
                                const SizedBox(height: 10),
                                LessonBlock(
                                  date: day,
                                  firstDay: firstDay,
                                  grades: grades,
                                  programme: programme,
                                  showDate: false,
                                ),
                              ],
                            ),
                          ),
                          if (session.isAdmin)
                            PopupMenuButton<String>(
                              onSelected: (value) => value == 'edit'
                                  ? _edit(programme, day, firstDay)
                                  : _setBreak(programme, day),
                              itemBuilder: (_) => [
                                if (slot != null)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text(AppStrings.editLesson),
                                  ),
                                PopupMenuItem(
                                  value: 'break',
                                  child: Text(brk == null
                                      ? AppStrings.noLessonThisSaturday
                                      : AppStrings.changeSaturday),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The top of a week's card: the day on a tinted square, the programme's
/// month and week, and whether it is the coming one, past, or has no lesson.
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.slotLabel,
    required this.upcoming,
    required this.past,
    required this.broken,
    this.breakKind,
  });

  final DateTime day;
  final String? slotLabel;
  final bool upcoming;
  final bool past;
  final bool broken;

  /// Why there is no lesson (a chip instead of the generic «بلا درس»).
  final LessonBreakKind? breakKind;

  @override
  Widget build(BuildContext context) {
    final color = upcoming ? AppColors.gold : AppColors.olive;
    return Row(
      children: [
        Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.readable(color),
                ),
              ),
              Text(
                AppDateUtils.monthName(day.month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.readable(color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppDateUtils.weekdayName(day),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (slotLabel != null)
                Text(
                  slotLabel!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        if (upcoming)
          _Badge(AppStrings.lessonUpcoming, AppColors.gold)
        else if (broken)
          _Badge(
            breakKind?.label ?? AppStrings.lessonNoClass,
            breakKind == LessonBreakKind.activity
                ? AppColors.gold
                : AppColors.coral,
          )
        else if (past)
          const Icon(Icons.check_circle_outline_rounded,
              size: 18, color: AppColors.muted),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.readable(color),
          ),
        ),
      );
}
