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
import '../calendar/calendar_screen.dart';
import '../lessons/lesson_widgets.dart';
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

  /// "عرض الكل" on the low-attendance list and the activity feed.
  bool _showAllLow = false;
  bool _showAllActivity = false;

  Future<_AdminDashboard> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;

    // The five reads do not depend on each other, so run them side by side
    // instead of one after another (the dashboard waited for all five in turn).
    if (yearId == null) {
      final (stats, activity) =
          await (_reports.adminStats(), _reports.recentActivity()).wait;
      return _AdminDashboard(
        stats: stats,
        classScores: const <ClassYearScore>[],
        lowAttendance: const <ChildYearReport>[],
        activity: activity,
      );
    }

    // The class scores already count only the Saturdays held so far, so the
    // monthly table (thousands of rows) is no longer downloaded here.
    final (stats, activity, scores, low, weeks) = await (
      _reports.adminStats(),
      _reports.recentActivity(),
      _reports.classScores(yearId),
      _reports.lowAttendance(yearId: yearId),
      _reports.weeklyAttendance(yearId),
    ).wait;

    return _AdminDashboard(
      stats: stats,
      classScores: scores,
      lowAttendance: low,
      activity: activity,
      weeks: weeks,
    );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Glance first (greeting, the four numbers), then today
              // (birthdays, the lesson), then what to do and the details.
              FadeSlideIn(
                index: 0,
                child:
                    _greeting(session.displayName, session.currentYear?.name),
              ),
              const SizedBox(height: 16),
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
              const FadeSlideIn(index: 3, child: TodayBirthdaysSection()),
              FadeSlideIn(
                index: 4,
                child: LessonOfDay(date: upcomingSaturday()),
              ),
              FadeSlideIn(index: 5, child: _quickActions()),
              const SizedBox(height: 16),
              FadeSlideIn(index: 6, child: _overview(stats)),
              if (data.weeks.length >= 2) ...[
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 7,
                  child: WeeklyAttendanceChart(weeks: data.weeks),
                ),
              ],
              const SizedBox(height: 16),
              if (data.classScores.isNotEmpty) ...[
                FadeSlideIn(
                  index: 7,
                  child: SectionCard(
                    title: AppStrings.classPerformance,
                    icon: Icons.bar_chart_rounded,
                    accent: AppColors.olive,
                    child: Column(
                      children: [
                        for (final (i, score)
                            in _ranked(data.classScores).indexed)
                          _classRow(i, score),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (data.lowAttendance.isNotEmpty) ...[
                FadeSlideIn(
                  index: 8,
                  child: _lowAttendance(data.lowAttendance),
                ),
                const SizedBox(height: 16),
              ],
              if (data.activity.isNotEmpty)
                FadeSlideIn(index: 8, child: _activity(data.activity)),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- sections

  /// Last Saturday taken, and boys vs girls as one split bar.
  Widget _overview(AdminStats stats) {
    final total = stats.boysCount + stats.girlsCount;
    final boysShare = total == 0 ? 0.5 : stats.boysCount / total;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            label: AppStrings.lastAttendance,
            value: stats.lastSessionDate == null
                ? AppStrings.noUpcomingSession
                : AppDateUtils.formatDayDate(stats.lastSessionDate!),
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.boy_rounded, size: 18, color: AppColors.sky),
              Text(
                ' ${AppStrings.boys} ${stats.boysCount}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sky,
                ),
              ),
              const Spacer(),
              Text(
                '${stats.girlsCount} ${AppStrings.girls} ',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.coral,
                ),
              ),
              const Icon(Icons.girl_rounded, size: 18, color: AppColors.coral),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: boysShare),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, share, __) => SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (share * 1000).round().clamp(1, 999),
                      child: Container(color: AppColors.sky),
                    ),
                    Expanded(
                      flex: ((1 - share) * 1000).round().clamp(1, 999),
                      child: Container(color: AppColors.coral),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Classes best first by the percentage actually shown (points over the
  /// Saturdays held so far), so the rank badge matches the bar.
  List<ClassYearScore> _ranked(List<ClassYearScore> scores) {
    double pct(ClassYearScore s) =>
        s.maxPoints > 0 ? s.points / s.maxPoints * 100 : s.percentage;

    return [...scores]..sort((a, b) => pct(b).compareTo(pct(a)));
  }

  /// One class in the ranking: its place, the bar, and an arrow to open it.
  Widget _classRow(int i, ClassYearScore score) {
    final maxHeld = score.maxPoints;
    final pct = maxHeld > 0 ? score.points / maxHeld * 100 : score.percentage;
    final medal = switch (i) {
      0 => AppColors.warning,
      1 => AppColors.navyLight,
      2 => AppColors.olive,
      _ => AppColors.muted,
    };
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _push(ClassDetailScreen(classId: score.classId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: medal.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: medal,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PercentageBar(
                percentage: pct,
                label: '${score.className} '
                    '(${score.children} ${AppStrings.childLabel})',
              ),
            ),
            const SizedBox(width: 4),
            const Icon(AppIcons.forward, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  /// Lowest attenders: the first five, the rest behind "عرض الكل".
  Widget _lowAttendance(List<ChildYearReport> all) {
    final shown = _showAllLow ? all : all.take(5).toList();
    return SectionCard(
      title: '${AppStrings.lowAttendanceChildren} (${all.length})',
      icon: Icons.warning_amber_rounded,
      accent: AppColors.coral,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final report in shown)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _push(ChildProfileScreen(childId: report.childId)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            AppColors.coral.withValues(alpha: 0.14),
                        child: Text(
                          report.childName.isEmpty
                              ? '?'
                              : report.childName.characters.first,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.childName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              report.className,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Saturdays at Sunday school out of those held, e.g. 2/7.
                      ScoreChip(
                        score: report.points,
                        maxScore: report.maxPoints,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            if (all.length > 5)
              TextButton(
                onPressed: () => setState(() => _showAllLow = !_showAllLow),
                child: Text(
                  _showAllLow ? AppStrings.showLess : AppStrings.showAll,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Recent activity as a small timeline: an icon per kind of change and how
  /// long ago it happened. Five at first, the rest behind "عرض الكل".
  Widget _activity(List<ActivityLogEntry> all) {
    final shown = _showAllActivity ? all : all.take(5).toList();
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
            if (all.length > 5)
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
                    _ago(entry.createdAt),
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

  /// "منذ 5 دقائق" / "منذ ساعتين" today, the day-level wording after that.
  String _ago(DateTime at) {
    final diff = DateTime.now().difference(at.toLocal());
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return m == 1
          ? 'منذ دقيقة'
          : m == 2
              ? 'منذ دقيقتين'
              : 'منذ $m دقيقة';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return h == 1
          ? 'منذ ساعة'
          : h == 2
              ? 'منذ ساعتين'
              : 'منذ $h ساعات';
    }
    return '${AppDateUtils.sinceLabel(at)} • ${AppDateUtils.formatDateTime(at)}';
  }

  Widget _greeting(String name, String? yearName) =>
      GreetingBanner(name: name, subtitle: yearName);

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
    required this.classScores,
    required this.lowAttendance,
    required this.activity,
    this.weeks = const <WeeklyAttendance>[],
  });

  final AdminStats stats;
  final List<ClassYearScore> classScores;
  final List<ChildYearReport> lowAttendance;
  final List<ActivityLogEntry> activity;

  /// Attendance per Saturday, for the weekly chart.
  final List<WeeklyAttendance> weeks;
}
