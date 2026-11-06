import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../children/child_form_screen.dart';
import '../children/follow_up_section.dart';
import '../classes/class_detail_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../servant_activities/my_activities_screen.dart';
import '../calendar/calendar_screen.dart';
import '../lessons/lesson_widgets.dart';
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
  List<ChildStreak> _streaks = const [];

  Future<List<ClassYearScore>> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return <ClassYearScore>[];
    // A hint only: if it cannot load, the home screen still works.
    try {
      _streaks = await _reports.streaks(yearId: yearId, minPresent: 1000);
    } catch (_) {
      _streaks = const [];
    }
    return _reports.classScores(yearId);
  }

  Future<void> _reload() => _sectionKey.currentState?.reload() ?? Future.value();

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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _WelcomeBanner(
              name: session.displayName,
              yearName: session.currentYear?.name,
            ),
            const SizedBox(height: 16),
            const TodayBirthdaysSection(),
            FollowUpSection(
              streaks: _streaks,
              showClass: classes.length > 1,
              onReturn: _reload,
            ),
            LessonOfDay(date: upcomingSaturday()),
            StatCard(
              label: AppStrings.totalChildren,
              value: '$totalChildren',
              icon: Icons.groups_outlined,
              color: AppColors.olive,
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: InfoRow(
                label: AppStrings.lastAttendance,
                value: currentSession == null
                    ? AppStrings.noUpcomingSession
                    : AppDateUtils.formatDayDate(currentSession),
                icon: Icons.event_available_outlined,
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.quickActions,
              icon: Icons.bolt_rounded,
              accent: AppColors.gold,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ActionChip(
                    avatar: const Icon(
                      Icons.fact_check_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    label: const Text(AppStrings.attendanceTitle),
                    onPressed: () =>
                        _push(const AttendanceScreen(showAppBar: true)),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    label: const Text(AppStrings.calendarTitle),
                    onPressed: () => _push(const CalendarScreen()),
                  ),
                  // A servant with no class has nowhere to add a child.
                  if (session.myClasses.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(
                        Icons.person_add_alt,
                        size: 16,
                        color: AppColors.navy,
                      ),
                      label: const Text(AppStrings.addChild),
                      onPressed: () => _push(const ChildFormScreen()),
                    ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.assignment_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    label: const Text(AppStrings.myActivities),
                    onPressed: () => _push(const MyActivitiesScreen(showAppBar: true)),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.emoji_events_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    label: const Text(AppStrings.weeklyCompetition),
                    onPressed: () => _push(const CompetitionsScreen()),
                  ),
                  ActionChip(
                    avatar: const Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: AppColors.navy,
                    ),
                    label: const Text(AppStrings.events),
                    onPressed: () => _push(const EventsScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.myClasses,
              icon: Icons.menu_book_rounded,
              accent: AppColors.olive,
              child: Column(
                children: classes
                    .map(
                      (item) => _ClassRow(
                        overview: item,
                        score: _scoreOf(scores, item.classId),
                        onTap: () =>
                            _push(ClassDetailScreen(classId: item.classId)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
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
                const Icon(Icons.chevron_left, color: AppColors.muted, size: 20),
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
