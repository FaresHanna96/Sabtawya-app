import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/responsive.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../children/child_form_screen.dart';
import '../excel/import_children_screen.dart';
import '../calendar/calendar_screen.dart';
import '../lessons/lesson_widgets.dart';
import 'home_numbers_card.dart';
import 'quick_action_grid.dart';
import 'weekly_attendance_chart.dart';
import 'today_birthdays_section.dart';

/// The admin landing page: system-wide counters, class standings, the children
/// who need attention, and who changed what recently.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_AdminDashboard>>();

  /// "عرض الكل" on the activity feed.
  bool _showAllActivity = false;

  /// Counts the loads: the birthdays, missing-info and lesson cards load on
  /// their own, and fetch again whenever it changes.
  int _loads = 0;

  Future<_AdminDashboard> _load() async {
    _loads++;
    final yearId = context.read<SessionController>().currentYear?.id;

    // The reads do not depend on each other, so run them side by side
    // instead of one after another (the dashboard waited for each in turn).
    if (yearId == null) {
      final (stats, activity) =
          await (_reports.adminStats(), _reports.recentActivity()).wait;
      return _AdminDashboard(stats: stats, activity: activity);
    }

    // صحة الفصول (with the class scores it needs) moved to the Classes tab,
    // so the home no longer downloads either.
    final (stats, activity, weeks) = await (
      _reports.adminStats(),
      _reports.recentActivity(),
      _reports.weeklyAttendance(yearId),
    ).wait;

    return _AdminDashboard(stats: stats, activity: activity, weeks: weeks);
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  /// A class that did not record, from the weekly chart: its attendance for
  /// that Saturday, then every card reloads.
  Future<void> _record(String classId, DateTime date) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(
          showAppBar: true,
          initialClassId: classId,
          initialDate: date,
        ),
      ),
    );
    if (mounted) context.read<SessionController>().markChanged();
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();

    return AsyncSection<_AdminDashboard>(
      key: _sectionKey,
      load: _load,
      builder: (context, data, reload) {
        final stats = data.stats;

        // Not a lazy ListView: it rebuilt each section as it scrolled back
        // into view, which replayed its entrance (after a delay) every time.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          // On a phone one column in this order; on a wide window what to
          // act on stays at the start (the right) and the chart and the
          // activity feed move beside it.
          child: TwoColumns(
            main: [
              // A slim greeting and every number in one card, then what is
              // waiting (محتاج متابعة), today (birthdays, if any; the lesson,
              // closed), the shortcuts and the details.
              FadeSlideIn(
                index: 0,
                child:
                    _greeting(session.displayName, session.currentYear?.name),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 1,
                child: HomeNumbersCard(
                  children: stats.childrenCount,
                  classes: stats.classesCount,
                  servants: stats.servantsCount,
                  admins: stats.adminsCount,
                  boys: stats.boysCount,
                  girls: stats.girlsCount,
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 3,
                child: TodayBirthdaysSection(
                  reloadToken: _loads,
                  hideWhenEmpty: true,
                ),
              ),
              FadeSlideIn(
                index: 4,
                child: LessonOfDay(
                  date: upcomingSaturday(),
                  reloadToken: _loads,
                  initiallyExpanded: false,
                ),
              ),
              FadeSlideIn(index: 5, child: _quickActions()),
              const SizedBox(height: 16),
            ],
            side: [
              // The chart names its own Saturday; with nothing recorded yet
              // the last Saturday keeps a card of its own.
              FadeSlideIn(
                index: 6,
                child: data.weeks.any((w) => w.recorded)
                    ? WeeklyAttendanceChart(
                        weeks: data.weeks,
                        classNames: {
                          for (final c
                              in context.read<SessionController>().myClasses)
                            c.classId: c.className,
                        },
                        onRecord: _record,
                      )
                    : SectionCard(child: _lastSaturday(stats)),
              ),
              const SizedBox(height: 16),
              if (data.activity.isNotEmpty)
                FadeSlideIn(index: 7, child: _activity(data.activity)),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- sections

  /// The last Saturday taken: at the top of the weekly chart's card.
  Widget _lastSaturday(AdminStats stats) => InfoRow(
        label: AppStrings.lastAttendance,
        value: stats.lastSessionDate == null
            ? AppStrings.noAttendanceYet
            : AppDateUtils.formatDayDate(stats.lastSessionDate!),
        icon: Icons.event_available_outlined,
      );

  /// Recent activity as a small timeline: an icon per kind of change and how
  /// long ago it happened. Three at first, the rest behind "عرض الكل".
  Widget _activity(List<ActivityLogEntry> all) {
    final shown = _showAllActivity ? all : all.take(3).toList();
    return SectionCard(
      title: AppStrings.recentActivity,
      icon: Icons.history_rounded,
      accent: AppColors.sky,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++)
              _activityRow(shown[i], last: i == shown.length - 1),
            if (all.length > 3)
              TextButton(
                onPressed: () =>
                    setState(() => _showAllActivity = !_showAllActivity),
                child: Text(
                  _showAllActivity ? AppStrings.showLess : AppStrings.showAll,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _activityRow(ActivityLogEntry entry, {required bool last}) {
    final (icon, color) = switch (entry.entity) {
      'attendance_records' => (Icons.fact_check_rounded, AppColors.success),
      'children' => (Icons.child_care_rounded, AppColors.navy),
      'class_servants' => (Icons.group_add_rounded, AppColors.olive),
      'profiles' => (Icons.person_add_alt_1_rounded, AppColors.sky),
      'event_payments' => (Icons.payments_rounded, AppColors.gold),
      _ => (Icons.history_rounded, AppColors.muted),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The dot and the line joining it to the next entry.
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.muted.withValues(alpha: 0.18),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.description, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    AppDateUtils.agoLabel(entry.createdAt),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _greeting(String name, String? yearName) =>
      GreetingBanner(name: name, subtitle: yearName, dense: true);

  Widget _quickActions() {
    // خادم عام sees everything but does not add or import children.
    final canEditChildren = !context.read<SessionController>().isGeneralServant;
    return QuickActionGrid(
      actions: [
        QuickAction(
          Icons.fact_check_rounded,
          AppStrings.attendanceTitle,
          AppColors.success,
          () => _push(const AttendanceScreen(showAppBar: true)),
        ),
        if (canEditChildren) ...[
          QuickAction(
            Icons.person_add_alt_1_rounded,
            AppStrings.addChild,
            AppColors.navy,
            () => _push(const ChildFormScreen()),
          ),
          // Short label: the full one is cut off in a quarter-width tile.
          QuickAction(
            Icons.upload_file_rounded,
            AppStrings.importExcelShort,
            AppColors.olive,
            () => _push(const ImportChildrenScreen()),
          ),
        ],
        QuickAction(
          Icons.calendar_month_rounded,
          AppStrings.calendarTitle,
          AppColors.gold,
          () => _push(const CalendarScreen()),
        ),
      ],
    );
  }
}

class _AdminDashboard {
  const _AdminDashboard({
    required this.stats,
    required this.activity,
    this.weeks = const <WeeklyAttendance>[],
  });

  final AdminStats stats;
  final List<ActivityLogEntry> activity;

  /// Attendance per Saturday, for the weekly chart.
  final List<WeeklyAttendance> weeks;
}
