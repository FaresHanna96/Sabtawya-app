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
import '../../data/models/school_class.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../children/child_form_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../calendar/calendar_screen.dart';
import 'home_status_card.dart';
import 'needs_attention_strip.dart';
import 'next_saturday_prep_card.dart';
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
        // Not a lazy ListView: it rebuilt each section as it scrolled back
        // into view, which replayed its entrance (after a delay) every time.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          // One column on a phone; beside each other on a wide window (the
          // chart next to the rest), as on the admin home.
          child: TwoColumns(
            main: [
              // Same shape as the admin home: the week at a glance, what needs
              // doing, the Saturday ahead, then the shortcuts.
              FadeSlideIn(
                index: 0,
                child: HomeStatusCard(
                  name: session.displayName,
                  yearName: session.currentYear?.name,
                  onRecord: data.weeks.isNotEmpty && data.weeks.last.inProgress
                      ? () => _push(AttendanceScreen(
                            showAppBar: true,
                            initialDate: data.weeks.last.date,
                          ))
                      : null,
                  totals: servantHomeTotals(classes),
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
                ),
              ),
              FadeSlideIn(
                index: 4,
                child: QuickActionGrid(
                  compact: true,
                  actions: [
                    // Attendance and «تحضيراتي» are bottom tabs already.
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
            ],
            side: [
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

/// The totals under the status card for a servant: their children with the
/// boys/girls split, then, for one class, which class it is («فصلك» and its
/// name: the home never said), or for several (a general servant) how many
/// classes and how many servants share them. A cell with nothing to say is
/// left out.
@visibleForTesting
List<HomeTotal> servantHomeTotals(List<ClassOverview> classes) {
  final children = classes.fold<int>(0, (a, c) => a + c.activeChildren);
  final boys = classes.fold<int>(0, (a, c) => a + c.boysCount);
  final girls = classes.fold<int>(0, (a, c) => a + c.girlsCount);
  final servants = classes.fold<int>(0, (a, c) => a + c.servantsCount);
  return [
    HomeTotal(
      value: children,
      label: AppStrings.totalChildren,
      icon: Icons.groups_rounded,
      sub: boys + girls == 0
          ? null
          : [
              if (boys > 0) '$boys ${AppStrings.boys}',
              if (girls > 0) '$girls ${AppStrings.girls}',
            ].join(' • '),
    ),
    if (classes.length == 1)
      HomeTotal(
        text: classes.first.className,
        label: AppStrings.yourClass,
        icon: Icons.class_rounded,
      ),
    if (classes.length > 1) ...[
      HomeTotal(
        value: classes.length,
        label: AppStrings.totalClasses,
        icon: Icons.class_rounded,
      ),
      if (servants > 0)
        HomeTotal(
          value: servants,
          label: AppStrings.totalServants,
          icon: Icons.supervisor_account_rounded,
        ),
    ],
  ];
}
