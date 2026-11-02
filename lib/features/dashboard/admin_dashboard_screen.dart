import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../children/child_form_screen.dart';
import '../children/child_profile_screen.dart';
import '../classes/class_detail_screen.dart';
import '../excel/import_children_screen.dart';
import '../lessons/lesson_widgets.dart';
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

  Future<_AdminDashboard> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;

    final stats = await _reports.adminStats();
    if (yearId == null) {
      return _AdminDashboard(
        stats: stats,
        classScores: const <ClassYearScore>[],
        lowAttendance: const <ChildYearReport>[],
        activity: await _reports.recentActivity(),
        monthly: const <ChildMonthlyReport>[],
      );
    }

    final monthly = await _reports.childMonthly(yearId: yearId);

    return _AdminDashboard(
      stats: stats,
      classScores: await _reports.classScores(yearId),
      lowAttendance: await _reports.lowAttendance(yearId: yearId),
      activity: await _reports.recentActivity(),
      monthly: monthly,
    );
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

    return AsyncSection<_AdminDashboard>(
      key: _sectionKey,
      load: _load,
      builder: (context, data, reload) {
        final stats = data.stats;

        // Max points held so far per class and per child (sessions up to now).
        final now = DateTime.now();
        final classMaxHeld = <String, int>{};
        final childMaxHeld = <String, int>{};
        for (final r in data.monthly) {
          if (r.monthStart.year < now.year ||
              (r.monthStart.year == now.year &&
                  r.monthStart.month <= now.month)) {
            classMaxHeld[r.classId] =
                (classMaxHeld[r.classId] ?? 0) + r.maxPoints;
            childMaxHeld[r.childId] =
                (childMaxHeld[r.childId] ?? 0) + r.maxPoints;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _greeting(session.displayName, session.currentYear?.name),
            const SizedBox(height: 16),
            const TodayBirthdaysSection(),
            LessonOfDay(date: upcomingSaturday()),
            FadeSlideIn(
              index: 1,
              child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: AppStrings.totalChildren,
                    value: '${stats.childrenCount}',
                    icon: Icons.groups_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: AppStrings.totalClasses,
                    value: '${stats.classesCount}',
                    icon: Icons.class_outlined,
                    color: AppColors.olive,
                  ),
                ),
              ],
            ),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              index: 2,
              child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: AppStrings.totalServants,
                    value: '${stats.servantsCount}',
                    icon: Icons.volunteer_activism_outlined,
                    color: AppColors.navyLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: AppStrings.totalPoints,
                    value: '${stats.totalPoints}',
                    icon: Icons.star_outline,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              child: Column(
                children: [
                  InfoRow(
                    label: AppStrings.lastAttendance,
                    value: stats.lastSessionDate == null
                        ? AppStrings.noUpcomingSession
                        : AppDateUtils.formatDayDate(stats.lastSessionDate!),
                    icon: Icons.event_available_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.boys,
                    value: '${stats.boysCount}',
                    icon: Icons.boy,
                  ),
                  InfoRow(
                    label: AppStrings.girls,
                    value: '${stats.girlsCount}',
                    icon: Icons.girl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(index: 3, child: _quickActions()),
            const SizedBox(height: 16),
            if (data.classScores.isNotEmpty) ...[
              SectionCard(
                title: AppStrings.classPerformance,
                icon: Icons.bar_chart_rounded,
                accent: AppColors.olive,
                child: Column(
                  children: data.classScores
                      .map(
                        (score) {
                          final maxHeld =
                              classMaxHeld[score.classId] ?? score.maxPoints;
                          final pct = maxHeld > 0
                              ? score.points / maxHeld * 100
                              : score.percentage;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: InkWell(
                              onTap: () => _push(
                                ClassDetailScreen(classId: score.classId),
                              ),
                              child: PercentageBar(
                                percentage: pct,
                                label: '${score.className} '
                                    '(${score.children} ${AppStrings.childLabel})',
                              ),
                            ),
                          );
                        },
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (data.lowAttendance.isNotEmpty) ...[
              SectionCard(
                title: AppStrings.lowAttendanceChildren,
                icon: Icons.warning_amber_rounded,
                accent: AppColors.coral,
                child: Column(
                  children: data.lowAttendance
                      .map(
                        (report) {
                          final maxHeld =
                              childMaxHeld[report.childId] ?? report.maxPoints;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              report.childName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              report.className,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: ScoreChip(
                              score: report.points,
                              maxScore: maxHeld,
                              compact: true,
                              showMax: false,
                            ),
                            onTap: () => _push(
                              ChildProfileScreen(childId: report.childId),
                            ),
                          );
                        },
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (data.activity.isNotEmpty)
              SectionCard(
                title: AppStrings.recentActivity,
                icon: Icons.history_rounded,
                accent: AppColors.sky,
                child: Column(
                  children: data.activity
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.history,
                                size: 15,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.description,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      AppDateUtils.formatDateTime(
                                        entry.createdAt,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  Widget _greeting(String name, String? yearName) =>
      GreetingBanner(name: name, subtitle: yearName);

  Widget _quickActions() {
    return SectionCard(
      title: AppStrings.quickActions,
      icon: Icons.bolt_rounded,
      accent: AppColors.gold,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ActionChip(
            icon: Icons.fact_check_outlined,
            label: AppStrings.attendanceTitle,
            onTap: () => _push(const AttendanceScreen(showAppBar: true)),
          ),
          _ActionChip(
            icon: Icons.person_add_alt,
            label: AppStrings.addChild,
            onTap: () => _push(const ChildFormScreen()),
          ),
          _ActionChip(
            icon: Icons.upload_file,
            label: AppStrings.importChildren,
            onTap: () => _push(const ImportChildrenScreen()),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.navy),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _AdminDashboard {
  const _AdminDashboard({
    required this.stats,
    required this.classScores,
    required this.lowAttendance,
    required this.activity,
    required this.monthly,
  });

  final AdminStats stats;
  final List<ClassYearScore> classScores;
  final List<ChildYearReport> lowAttendance;
  final List<ActivityLogEntry> activity;
  final List<ChildMonthlyReport> monthly;
}
