import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../children/child_form_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../servant_activities/my_activities_screen.dart';
import '../calendar/calendar_screen.dart';
import '../lessons/lesson_widgets.dart';
import 'missing_info_section.dart';
import 'quick_action_grid.dart';
import 'today_birthdays_section.dart';
import 'weekly_attendance_chart.dart';

/// The servant landing page. It shows only the assigned classes, which is a
/// consequence of row level security rather than of filtering done here.
class ServantDashboardScreen extends StatefulWidget {
  const ServantDashboardScreen({super.key});

  @override
  State<ServantDashboardScreen> createState() => _ServantDashboardScreenState();
}

class _ServantDashboardScreenState extends State<ServantDashboardScreen> {
  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ServantDashboard>>();

  /// Counts the loads: the birthdays, missing-info and lesson cards load on
  /// their own, and fetch again whenever it changes.
  int _loads = 0;

  /// The Saturday-by-Saturday attendance (through row level security, so
  /// the servant's classes only) and the whole service's totals. The classes
  /// themselves are in the «فصلي» tab, not repeated here.
  Future<_ServantDashboard> _load() async {
    _loads++;
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const _ServantDashboard();
    final (weeks, service) = await (
      _reports.weeklyAttendance(yearId),
      // The whole service's %, to compare the class with (totals only).
      _reports.serviceWeeklyAttendance(yearId),
    ).wait;
    return _ServantDashboard(weeks: weeks, service: service);
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final classes = session.myClasses;

    if (classes.isEmpty) {
      return const EmptyState(
        icon: Icons.class_outlined,
        title: AppStrings.noClassesAssigned,
        body: AppStrings.noClassesAssignedBody,
      );
    }

    final currentSession = _currentSession(classes);
    final totalChildren = classes.fold<int>(
      0,
      (sum, item) => sum + item.activeChildren,
    );

    final lastSaturday = InfoRow(
      label: AppStrings.lastAttendance,
      value: currentSession == null
          ? AppStrings.noAttendanceYet
          : AppDateUtils.formatDayDate(currentSession),
      icon: Icons.event_available_outlined,
    );

    return AsyncSection<_ServantDashboard>(
      key: _sectionKey,
      load: _load,
      builder: (context, data, reload) {
        // The chart names its own Saturday; with nothing recorded yet the
        // last Saturday gets a small card instead.
        final hasChart = data.weeks.any((w) => w.recorded);
        final lastWeek = WeeklyAttendance.headline(data.weeks);
        // Not a lazy ListView: it rebuilt each section as it scrolled back
        // into view, which replayed its entrance (after a delay) every time.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Same order as the admin home: glance (greeting, numbers), today
              // (birthdays, lesson), then shortcuts and the classes.
              FadeSlideIn(
                index: 0,
                child: _WelcomeBanner(
                  name: session.displayName,
                  yearName: session.currentYear?.name,
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: AppStrings.totalChildren,
                        value: '$totalChildren',
                        icon: Icons.groups_outlined,
                        color: AppColors.olive,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      // A servant has one class, so its count says nothing;
                      // this is how the last finished Saturday went.
                      child: StatCard(
                        label: AppStrings.lastSaturdayRate,
                        value: lastWeek == null
                            ? '—'
                            : '${lastWeek.percentage.round()}%',
                        icon: Icons.how_to_reg_rounded,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 2,
                child: TodayBirthdaysSection(reloadToken: _loads),
              ),
              FadeSlideIn(
                index: 2,
                child: MissingInfoSection(reloadToken: _loads),
              ),
              FadeSlideIn(
                index: 3,
                child: LessonOfDay(
                  date: upcomingSaturday(),
                  reloadToken: _loads,
                ),
              ),
              FadeSlideIn(
                index: 4,
                child: QuickActionGrid(
                  actions: [
                    QuickAction(
                      Icons.fact_check_rounded,
                      AppStrings.attendanceTitle,
                      AppColors.success,
                      () => _push(const AttendanceScreen(showAppBar: true)),
                    ),
                    QuickAction(
                      Icons.assignment_rounded,
                      AppStrings.myActivities,
                      AppColors.navy,
                      () => _push(const MyActivitiesScreen(showAppBar: true)),
                    ),
                    QuickAction(
                      Icons.person_add_alt_1_rounded,
                      AppStrings.addChild,
                      AppColors.olive,
                      () => _push(const ChildFormScreen()),
                    ),
                    // Competitions are for the general servant (and the admin),
                    // not for a servant of a class.
                    if (session.isGeneralServant || session.isAdmin)
                      QuickAction(
                        Icons.emoji_events_rounded,
                        AppStrings.weeklyCompetition,
                        AppColors.gold,
                        () => _push(const CompetitionsScreen()),
                      ),
                    QuickAction(
                      Icons.event_rounded,
                      AppStrings.events,
                      AppColors.coral,
                      () => _push(const EventsScreen()),
                    ),
                    QuickAction(
                      Icons.calendar_month_rounded,
                      AppStrings.calendarTitle,
                      AppColors.sky,
                      () => _push(const CalendarScreen()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (hasChart) ...[
                FadeSlideIn(
                  index: 5,
                  child: WeeklyAttendanceChart(
                    weeks: data.weeks,
                    classNames: {
                      for (final c in classes) c.classId: c.className,
                    },
                    benchmark: data.service,
                    onRecord: (classId, date) => _push(AttendanceScreen(
                      showAppBar: true,
                      initialClassId: classId,
                      initialDate: date,
                    )),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // With nothing recorded yet there is no chart to name the
              // Saturday, so the last one keeps a small card of its own.
              if (!hasChart)
                FadeSlideIn(index: 5, child: SectionCard(child: lastSaturday)),
            ],
          ),
        );
      },
    );
  }

  /// The Saturday being recorded. Every class shares one calendar, so the
  /// latest of them is the one all the servant's classes are on.
  static DateTime? _currentSession(List<ClassOverview> classes) {
    DateTime? latest;
    for (final item in classes) {
      final date = item.lastSessionDate;
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest;
  }
}

/// What the servant home loads in one go.
class _ServantDashboard {
  const _ServantDashboard({
    this.weeks = const <WeeklyAttendance>[],
    this.service = const <DateTime, double>{},
  });

  final List<WeeklyAttendance> weeks;

  /// The whole service's % per Saturday; empty when it could not be read.
  final Map<DateTime, double> service;
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name, this.yearName});

  final String name;
  final String? yearName;

  @override
  Widget build(BuildContext context) {
    return GreetingBanner(name: name, subtitle: yearName);
  }
}
