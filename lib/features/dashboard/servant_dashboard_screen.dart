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
import '../classes/class_detail_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../servant_activities/my_activities_screen.dart';
import '../calendar/calendar_screen.dart';
import '../lessons/lesson_widgets.dart';
import 'quick_action_grid.dart';
import 'today_birthdays_section.dart';

/// The servant landing page. It shows only the assigned classes, which is a
/// consequence of row level security rather than of filtering done here.
class ServantDashboardScreen extends StatefulWidget {
  const ServantDashboardScreen({super.key});

  @override
  State<ServantDashboardScreen> createState() => _ServantDashboardScreenState();
}

class _ServantDashboardScreenState extends State<ServantDashboardScreen> {
  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<ClassYearScore>>>();

  Future<List<ClassYearScore>> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return <ClassYearScore>[];
    return _reports.classScores(yearId);
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

    return AsyncSection<List<ClassYearScore>>(
      key: _sectionKey,
      load: _load,
      builder: (context, scores, reload) {
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
                      child: StatCard(
                        label: AppStrings.myClasses,
                        value: '${classes.length}',
                        icon: Icons.menu_book_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const FadeSlideIn(index: 2, child: TodayBirthdaysSection()),
              FadeSlideIn(
                index: 3,
                child: LessonOfDay(date: upcomingSaturday()),
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
              FadeSlideIn(
                index: 5,
                child: SectionCard(
                  title: AppStrings.myClasses,
                  icon: Icons.menu_book_rounded,
                  accent: AppColors.olive,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoRow(
                        label: AppStrings.lastAttendance,
                        value: currentSession == null
                            ? AppStrings.noUpcomingSession
                            : AppDateUtils.formatDayDate(currentSession),
                        icon: Icons.event_available_outlined,
                      ),
                      const Divider(height: 16),
                      for (final item in classes)
                        _ClassRow(
                          overview: item,
                          score: _scoreOf(scores, item.classId),
                          onTap: () =>
                              _push(ClassDetailScreen(classId: item.classId)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static ClassYearScore? _scoreOf(List<ClassYearScore> scores, String classId) {
    for (final score in scores) {
      if (score.classId == classId) return score;
    }
    return null;
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

class _ClassRow extends StatelessWidget {
  const _ClassRow({
    required this.overview,
    required this.score,
    required this.onTap,
  });

  final ClassOverview overview;
  final ClassYearScore? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    overview.className,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${overview.activeChildren} ${AppStrings.childrenTitle}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const Icon(AppIcons.forward, color: AppColors.muted, size: 20),
              ],
            ),
            if (score != null) ...[
              const SizedBox(height: 8),
              PercentageBar(percentage: score!.percentage),
            ],
          ],
        ),
      ),
    );
  }
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
