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
import '../calendar/calendar_screen.dart';
import 'home_status_card.dart';
import 'needs_attention_strip.dart';
import 'next_saturday_prep_card.dart';
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

  /// Counts the loads: the birthdays, missing-info and lesson cards load on
  /// their own, and fetch again whenever it changes.
  int _loads = 0;

  Future<_AdminDashboard> _load() async {
    _loads++;
    final yearId = context.read<SessionController>().currentYear?.id;

    // The reads do not depend on each other, so run them side by side
    // instead of one after another (the dashboard waited for each in turn).
    if (yearId == null) {
      return _AdminDashboard(stats: await _reports.adminStats());
    }

    // صحة الفصول (with the class scores it needs) moved to the Classes tab,
    // so the home no longer downloads either.
    final (stats, weeks) = await (
      _reports.adminStats(),
      _reports.weeklyAttendance(yearId),
    ).wait;

    return _AdminDashboard(stats: stats, weeks: weeks);
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

  /// «سجّل الحضور» while today's attendance still has a class to record.
  VoidCallback? _recordNow(List<WeeklyAttendance> weeks) {
    if (weeks.isEmpty || !weeks.last.inProgress) return null;
    final date = weeks.last.date;
    return () async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AttendanceScreen(showAppBar: true, initialDate: date),
        ),
      );
      if (mounted) context.read<SessionController>().markChanged();
    };
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
              // The week at a glance in one card (who, how the last Saturday
              // went, the totals), then what needs doing (محتاج متابعة,
              // today's birthdays on one line), the Saturday ahead (lesson and
              // prep in one card) and the shortcuts. The chart is the detail.
              FadeSlideIn(
                index: 0,
                child: HomeStatusCard(
                  name: session.displayName,
                  yearName: session.currentYear?.name,
                  onRecord: _recordNow(data.weeks),
                  totals: [
                    HomeTotal(
                      value: stats.childrenCount,
                      label: AppStrings.totalChildren,
                      icon: Icons.groups_rounded,
                      sub: '${stats.boysCount} ${AppStrings.boys} • '
                          '${stats.girlsCount} ${AppStrings.girls}',
                    ),
                    HomeTotal(
                      value: stats.classesCount,
                      label: AppStrings.totalClasses,
                      icon: Icons.class_rounded,
                    ),
                    HomeTotal(
                      value: stats.servantsCount,
                      label: AppStrings.totalServants,
                      icon: Icons.supervisor_account_rounded,
                      sub: '${stats.adminsCount} ${AppStrings.adminsShort}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                index: 1,
                child: NeedsAttentionSection(reloadToken: _loads),
              ),
              FadeSlideIn(
                index: 2,
                child: TodayBirthdaysSection(
                  reloadToken: _loads,
                  hideWhenEmpty: true,
                  compact: true,
                ),
              ),
              FadeSlideIn(
                index: 3,
                child: NextSaturdaySection(
                  reloadToken: _loads,
                  showPrep: true,
                ),
              ),
              FadeSlideIn(index: 4, child: _quickActions()),
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

  Widget _quickActions() {
    // خادم عام sees everything but does not add or import children.
    final canEditChildren = !context.read<SessionController>().isGeneralServant;
    return QuickActionGrid(
      compact: true,
      actions: [
        // Attendance is a bottom tab and the import is in Children and
        // المزيد, so they are not repeated here.
        if (canEditChildren)
          QuickAction(
            Icons.person_add_alt_1_rounded,
            AppStrings.addChild,
            AppColors.navy,
            () => _push(const ChildFormScreen()),
          ),
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
    this.weeks = const <WeeklyAttendance>[],
  });

  final AdminStats stats;

  /// Attendance per Saturday, for the weekly chart.
  final List<WeeklyAttendance> weeks;
}
