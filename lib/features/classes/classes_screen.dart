import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/class_colors.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/class_health.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../dashboard/class_health_section.dart';
import '../dashboard/weekly_attendance_chart.dart';
import 'class_detail_screen.dart';
import 'class_health_tab.dart';
import 'class_form_screen.dart';
import 'patron_avatar.dart';

export '../../core/theme/class_colors.dart' show classColourIndex;

/// The class list. An admin sees every class including archived ones; a servant
/// sees only the classes assigned to them, which the policies enforce. A
/// servant with a single class sees that class's page here instead of a list.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  /// The class to show directly: a servant's one and only class. Null for
  /// an admin or general servant (every class) and for two or more classes.
  static ClassOverview? onlyClass({
    required bool everyClass,
    required List<ClassOverview> mine,
  }) =>
      !everyClass && mine.length == 1 ? mine.single : null;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen>
    with SingleTickerProviderStateMixin {
  static const _repository = ClassRepository();

  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ClassesData>>();

  /// The list, and متابعة الفصول (moved here from the home page).
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      // The add button belongs to the list only.
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });

  bool _includeArchived = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The classes, then for each what its card says beyond the counts: this
  /// Saturday's attendance, the health score, and (the admin) whether a prep
  /// was sent. Those parts are best effort: one that fails just leaves its
  /// line off the cards.
  Future<_ClassesData> _load() async {
    final session = context.read<SessionController>();
    final yearId = session.currentYear?.id;
    final isAdmin = session.isAdmin;
    final saturday = AppDateUtils.lastSaturday(DateTime.now());
    final (classes, weeks, health, preps, breaks) = await (
      _repository.overview(includeInactive: _includeArchived),
      yearId == null
          ? Future.value(const <String, ClassWeek>{})
          : _reports
              .classWeekOn(yearId: yearId, date: saturday)
              .catchError((Object _) => const <String, ClassWeek>{}),
      yearId == null
          ? Future.value(const <ClassHealth>[])
          : _loadHealth(yearId).catchError((Object _) => const <ClassHealth>[]),
      // Preps are visible to the admin only (and to their own servant).
      isAdmin
          ? const ServantActivityRepository()
              .classesWithPrepOn(saturday)
              .then<Set<String>?>((s) => s)
              .catchError((Object _) => null)
          : Future<Set<String>?>.value(null),
      const LessonRepository()
          .breaks()
          .catchError((Object _) => const <String, LessonBreak>{}),
    ).wait;
    return _ClassesData(
      classes: classes,
      saturday: saturday,
      facts: classCardFacts(
        weeks: weeks,
        health: health,
        prepClasses: preps,
        noLesson: breaks.containsKey(AppDateUtils.toIsoDate(saturday)),
      ),
    );
  }

  /// The same score as متابعة الفصول: the health rows with the year's
  /// attendance % joined in.
  static Future<List<ClassHealth>> _loadHealth(String yearId) async {
    final (health, scores) = await (
      _reports.classHealth(yearId),
      _reports.classScores(yearId),
    ).wait;
    return ClassHealth.joinAttendance(health, {
      for (final s in scores) s.classId: s.percentage,
    });
  }

  /// This class's attendance for [date], then back to the list.
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
  }

  Future<void> _reload() async {
    await _sectionKey.currentState?.reload();
    if (mounted) await context.read<SessionController>().refreshClasses();
  }

  /// Reloads on the way back only when something was saved meanwhile (every
  /// save marks the data changed), so just looking at a class costs nothing.
  Future<void> _open(ClassOverview overview) async {
    final session = context.read<SessionController>();
    final before = session.dataVersion;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClassDetailScreen(classId: overview.classId),
      ),
    );
    if (mounted && session.dataVersion != before) await _reload();
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ClassFormScreen()),
    );
    if (added == true) await _reload();
  }

  void _toggleArchived(bool value) {
    setState(() => _includeArchived = value);
    _sectionKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final isGeneralServant = session.isGeneralServant;
    final everyClass = isAdmin || isGeneralServant;

    final tabBar = TabBar(
      controller: _tabs,
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      tabs: [
        Tab(
          text: everyClass ? AppStrings.classesTitle : AppStrings.myClasses,
        ),
        Tab(
          text: everyClass
              ? AppStrings.classHealthTitle
              : AppStrings.myClassHealthTitle,
        ),
      ],
    );

    // A servant with one class gets that class itself: a list holding one
    // card would only be a tap in the way.
    final onlyClass = ClassesScreen.onlyClass(
      everyClass: everyClass,
      mine: session.myClasses,
    );

    final list = _buildList(isAdmin, isGeneralServant);

    // Archived classes: an icon on the tab strip, not a row of its own.
    final archiveToggle = IconButton(
      tooltip: AppStrings.showInactive,
      isSelected: _includeArchived,
      icon: const Icon(Icons.inventory_2_outlined),
      selectedIcon: const Icon(Icons.inventory_2),
      onPressed: () => _toggleArchived(!_includeArchived),
    );

    // Each page keeps its state (and its loaded data) while the other shows.
    final pages = TabBarView(
      controller: _tabs,
      children: [
        _KeepAlive(
          child: onlyClass == null
              ? list
              : ClassDetailScreen(
                  key: ValueKey(onlyClass.classId),
                  classId: onlyClass.classId,
                  embedded: true,
                ),
        ),
        const _KeepAlive(child: ClassHealthTab()),
      ],
    );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                  everyClass ? AppStrings.classesTitle : AppStrings.myClasses),
              actions: [
                if (isAdmin && _tabs.index == 0) archiveToggle,
              ],
              bottom: tabBar,
            )
          : null,
      body: SafeArea(
        child: widget.showAppBar
            ? pages
            : Column(
                children: [
                  Material(
                    color: Theme.of(context).appBarTheme.backgroundColor ??
                        Theme.of(context).colorScheme.primary,
                    child: Row(
                      children: [
                        Expanded(child: tabBar),
                        if (isAdmin && _tabs.index == 0)
                          IconTheme(
                            data: const IconThemeData(color: Colors.white),
                            child: archiveToggle,
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: pages),
                ],
              ),
      ),
      floatingActionButton: isAdmin && _tabs.index == 0
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addClass),
            )
          : null,
    );
  }

  Widget _buildList(bool isAdmin, bool isGeneralServant) {
    return AsyncSection<_ClassesData>(
      loading: const SkeletonList(),
      key: _sectionKey,
      load: _load,
      builder: (context, data, reload) {
        final classes = data.classes;
        if (classes.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.class_outlined,
                title: (isAdmin || isGeneralServant)
                    ? AppStrings.noClasses
                    : AppStrings.noClassesAssigned,
                body: (isAdmin || isGeneralServant)
                    ? null
                    : AppStrings.noClassesAssignedBody,
                action: isAdmin
                    ? FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text(AppStrings.addClass),
                      )
                    : null,
              ),
            ],
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isAdmin ? 96 : 24),
          itemCount: classes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: ClassCard(
              overview: classes[index],
              accent: classAccent(classes[index].classId),
              saturday: data.saturday,
              facts:
                  data.facts[classes[index].classId] ?? const ClassCardFacts(),
              onRecord: () => _record(classes[index].classId, data.saturday),
              onTap: () => _open(classes[index]),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps a sub-tab's page alive while the other one is on screen.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The list, the Saturday the cards are about, and what each card says
/// beyond the counts (class id -> facts).
class _ClassesData {
  const _ClassesData({
    required this.classes,
    required this.saturday,
    required this.facts,
  });

  final List<ClassOverview> classes;
  final DateTime saturday;
  final Map<String, ClassCardFacts> facts;
}

/// What one class card shows beyond the class's own counts. Every part may
/// be unknown (null): its line is then left off the card.
class ClassCardFacts {
  const ClassCardFacts({this.week, this.score, this.level, this.prepSent});

  /// This Saturday's session; null when the class did not meet then.
  final ClassWeek? week;

  /// The health score (0-100) and its colour, as in متابعة الفصول.
  final int? score;
  final HealthLevel? level;

  /// A lesson prep was sent for this Saturday; null when not known (not the
  /// admin, a day with no lesson, or the class did not meet).
  final bool? prepSent;
}

/// Puts the loaded parts together per class. [prepClasses] null means the
/// preps could not be read (or are not the caller's to read); [noLesson]
/// marks a Saturday with no lesson, when no prep is expected.
@visibleForTesting
Map<String, ClassCardFacts> classCardFacts({
  required Map<String, ClassWeek> weeks,
  required List<ClassHealth> health,
  required Set<String>? prepClasses,
  required bool noLesson,
}) {
  final byHealth = {for (final h in health) h.classId: h};
  final ids = {...weeks.keys, ...byHealth.keys};
  return {
    for (final id in ids)
      id: ClassCardFacts(
        week: weeks[id],
        score: byHealth[id]?.score,
        level: byHealth[id]?.level,
        prepSent: prepClasses == null || noLesson || weeks[id] == null
            ? null
            : prepClasses.contains(id),
      ),
  };
}

/// One class: who it is, how many children and servants, its health, and
/// how this Saturday went (attendance taken, who came, prep sent).
@visibleForTesting
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.overview,
    required this.accent,
    required this.saturday,
    required this.facts,
    required this.onRecord,
    required this.onTap,
  });

  final Color accent;
  final ClassOverview overview;
  final DateTime saturday;
  final ClassCardFacts facts;
  final VoidCallback onRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final week = facts.week;
    // Boys and girls only say something in a mixed class.
    final mixed = overview.boysCount > 0 && overview.girlsCount > 0;
    final noServant = overview.isActive && overview.servantsCount == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      PatronAvatar(
                          photoPath: overview.patronPhotoPath, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              overview.className,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (overview.patronName != null)
                              Text(
                                overview.patronName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.maroon,
                                ),
                              ),
                            // Under the name, where the words have room.
                            if (overview.isActive &&
                                facts.score != null &&
                                facts.level != null) ...[
                              const SizedBox(height: 6),
                              HealthScoreChip(
                                score: facts.score!,
                                level: facts.level!,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!overview.isActive)
                        const StatusBadge(isActive: false),
                      const Icon(AppIcons.forward, color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Pill(
                        icon: Icons.groups_outlined,
                        value: '${overview.activeChildren}',
                        label: AppStrings.pillChildren,
                      ),
                      if (mixed) ...[
                        _Pill(
                          icon: Icons.boy,
                          value: '${overview.boysCount}',
                          label: AppStrings.boys,
                          color: AppColors.navyLight,
                        ),
                        _Pill(
                          icon: Icons.girl,
                          value: '${overview.girlsCount}',
                          label: AppStrings.girls,
                          color: AppColors.olive,
                        ),
                      ],
                      if (noServant)
                        const Expanded(child: _NeedsServant())
                      else
                        _Pill(
                          icon: Icons.volunteer_activism_outlined,
                          value: '${overview.servantsCount}',
                          label: AppStrings.pillServants,
                        ),
                    ],
                  ),
                  if (week != null && overview.isActive) ...[
                    const SizedBox(height: 10),
                    ClassSaturdayStatus(
                      recorded: week.recorded,
                      day: '${saturday.day} '
                          '${AppDateUtils.monthName(saturday.month)}',
                      present: week.present,
                      children: week.children,
                      onRecord: onRecord,
                    ),
                    if (facts.prepSent != null) ...[
                      const SizedBox(height: 6),
                      _PrepLine(sent: facts.prepSent!),
                    ],
                  ] else if (overview.lastSessionDate != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${AppStrings.lastAttendance}: '
                          '${AppDateUtils.formatDate(overview.lastSessionDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "● 78 صحة" in the colour of the class's health level.
@visibleForTesting
class HealthScoreChip extends StatelessWidget {
  const HealthScoreChip({super.key, required this.score, required this.level});

  final int score;
  final HealthLevel level;

  /// A face for each level, so the colour is not the only signal.
  static IconData iconOf(HealthLevel level) => switch (level) {
        HealthLevel.green => Icons.sentiment_satisfied_alt_rounded,
        HealthLevel.amber => Icons.visibility_outlined,
        HealthLevel.red => Icons.volunteer_activism_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final color = ClassHealthSection.colorOf(level);
    // In words first («محتاجين دعم»), as متابعة الفصول says it; the score
    // out of 100 stays beside it, smaller, for whoever wants the number.
    final label = ClassHealthSection.labelOf(level);
    return Tooltip(
      message: AppStrings.healthChipTooltip(score),
      child: Semantics(
        label: '${AppStrings.healthShort}: $label، $score/100',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 10, 3),
          decoration: BoxDecoration(
            color: statusTint(color),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconOf(level), size: 15, color: color),
              const SizedBox(width: 5),
              // Shrinks a little rather than overflow next to a long name.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$score/100',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// In place of the servants count when a class has none.
class _NeedsServant extends StatelessWidget {
  const _NeedsServant();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.person_off_outlined, size: 16, color: AppColors.danger),
        SizedBox(width: 4),
        Flexible(
          child: Text(
            AppStrings.classNeedsServant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    );
  }
}

/// "التحضير اتبعت" / "لم يُرسل تحضير" for this Saturday.
class _PrepLine extends StatelessWidget {
  const _PrepLine({required this.sent});

  final bool sent;

  @override
  Widget build(BuildContext context) {
    final color = sent ? AppColors.success : AppColors.muted;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 10),
      child: Row(
        children: [
          Icon(
            sent ? Icons.menu_book_rounded : Icons.menu_book_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            sent ? AppStrings.prepSentLine : AppStrings.prepNotSent,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: sent ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// "اتسجّل حضور 21 نوفمبر" with who came ("حضر 8 من 10", 80%), or
/// "لم يُسجَّل بعد" with a button to do it.
@visibleForTesting
class ClassSaturdayStatus extends StatelessWidget {
  const ClassSaturdayStatus({
    super.key,
    required this.recorded,
    required this.day,
    required this.onRecord,
    this.present,
    this.children,
  });

  final bool recorded;
  final String day;
  final VoidCallback onRecord;

  /// Who came out of the class's active children; shown once recorded.
  final int? present;
  final int? children;

  @override
  Widget build(BuildContext context) {
    final color = recorded ? AppColors.success : AppColors.warning;
    final total = children ?? 0;
    if (recorded && present != null && total > 0) {
      final pct = present! / total * 100;
      final level = WeeklyAttendanceChart.levelColor(pct);
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.classRecordedOn(day),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // "8/10 • 80%": who came out of the class, then the share.
                Text(
                  '$present/$total',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${pct.round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: level,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(level),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            recorded
                ? Icons.check_circle_rounded
                : Icons.pending_actions_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recorded
                  ? AppStrings.classRecordedOn(day)
                  : AppStrings.classNotRecordedOn(day),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (!recorded)
            TextButton(
              onPressed: onRecord,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                minimumSize: const Size(0, 40),
              ),
              child: const Text(AppStrings.recordNow),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final String value;

  /// Says what the number counts; an icon alone was not enough to tell.
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
