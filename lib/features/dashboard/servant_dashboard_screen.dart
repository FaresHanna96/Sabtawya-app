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
import '../classes/class_detail_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../servant_activities/my_activities_screen.dart';
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
                    onPressed: () => _push(const MyActivitiesScreen()),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.navyHeader,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const AppLogo(size: 44),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppStrings.welcome}، $name 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  yearName ?? AppStrings.appSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
