import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../messages/parent_messages_screen.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_history_screen.dart';
import '../attendance/attendance_screen.dart';
import '../badges/class_champions.dart';
import '../children/absence_followup_screen.dart';
import '../children/birthday_screen.dart';
import '../children/child_contact_sheet.dart';
import '../children/child_filters.dart';
import '../children/missing_info.dart';
import '../children/missing_info_screen.dart';
import '../children/child_form_screen.dart';
import '../children/child_profile_screen.dart';
import '../children/child_tile.dart';
import '../children/contacts_export_screen.dart';
import '../servants/servant_assignments_screen.dart' show addServantToClass;
import 'class_follow_up_strip.dart';
import 'class_form_screen.dart';
import 'class_saturday_status.dart';
import 'class_servants_card.dart';
import 'patron_avatar.dart';

/// Everything about one class: its counters, its servants, and its children
/// with the same filtering as the main directory.
class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.classId,
    this.embedded = false,
  });

  final String classId;

  /// Shown inside the Classes tab (a servant with one class) rather than
  /// pushed: no app bar of its own, the name and menu head the page instead.
  final bool embedded;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  static const _classes = ClassRepository();
  static const _children = ChildRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ClassDetail>>();
  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  /// Whether the page is scrolled far enough to offer «للأعلى».
  final _showTop = ValueNotifier<bool>(false);

  ChildFilter _filter = const ChildFilter();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final far = _scroll.hasClients && _scroll.offset > 600;
      if (far != _showTop.value) _showTop.value = far;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _showTop.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Five independent reads, side by side.
  Future<_ClassDetail> _load() async {
    final (overview, servants, children, streaks, week, points) = await (
      _classes.overviewById(widget.classId),
      _classes.servantsOfClass(widget.classId),
      _children.byClass(widget.classId, includeInactive: true),
      _loadStreaks(),
      _loadWeek(),
      _loadPoints(),
    ).wait;
    if (overview == null) {
      throw AppFailure(AppStrings.noPermission);
    }
    return _ClassDetail(
      overview: overview,
      servants: servants,
      children: children,
      streaks: streaks,
      week: week,
      points: points,
    );
  }

  /// Each child's game points, to order the champions with equal runs; a
  /// hint, empty on failure.
  Future<Map<String, int>> _loadPoints() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const <String, int>{};
    return pointsOfClass(yearId, widget.classId);
  }

  /// This Saturday's attendance for the class: a hint, null when unknown, and
  /// also null on a Saturday with no lesson (nothing to record then).
  Future<_Week?> _loadWeek() async {
    try {
      final yearId = context.read<SessionController>().currentYear?.id;
      if (yearId == null) return null;
      final saturday = AppDateUtils.lastSaturday(DateTime.now());
      final (weeks, breaks) = await (
        const ReportRepository().classWeekOn(yearId: yearId, date: saturday),
        const LessonRepository().breaks(),
      ).wait;
      if (breaks.containsKey(AppDateUtils.toIsoDate(saturday))) return null;
      final week = weeks[widget.classId];
      return week == null ? null : _Week(saturday, week);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openChampions(ClassOverview overview) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ClassChampionsScreen(
            classId: overview.classId,
            className: overview.className,
          ),
        ),
      );

  /// The runs are a hint on top of the page: a failure leaves them out rather
  /// than breaking the class screen.
  Future<Map<String, ChildStreak>> _loadStreaks() async {
    try {
      final yearId = context.read<SessionController>().currentYear?.id;
      if (yearId == null) return const {};
      final list = await const ReportRepository()
          .streaks(yearId: yearId, classId: widget.classId);
      return {for (final s in list) s.childId: s};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _addChild() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChildFormScreen(initialClassId: widget.classId),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _openChild(Child child) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChildProfileScreen(childId: child.id),
      ),
    );
    await _reload();
  }

  Future<void> _takeAttendance() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(
          showAppBar: true,
          initialClassId: widget.classId,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceHistoryScreen(initialClassId: widget.classId),
      ),
    );
    await _reload();
  }

  Future<void> _edit(SchoolClass current) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClassFormScreen(existing: current),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _toggleArchive(ClassOverview overview) async {
    final archiving = overview.isActive;
    final confirmed = await Ui.confirm(
      context,
      title: archiving ? AppStrings.archiveClass : AppStrings.restoreClass,
      message: archiving ? AppStrings.confirmArchiveClass : null,
      destructive: archiving,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _classes.setActive(overview.classId, !archiving),
      successMessage: AppStrings.saved,
    );
    if (!ok || !mounted) return;

    await context.read<SessionController>().refreshClasses();
    await _reload();
  }

  Future<void> _delete(ClassOverview overview) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.deleteClass,
      message: AppStrings.confirmDeleteClass,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _classes.delete(overview.classId);
    } catch (e) {
      if (!mounted) return;
      // The restrict constraint is the expected outcome for a class that still
      // has children, so it gets an instruction rather than a raw error.
      final isInUse = e is AppFailure && e.code == '23503';
      Ui.info(
        context,
        isInUse ? AppStrings.classHasChildren : '$e',
      );
      return;
    }

    if (!mounted) return;
    await context.read<SessionController>().refreshClasses();
    if (!mounted) return;
    Ui.success(context, AppStrings.classDeleted);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final isGeneralServant = session.isGeneralServant;

    return Scaffold(
      // A long class: one tap back to the top.
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showTop,
        builder: (_, show, __) => AnimatedScale(
          scale: show ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: FloatingActionButton.small(
            heroTag: 'class-top-${widget.classId}',
            tooltip: AppStrings.backToTop,
            onPressed: show
                ? () => _scroll.animateTo(0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic)
                : null,
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ),
      ),
      body: AsyncSection<_ClassDetail>(
        key: _sectionKey,
        load: _load,
        builder: (context, data, reload) {
          final overview = data.overview;
          final visible = _filter.apply(data.children);
          final totalVisible = data.children
              .where((child) => _filter.includeInactive || child.isActive)
              .length;

          // أمين الخدمة manages the class; a servant of this class can edit it
          // (the database allows exactly that) but not archive or delete it.
          final canManage = isAdmin ||
              session.myClasses.any((c) => c.classId == overview.classId);
          final Widget? menu = !canManage
              ? null
              : PopupMenuButton<_ClassAction>(
                  iconColor: widget.embedded ? Colors.white : null,
                  onSelected: (action) => switch (action) {
                    _ClassAction.edit => _edit(overview.asClass),
                    _ClassAction.archive => _toggleArchive(overview),
                    _ClassAction.delete => _delete(overview),
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<_ClassAction>(
                      value: _ClassAction.edit,
                      child: Text(AppStrings.editClass),
                    ),
                    if (isAdmin)
                      PopupMenuItem<_ClassAction>(
                        value: _ClassAction.archive,
                        child: Text(
                          overview.isActive
                              ? AppStrings.archiveClass
                              : AppStrings.restoreClass,
                        ),
                      ),
                    if (isAdmin)
                      const PopupMenuItem<_ClassAction>(
                        value: _ClassAction.delete,
                        child: Text(
                          AppStrings.deleteClass,
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                  ],
                );

          // Pull down to reload; the old page stays on screen meanwhile.
          return RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (!widget.embedded)
                  SliverAppBar(
                    title: Text(overview.className),
                    pinned: true,
                    actions: [if (menu != null) menu],
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      FadeSlideIn(
                        index: 0,
                        child: _hero(overview, widget.embedded ? menu : null),
                      ),
                      const SizedBox(height: 12),
                      FadeSlideIn(index: 1, child: _saturday(data, overview)),
                      FadeSlideIn(
                        index: 2,
                        child: _actions(
                          canMessage: canManage,
                          onMessage: () => _messageFamilies(
                              visible, overview.classId, overview.className),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeSlideIn(index: 3, child: _followUp(data)),
                      FadeSlideIn(
                        index: 4,
                        child: _servants(data.servants, overview),
                      ),
                      // The first three on a run, «عرض الكل» for the rest.
                      if (ClassChampionsCard.championsOf(data.streaks.values)
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          index: 5,
                          child: ClassChampionsCard(
                            points: data.points,
                            champions: ClassChampionsCard.championsOf(
                                data.streaks.values,
                                points: data.points),
                            onSeeAll: () => _openChampions(overview),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            AppStrings.childrenTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${overview.activeChildren}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!isGeneralServant)
                            TextButton.icon(
                              onPressed: _addChild,
                              icon: const Icon(Icons.person_add_alt, size: 18),
                              label: const Text(AppStrings.addChild),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: ChildFilterBar(
                    filter: _filter,
                    searchController: _searchController,
                    resultCount: visible.length,
                    totalCount: totalVisible,
                    // A class of only girls (or only boys) needs no gender chips.
                    showGender:
                        overview.boysCount > 0 && overview.girlsCount > 0,
                    onChanged: (next) => setState(() => _filter = next),
                  ),
                ),
                if (visible.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: EmptyState(
                        icon: Icons.groups_outlined,
                        title: data.children.isEmpty
                            ? AppStrings.noChildren
                            : AppStrings.noData,
                        body: data.children.isEmpty
                            ? AppStrings.noChildrenBody
                            : AppStrings.clearFilters,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final child = visible[index];
                        final streak = data.streaks[child.id];
                        final tile = ChildTile(
                          child: child,
                          presentStreak: streak?.presentStreak ?? 0,
                          absentStreak: streak?.absentStreak ?? 0,
                          onTap: () => _openChild(child),
                          // Call or WhatsApp from the row, or swipe it.
                          onContact: () => showChildContactSheet(context, child),
                        );
                        // Only the first screenful slides in; rows further
                        // down appear at once so scrolling never waits.
                        return index < 12
                            ? FadeSlideIn(index: index, child: tile)
                            : tile;
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The class at a glance: patron, name (when embedded, with the menu) and
  /// the counts, in one card.
  Widget _hero(ClassOverview overview, Widget? menu) {
    final mixed = overview.boysCount > 0 && overview.girlsCount > 0;
    const onNavy = Colors.white;
    final stats = <_HeroStat>[
      _HeroStat(
        label: AppStrings.childrenCount,
        value: overview.activeChildren,
        icon: Icons.groups_rounded,
        color: AppColors.oliveLight,
      ),
      if (mixed) ...[
        _HeroStat(
          label: AppStrings.boys,
          value: overview.boysCount,
          icon: Icons.boy_rounded,
          color: const Color(0xFF8FD0F2),
        ),
        _HeroStat(
          label: AppStrings.girls,
          value: overview.girlsCount,
          icon: Icons.girl_rounded,
          color: const Color(0xFFFFA58F),
        ),
      ],
      _HeroStat(
        label: AppStrings.servantsCount,
        value: overview.servantsCount,
        icon: Icons.volunteer_activism_rounded,
        color: AppColors.gold,
      ),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.navyLight, AppColors.navy, AppColors.navyDark],
          ),
        ),
        child: Stack(
          children: [
            // Soft rings behind the content, for depth.
            PositionedDirectional(
              top: -40,
              start: -30,
              child: _Ring(size: 130, alpha: 0.07),
            ),
            PositionedDirectional(
              bottom: -50,
              end: -20,
              child: _Ring(size: 150, alpha: 0.06),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Flies in from the class's card in the list.
                      Hero(
                        tag: patronHeroTag(overview.classId),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.9),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: PatronAvatar(
                              photoPath: overview.patronPhotoPath, size: 64),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.embedded) ...[
                              Text(
                                overview.className,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: onNavy,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 13, color: AppColors.gold),
                                const SizedBox(width: 5),
                                Text(
                                  AppStrings.patronSaint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: onNavy.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              overview.patronName ?? AppStrings.noPatron,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: widget.embedded ? 15 : 19,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: onNavy.withValues(
                                    alpha:
                                        overview.patronName == null ? 0.6 : 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (menu != null) menu,
                    ],
                  ),
                  const SizedBox(height: 16),
                  // The counts sit in one frosted strip.
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14)),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          for (var i = 0; i < stats.length; i++) ...[
                            if (i > 0)
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                indent: 4,
                                endIndent: 4,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            stats[i],
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (overview.description != null &&
                      overview.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      overview.description!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: onNavy.withValues(alpha: 0.8),
                      ),
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

  /// «هذا السبت»: recorded (who came) or not yet (with the button), and when
  /// it is not known, the last Saturday on record.
  Widget _saturday(_ClassDetail data, ClassOverview overview) {
    final week = data.week;
    if (week != null && overview.isActive) {
      final date = week.date;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ClassSaturdayStatus(
          recorded: week.week.recorded,
          day: '${date.day} ${AppDateUtils.monthName(date.month)}',
          present: week.week.present,
          children: week.week.children,
          onRecord: _takeAttendance,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoRow(
        label: AppStrings.lastAttendance,
        value: overview.lastSessionDate == null
            ? AppStrings.noAttendanceYet
            : AppDateUtils.formatDayDate(overview.lastSessionDate!),
        icon: Icons.event_available_outlined,
      ),
    );
  }

  /// «متابعة الفصل»: what needs a look, counted from what the page loaded.
  Widget _followUp(_ClassDetail data) {
    final now = DateTime.now();
    final active = [
      for (final c in data.children)
        if (c.isActive) c,
    ];
    final streaks = data.streaks.values;
    final ids = {widget.classId};
    final strip = ClassFollowUpStrip(
      absent: streaks.where((s) => s.absentStreak >= 2).length,
      birthdays: active
          .where((c) => c.birthDate != null && c.birthDate!.month == now.month)
          .length,
      missing: MissingInfo.counts(active)[MissingField.birthDate] ?? 0,
      onAbsent: () => _openScreen(AbsenceFollowUpScreen(initialClassIds: ids)),
      onBirthdays: () => _openScreen(BirthdayScreen(initialClassIds: ids)),
      onMissing: () => _openScreen(MissingInfoScreen(initialClassIds: ids)),
    );
    if (strip.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: strip,
    );
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    await _reload();
  }

  /// "رسالة للأهالي": the families of the active children the filter shows
  /// (all of them, or e.g. only the absent ones once filtered).
  Future<void> _messageFamilies(
    List<Child> shown,
    String classId,
    String className,
  ) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ParentMessagesScreen(
            children: [
              for (final c in shown)
                if (c.isActive) c,
            ],
            classNames: {classId: className},
          ),
        ),
      );

  Widget _actions({
    required bool canMessage,
    required VoidCallback onMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _takeAttendance,
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text(AppStrings.attendanceTitle),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.history,
                label: AppStrings.actionHistory,
                onTap: _openHistory,
              ),
            ),
            if (canMessage) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.sms_outlined,
                  label: AppStrings.actionMessage,
                  onTap: onMessage,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Expanded(
              // The families' numbers as a contacts file, for this class.
              child: _ActionTile(
                icon: Icons.contacts_rounded,
                label: AppStrings.actionContacts,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ContactsExportScreen(classId: widget.classId),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _servants(List<ClassServant> servants, ClassOverview overview) {
    final session = context.read<SessionController>();
    return ClassServantsCard(
      servants: servants,
      currentUserId: session.profile?.id,
      // Only the admin assigns servants (the policies enforce it too).
      onAdd: session.isAdmin && overview.isActive
          ? () => _addServant(overview)
          : null,
    );
  }

  /// «إضافة خادم»: pick a servant for this class, then refresh the page and
  /// the session's classes (a moved servant's own list changes).
  Future<void> _addServant(ClassOverview overview) async {
    final added = await addServantToClass(
      context,
      classId: overview.classId,
      className: overview.className,
    );
    if (!added || !mounted) return;
    await _reload();
    if (mounted) await context.read<SessionController>().refreshClasses();
    if (mounted) context.read<SessionController>().markChanged();
  }
}

enum _ClassAction { edit, archive, delete }

class _Week {
  const _Week(this.date, this.week);

  final DateTime date;
  final ClassWeek week;
}

class _ClassDetail {
  const _ClassDetail({
    required this.overview,
    required this.servants,
    required this.children,
    required this.streaks,
    this.week,
    this.points = const {},
  });

  /// childId -> game points.
  final Map<String, int> points;

  /// This Saturday for the class; null when unknown or no lesson.
  final _Week? week;

  final Map<String, ChildStreak> streaks;

  final ClassOverview overview;
  final List<ClassServant> servants;
  final List<Child> children;
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Numbers count up when the screen opens.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              AnimatedCount(
                value: value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navyTint,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.navy),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
