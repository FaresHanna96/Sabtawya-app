import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/class_colors.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/child_changes.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/attendance.dart';
import '../../data/models/badges.dart';
import '../../data/models/child.dart';
import '../../data/models/competition.dart';
import '../../data/models/event.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/badge_repository.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/competition_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import '../badges/child_badges_card.dart';
import '../badges/class_order_screen.dart';
import '../competitions/competition_detail_screen.dart';
import '../events/event_detail_screen.dart';
import '../dashboard/weekly_attendance_chart.dart';
import 'change_history_card.dart';
import 'child_attendance_log.dart';
import 'child_avatar.dart';
import 'child_location_card.dart';
import 'contact_cards.dart';
import 'child_filters.dart';
import 'child_form_screen.dart';
import 'health_notes_card.dart';
import 'location_sheet.dart';
import 'missing_info.dart';
import 'missing_info_banner.dart';
import 'profile/child_activities_cards.dart';
import 'profile/profile_status.dart';

/// Everything known about one child: personal, parent, and church details plus
/// the attendance history and scores derived from them.
class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  static const _children = ChildRepository();
  static const _attendance = AttendanceRepository();
  static const _reports = ReportRepository();

  static const _classes = ClassRepository();
  static const _badges = BadgeRepository();
  static const _events = EventRepository();
  static const _competitions = CompetitionRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ProfileData>>();

  Future<_ProfileData> _load() async {
    // Read before the first await, while the context is certainly mounted.
    final session = context.read<SessionController>();
    final year = session.currentYear;
    final yearId = year?.id;
    final canSeeCompetitions = session.isAdmin || session.isGeneralServant;

    final child = await _children.byId(widget.childId);
    if (child == null) {
      throw AppFailure('لم يتم العثور على المخدوم');
    }

    // Trips and competitions: extras on نظرة عامة, left out when they fail.
    // Started first so they run alongside the reads below.
    final extras = (
      (
        _events.listEvents(),
        _events.childBalances(child.id),
      ).wait.catchError(
          (Object _) => (const <Event>[], const <ChildEventBalance>[])),
      // Only the admin and the general servant can read marks.
      canSeeCompetitions
          ? _competitions
              .childMarks(child.id)
              .catchError((Object _) => const <(Competition, int)>[])
          : Future.value(const <(Competition, int)>[]),
    ).wait;

    // The reads below do not depend on each other: run them side by side
    // instead of one after another (the profile waited for each in turn).
    final (
      classOverview,
      yearReport,
      history,
      lastActivity,
      logs,
      changes,
      classSessions,
      badges,
      ranking,
    ) = await (
      _classes.overviewById(child.classId),
      yearId == null
          ? Future.value(null)
          : _reports.childYear(childId: child.id, yearId: yearId),
      _attendance.childHistory(childId: child.id, yearId: yearId),
      _reports.lastActivity(child.id),
      _children.visitLogs(child.id),
      // Needs the network; offline or refused, the card just shows nothing.
      _children
          .changeHistory(child.id)
          .catchError((Object _) => const <ChildChange>[]),
      // The class's Saturdays, so one nobody recorded still shows in the log.
      yearId == null
          ? Future.value(const <AttendanceSession>[])
          : _attendance.sessionsForClasses(
              classIds: [child.classId],
              yearId:
                  yearId).catchError((Object _) => const <AttendanceSession>[]),
      // النقاط والأوسمة: a hint on top of the profile, so a failure (or
      // offline) just leaves the card out.
      yearId == null
          ? Future<List<ChildBadge>?>.value(null)
          : _badges
              .forChild(yearId: yearId, childId: child.id)
              .then<List<ChildBadge>?>((b) => b)
              .catchError((Object _) => null),
      yearId == null
          ? Future<List<LeaderboardRow>?>.value(null)
          : _badges
              .leaderboard(yearId: yearId, classId: child.classId)
              .then<List<LeaderboardRow>?>((r) => r)
              .catchError((Object _) => null),
    ).wait;
    final ((events, balances), marks) = await extras;

    return _ProfileData(
      child: child,
      className: classOverview?.className ?? AppStrings.unknown,
      yearReport: yearReport,
      history: history,
      sessionDates: [
        for (final s in classSessions)
          if (!s.isBreak) s.sessionDate,
      ],
      breakDates: {
        for (final s in classSessions)
          if (s.isBreak) s.sessionDate,
      },
      lastActivity: lastActivity,
      visitLogs: logs,
      changes: changes,
      badges: badges,
      ranking: ranking,
      trips: ChildTrip.of(
        events: events,
        balances: balances,
        today: DateTime.now(),
        year: year,
      ),
      competitionMarks: ChildCompetitionsCard.forYear(marks, year),
    );
  }

  /// ترتيب الفصل, opened from the rank on the points card.
  Future<void> _openRanking(Child child, String className) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ClassOrderScreen(
            classId: child.classId,
            className: className,
            highlightChildId: child.id,
          ),
        ),
      );

  /// A trip's own screen (payments, bookings); back here, the card reloads.
  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => EventDetailScreen(event: event)),
    );
    if (mounted) await _reload();
  }

  Future<void> _openCompetition(Competition competition) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CompetitionDetailScreen(competition: competition),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _edit(Child child) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => ChildFormScreen(child: child)),
    );
    if (changed == true) await _reload();
  }

  /// Puts back what one history line changed, newest edit first.
  Future<void> _undoChange(ChildChangeGroup group) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.undoEditTitle,
      message: AppStrings.undoEditMessage,
      confirmLabel: AppStrings.undo,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () async {
        for (final id in group.ids) {
          await _children.revertChange(id);
        }
      },
      successMessage: AppStrings.undoDone,
    );
    if (ok && mounted) {
      await context.read<SessionController>().refreshClasses();
      await _reload();
    }
  }

  Future<void> _setLocation(Child child) async {
    final saved = await showLocationSheet(
      context,
      childId: child.id,
      current: child.location,
    );
    if (saved && mounted) await _reload();
  }

  Future<void> _toggleActive(Child child) async {
    if (child.isActive) {
      final confirmed = await Ui.confirm(
        context,
        title: AppStrings.deactivateChild,
        message: AppStrings.confirmDeactivateChild,
        confirmLabel: AppStrings.deactivateChild,
        destructive: true,
      );
      if (!confirmed) return;
    }

    if (!mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () => _children.setActive(child.id, !child.isActive),
      successMessage: child.isActive
          ? AppStrings.childDeactivated
          : AppStrings.childActivated,
    );
    if (ok && mounted) {
      await context.read<SessionController>().refreshClasses();
      await _reload();
    }
  }

  Future<void> _move(Child child, String currentClassName) async {
    final classes = await _classes.list();
    if (!mounted) return;

    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MoveChildSheet(
        classes: classes.where((item) => item.id != child.classId).toList(),
        currentClassName: currentClassName,
      ),
    );
    if (target == null || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _children.moveToClass(childId: child.id, newClassId: target),
      successMessage: AppStrings.childMoved,
    );
    if (ok && mounted) {
      await context.read<SessionController>().refreshClasses();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final canEdit = !session.isGeneralServant;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.childProfile)),
      body: AsyncSection<_ProfileData>(
        key: _sectionKey,
        load: _load,
        // Each tab has its own pull to refresh (the tabs scroll, not the page).
        enableRefresh: false,
        builder: (context, data, reload) {
          final child = data.child;
          // The points, badges and rank loaded: they join the header card.
          final hasGame = data.badges != null &&
              data.badges!.isNotEmpty &&
              data.ranking != null;
          final alerts = profileAlerts(
            child: child,
            absentSaturdays: absentRun(data.history, data.sessionDates),
            today: DateTime.now(),
          );
          Widget tab(List<Widget> children) => RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: children,
                ),
              );

          return DefaultTabController(
            length: 4,
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeSlideIn(
                          index: 0,
                          child: Builder(
                            builder: (context) => _header(
                              child,
                              data.className,
                              canEdit: canEdit,
                              isAdmin: isAdmin,
                              panel: !hasGame
                                  ? null
                                  : GamePointsPanel(
                                      framed: false,
                                      points: data.gamePoints,
                                      run: currentRun(data.badges!),
                                      rank: LeaderboardRow.rankOf(
                                          data.ranking!, child.id),
                                      onOpenRanking: () =>
                                          _openRanking(child, data.className),
                                      attendancePct: data.yearReport == null ||
                                              data.yearReport!.sessionsTotal ==
                                                  0
                                          ? null
                                          : data.yearReport!.percentage,
                                      onOpenAttendance: () =>
                                          DefaultTabController.of(context)
                                              .animateTo(1),
                                    ),
                            ),
                          ),
                        ),
                        if (alerts.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          FadeSlideIn(
                            index: 1,
                            child: ProfileStatusStrip(
                              alerts: alerts,
                              onCall: ContactPerson.forChild(child).isEmpty
                                  ? null
                                  : () => _callFamily(child),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabsHeader(
                    TabBar(
                      isScrollable: false,
                      labelColor: AppColors.navy,
                      unselectedLabelColor: AppColors.muted,
                      indicatorColor: AppColors.navy,
                      labelStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: AppStrings.profileTabOverview),
                        Tab(text: AppStrings.profileTabAttendance),
                        Tab(text: AppStrings.profileTabData),
                        Tab(text: AppStrings.profileTabFollowUp),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  // ── نظرة عامة: who to reach, how they are doing.
                  tab([
                    _contactBar(child),
                    if (canEdit && MissingInfo.of(child).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      MissingInfoBanner(
                        child: child,
                        servantName: session.displayName,
                        canEdit: canEdit,
                        onEdit: () => _edit(child),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // The attendance % is in the header with the points;
                    // without them it keeps a card of its own.
                    if (!hasGame)
                      Builder(
                        builder: (context) => _attendanceGlance(
                          data,
                          onOpen: () =>
                              DefaultTabController.of(context).animateTo(1),
                        ),
                      )
                    else
                      ChildBadgesCard(
                        badges: data.badges!,
                        gamePoints: data.gamePoints,
                        showPoints: false,
                        detailInSheet: true,
                      ),
                    if (data.trips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ChildTripsCard(trips: data.trips, onOpen: _openEvent),
                    ],
                    if (data.competitionMarks.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ChildCompetitionsCard(
                        marks: data.competitionMarks,
                        onOpen: _openCompetition,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) => _lastFollowUp(
                        data,
                        onOpen: () =>
                            DefaultTabController.of(context).animateTo(3),
                      ),
                    ),
                  ]),
                  // ── الحضور: every Saturday.
                  tab([
                    ChildAttendanceLog(
                      history: data.history,
                      sessionDates: data.sessionDates,
                      breakDates: data.breakDates,
                      lastActivity: data.lastActivity,
                      points: data.yearReport?.points,
                    ),
                  ]),
                  // ── البيانات: only what is not already above.
                  tab(_dataTab(child, data, session, canEdit)),
                  // ── المتابعة: record a call or a visit, then the history.
                  tab([
                    if (canEdit) ...[
                      _VisitSection(
                        // Re-create when the stored visit changes (saved or a
                        // history entry deleted), so the fields show the new
                        // values.
                        key: ValueKey('${child.id}|${child.lastPhoneVisitDate}|'
                            '${child.lastPhoneVisitNotes}|'
                            '${child.lastHomeVisitDate}|'
                            '${child.lastHomeVisitNotes}'),
                        child: child,
                        onSaved: _reload,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _visitHistoryCard(data, canEdit),
                    if (data.changes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ChangeHistoryCard(
                        changes: data.changes,
                        onUndo: canEdit ? _undoChange : null,
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// «اتصل» on the status strip: the family's numbers, one tap each.
  Future<void> _callFamily(Child child) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _contactBar(child),
          ),
        ),
      );

  /// The year at a glance on «نظرة عامة»; the full log is one tap away.
  Widget _attendanceGlance(_ProfileData data, {required VoidCallback onOpen}) {
    final y = data.yearReport;
    final pct = y == null ? 0.0 : y.percentage.clamp(0, 100).toDouble();
    return SectionCard(
      title: AppStrings.attendanceSummary,
      icon: Icons.fact_check_rounded,
      accent: AppColors.success,
      trailing: TextButton(
        onPressed: onOpen,
        child: const Text(AppStrings.seeAll),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: y == null || y.sessionsTotal == 0
          ? const Text(
              AppStrings.noAttendanceYet,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '${pct.round()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.readable(
                            WeeklyAttendanceChart.levelColor(pct)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStrings.attendedSaturdays(
                            y.sessionsAttended, y.sessionsTotal),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct / 100),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation(
                          WeeklyAttendanceChart.levelColor(pct)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// The last call or visit, one line; the whole follow-up one tap away.
  Widget _lastFollowUp(_ProfileData data, {required VoidCallback onOpen}) {
    final last = data.visitLogs.isEmpty ? null : data.visitLogs.first;
    return SectionCard(
      title: AppStrings.profileTabFollowUp,
      icon: Icons.support_agent_rounded,
      accent: AppColors.coral,
      trailing: TextButton(
        onPressed: onOpen,
        child: const Text(AppStrings.seeAll),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Text(
        last == null
            ? AppStrings.noVisitHistory
            : '${last.isPhone ? AppStrings.followUpPhone : AppStrings.followUpHome}'
                ' • ${AppDateUtils.formatDate(last.visitDate)}'
                ' • ${AppDateUtils.sinceLabel(last.visitDate)}',
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }

  /// «البيانات»: the record, without what the header and the contact cards
  /// already say (name, gender, age, class, phone numbers).
  List<Widget> _dataTab(
    Child child,
    _ProfileData data,
    SessionController session,
    bool canEdit,
  ) {
    String? orNull(String? s) => (s == null || s.trim().isEmpty) ? null : s;
    return [
      SectionCard(
        title: AppStrings.personalInfo,
        icon: Icons.badge_rounded,
        accent: AppColors.navyLight,
        child: Column(
          children: [
            InfoRow(
              label: AppStrings.birthDate,
              value: child.birthDate == null
                  ? null
                  : AppDateUtils.formatDate(child.birthDate!),
              icon: Icons.cake_outlined,
            ),
            InfoRow(
              label: AppStrings.childCode,
              value: child.code,
              icon: Icons.tag,
            ),
            InfoRow(
              label: AppStrings.motherName,
              value: orNull(child.motherName),
              icon: Icons.woman_outlined,
            ),
            InfoRow(
              label: AppStrings.fatherName,
              value: orNull(child.fatherName),
              icon: Icons.man_outlined,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: AppStrings.churchInfo,
        icon: Icons.church_rounded,
        accent: AppColors.maroon,
        child: Column(
          children: [
            InfoRow(
              label: AppStrings.confessionFather,
              value: child.confessionFather,
              icon: Icons.church_outlined,
            ),
            if (child.gender == Gender.boy)
              InfoRow(
                label: AppStrings.deacon,
                value: child.isDeacon ? AppStrings.yes : AppStrings.no,
                icon: Icons.volunteer_activism_outlined,
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: AppStrings.schoolInfo,
        icon: Icons.school_rounded,
        accent: AppColors.olive,
        child: Column(
          children: [
            InfoRow(
              label: AppStrings.school,
              value: child.school,
              icon: Icons.apartment_outlined,
            ),
            InfoRow(
              label: AppStrings.address,
              value: child.address,
              icon: Icons.location_on_outlined,
            ),
            InfoRow(
              label: AppStrings.notes,
              value: child.notes,
              icon: Icons.notes_outlined,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ChildLocationCard(
        location: child.location,
        address: child.address,
        onSet: canEdit ? () => _setLocation(child) : null,
      ),
      if (canSeeHealthNotes(session, child.classId)) ...[
        const SizedBox(height: 12),
        HealthNotesCard(
          key: ValueKey('health|${child.id}'),
          childId: child.id,
        ),
      ],
      const SizedBox(height: 12),
      Text(
        [
          if (child.createdAt != null)
            '${AppStrings.createdAt}: ${AppDateUtils.formatDate(child.createdAt!)}',
          if (child.updatedAt != null)
            '${AppStrings.updatedAt}: ${AppDateUtils.formatDateTime(child.updatedAt!)}',
        ].join('  •  '),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
      ),
    ];
  }

  /// Opens the photo full width so a face is actually recognisable.
  Future<void> _viewPhoto(Child child) async {
    final url = await PhotoService.signedUrl(
      bucket: Db.bucketChildPhotos,
      path: child.photoPath,
    );
    if (url == null || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(Icons.broken_image_outlined, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                child.fullName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One tap to call the child, the mother or the father (whichever numbers
  /// exist). Hidden when there is no number at all.
  Widget _contactBar(Child child) {
    return ContactCards(
      people: ContactPerson.forChild(child),
      childName: child.fullName,
      servantName: context.read<SessionController>().displayName,
    );
  }

  /// Who the child is, with ✏️ and ⋮. With [panel] (the points, level, run,
  /// rank and attendance) it is one navy card holding both; without (badges
  /// not loaded) the light card of before.
  Widget _header(
    Child child,
    String className, {
    required bool canEdit,
    required bool isAdmin,
    Widget? panel,
  }) {
    final dark = panel != null;
    final ink = dark ? Colors.white : AppColors.navy;
    final soft = dark ? const Color(0xFFDCE4F2) : AppColors.muted;
    final tint = child.gender == Gender.boy ? AppColors.sky : AppColors.coral;
    final identity = Row(
      children: [
        GestureDetector(
          onTap: child.hasPhoto ? () => _viewPhoto(child) : null,
          child: Container(
            padding: dark ? const EdgeInsets.all(2) : EdgeInsets.zero,
            decoration: dark
                ? const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  )
                : null,
            child: ChildAvatar(
              child: child,
              size: dark ? 52 : 56,
              heroTag: 'child-${child.id}',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                child.fullName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : null,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (!dark) GenderBadge(gender: child.gender, compact: true),
                  _headerFact(Icons.class_outlined, className, soft),
                  if (child.ageLabel != null)
                    _headerFact(Icons.cake_outlined, child.ageLabel!, soft),
                  if (!child.isActive) const StatusBadge(isActive: false),
                ],
              ),
            ],
          ),
        ),
        if (canEdit) ...[
          IconButton(
            tooltip: AppStrings.editChild,
            color: ink,
            onPressed: () => _edit(child),
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: AppStrings.profileMoreActions,
            icon: Icon(Icons.more_vert, color: ink),
            onSelected: (v) => switch (v) {
              'move' => _move(child, className),
              _ => _toggleActive(child),
            },
            itemBuilder: (_) => [
              if (isAdmin)
                const PopupMenuItem(
                  value: 'move',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.swap_horiz),
                    title: Text(AppStrings.moveChild),
                  ),
                ),
              PopupMenuItem(
                value: 'active',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    child.isActive
                        ? Icons.person_off_outlined
                        : Icons.person_add_alt,
                    color:
                        child.isActive ? AppColors.danger : AppColors.success,
                  ),
                  title: Text(
                    child.isActive
                        ? AppStrings.deactivateChild
                        : AppStrings.activateChild,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (dark) {
      return Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 6, 16),
        decoration: BoxDecoration(
          gradient: AppGradients.navyHeader,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            identity,
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: panel,
            ),
          ],
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [
              tint.withValues(alpha: 0.24),
              classAccent(child.classId).withValues(alpha: 0.10),
              Colors.white,
            ],
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
        child: identity,
      ),
    );
  }

  /// A small icon and a few words under the child's name (class, age).
  Widget _headerFact(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Deletes one history entry, then points the card's "last visit" back at
  /// the newest entry that is left (only when the deleted one was the newest
  /// of its type, so older cards without history are left alone).
  Future<void> _deleteVisit(ChildVisitLog log, _ProfileData data) async {
    final yes = await Ui.confirm(
      context,
      title: AppStrings.deleteVisit,
      destructive: true,
      confirmLabel: AppStrings.delete,
    );
    if (!yes || !mounted) return;

    final sameType = data.visitLogs.where((l) => l.visitType == log.visitType);
    final wasNewest = sameType.isNotEmpty && sameType.first.id == log.id;
    final remaining = sameType.where((l) => l.id != log.id);

    final ok = await Ui.runGuarded(
      context,
      () async {
        await _children.deleteVisitLog(log.id);
        if (!wasNewest) return;
        final next = remaining.isEmpty ? null : remaining.first;
        final c = data.child;
        await _children.update(
          c.withVisits(
            phoneVisitDate:
                log.isPhone ? next?.visitDate : c.lastPhoneVisitDate,
            phoneVisitNotes: log.isPhone ? next?.notes : c.lastPhoneVisitNotes,
            homeVisitDate: log.isPhone ? c.lastHomeVisitDate : next?.visitDate,
            homeVisitNotes: log.isPhone ? c.lastHomeVisitNotes : next?.notes,
          ),
        );
      },
      successMessage: AppStrings.visitDeleted,
    );
    if (ok && mounted) await _reload();
  }

  Widget _visitHistoryCard(_ProfileData data, bool canEdit) {
    final logs = data.visitLogs;
    return SectionCard(
      title: AppStrings.visitHistory,
      icon: Icons.home_rounded,
      accent: AppColors.coral,
      collapsible: true,
      child: logs.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppStrings.noVisitHistory,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: logs
                  .map((l) => _visitLogRow(l, canEdit ? data : null))
                  .toList(),
            ),
    );
  }

  Widget _visitLogRow(ChildVisitLog log, _ProfileData? deletable) {
    final isPhone = log.isPhone;
    final tint = isPhone ? AppColors.navy : AppColors.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same tinted round icon as the change history, so the two logs
          // read as one family.
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPhone ? Icons.phone_callback_rounded : Icons.home_rounded,
              size: 15,
              color: tint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: AppDateUtils.formatDate(log.visitDate),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: ' · ${AppDateUtils.sinceLabel(log.visitDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log.recorderName != null && log.recorderName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      AppStrings.visitBy(log.recorderName!),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.navy,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                if (log.notes != null && log.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      log.notes!,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (isPhone ? AppColors.navy : AppColors.success)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              // Each row's own type; "آخر" belongs only to the card's last
              // visit, not to every entry in the history.
              isPhone ? AppStrings.followUpPhone : AppStrings.followUpHome,
              style: TextStyle(
                fontSize: 12,
                color: isPhone ? AppColors.navy : AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (deletable != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.muted,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
              tooltip: AppStrings.delete,
              onPressed: () => _deleteVisit(log, deletable),
            ),
        ],
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.child,
    required this.className,
    required this.yearReport,
    required this.history,
    required this.lastActivity,
    required this.visitLogs,
    this.sessionDates = const <DateTime>[],
    this.breakDates = const <DateTime>{},
    this.changes = const <ChildChange>[],
    this.badges,
    this.ranking,
    this.trips = const <ChildTrip>[],
    this.competitionMarks = const <(Competition, int)>[],
  });

  /// This year's trips worth showing (booked, or still to come).
  final List<ChildTrip> trips;

  /// This year's competition marks, newest first (admin / general only).
  final List<(Competition, int)> competitionMarks;

  /// The six badges this year; null when they could not be read.
  final List<ChildBadge>? badges;

  /// The class ranking for the year; null when it could not be read.
  final List<LeaderboardRow>? ranking;

  /// The game points: this child's line in [ranking] (attendance points
  /// plus the badge bonus), 0 when not found.
  int get gamePoints {
    for (final r in ranking ?? const <LeaderboardRow>[]) {
      if (r.childId == child.id) return r.gamePoints;
    }
    return 0;
  }

  final Child child;
  final String className;
  final ChildYearReport? yearReport;
  final List<ChildSessionScore> history;

  /// The class's Saturdays this year, recorded or not.
  final List<DateTime> sessionDates;

  /// Its Saturdays with no lesson (إجازة / نشاط ترفيهي).
  final Set<DateTime> breakDates;
  final ChildLastActivity? lastActivity;
  final List<ChildVisitLog> visitLogs;
  final List<ChildChange> changes;
}

// ---------------------------------------------------------------------------
// Visits section — inline editable datepicker + notes for phone & home visits.
// ---------------------------------------------------------------------------

class _VisitSection extends StatefulWidget {
  const _VisitSection({super.key, required this.child, required this.onSaved});

  final Child child;
  final Future<void> Function() onSaved;

  @override
  State<_VisitSection> createState() => _VisitSectionState();
}

class _VisitSectionState extends State<_VisitSection> {
  static const _children = ChildRepository();

  late DateTime? _phoneDate;
  late DateTime? _homeDate;
  late final TextEditingController _phoneNotes;
  late final TextEditingController _homeNotes;

  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _phoneDate = widget.child.lastPhoneVisitDate;
    _homeDate = widget.child.lastHomeVisitDate;
    _phoneNotes =
        TextEditingController(text: widget.child.lastPhoneVisitNotes ?? '');
    _homeNotes =
        TextEditingController(text: widget.child.lastHomeVisitNotes ?? '');
  }

  @override
  void dispose() {
    _phoneNotes.dispose();
    _homeNotes.dispose();
    super.dispose();
  }

  void _mark() => setState(() => _dirty = true);

  Future<void> _pickDate({required bool isPhone}) async {
    final current = isPhone ? _phoneDate : _homeDate;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: AppStrings.pickVisitDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isPhone) {
        _phoneDate = picked;
      } else {
        _homeDate = picked;
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    FocusScope.of(context).unfocus();

    final phoneNotes =
        _phoneNotes.text.trim().isEmpty ? null : _phoneNotes.text.trim();
    final homeNotes =
        _homeNotes.text.trim().isEmpty ? null : _homeNotes.text.trim();

    final updated = widget.child.withVisits(
      phoneVisitDate: _phoneDate,
      phoneVisitNotes: phoneNotes,
      homeVisitDate: _homeDate,
      homeVisitNotes: homeNotes,
    );

    final ok = await Ui.runGuarded(
      context,
      () async {
        await _children.update(updated);
        // Record a history entry whenever the date OR the notes changed. A
        // corrected note on the same day updates the servant's own entry for
        // that day instead of adding a near-identical second one.
        String? clean(String? s) =>
            (s == null || s.trim().isEmpty) ? null : s.trim();
        final phoneChanged = _phoneDate != widget.child.lastPhoneVisitDate ||
            phoneNotes != clean(widget.child.lastPhoneVisitNotes);
        final homeChanged = _homeDate != widget.child.lastHomeVisitDate ||
            homeNotes != clean(widget.child.lastHomeVisitNotes);
        if (_phoneDate != null && phoneChanged) {
          await _children.recordVisitLog(
            childId: widget.child.id,
            visitType: 'phone',
            visitDate: _phoneDate!,
            notes: phoneNotes,
          );
        }
        if (_homeDate != null && homeChanged) {
          await _children.recordVisitLog(
            childId: widget.child.id,
            visitType: 'home',
            visitDate: _homeDate!,
            notes: homeNotes,
          );
        }
      },
      successMessage: AppStrings.visitsSaved,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _dirty = false;
    });
    if (ok) await widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.visitsSection,
      icon: Icons.home_rounded,
      accent: AppColors.coral,
      collapsible: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _visitRow(
            label: AppStrings.lastPhoneVisit,
            icon: Icons.phone_callback_outlined,
            date: _phoneDate,
            notesController: _phoneNotes,
            isPhone: true,
          ),
          const SizedBox(height: 12),
          _visitRow(
            label: AppStrings.lastHomeVisit,
            icon: Icons.home_outlined,
            date: _homeDate,
            notesController: _homeNotes,
            isPhone: false,
          ),
          if (_dirty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text(AppStrings.save),
            ),
          ],
        ],
      ),
    );
  }

  Widget _visitRow({
    required String label,
    required IconData icon,
    required DateTime? date,
    required TextEditingController notesController,
    required bool isPhone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _pickDate(isPhone: isPhone),
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon),
              suffixIcon: date == null
                  ? const Icon(Icons.calendar_today_outlined, size: 20)
                  : IconButton(
                      tooltip: AppStrings.clearField,
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() {
                        if (isPhone) {
                          _phoneDate = null;
                        } else {
                          _homeDate = null;
                        }
                        _dirty = true;
                      }),
                    ),
            ),
            child: Text(
              date == null
                  ? AppStrings.noVisitYet
                  : '${AppDateUtils.formatDate(date)} • ${AppDateUtils.sinceLabel(date)}',
              style: TextStyle(
                fontSize: 15,
                color: date == null ? AppColors.muted : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: notesController,
          maxLines: 2,
          onChanged: (_) => _mark(),
          decoration: const InputDecoration(
            labelText: AppStrings.visitNotes,
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _MoveChildSheet extends StatefulWidget {
  const _MoveChildSheet(
      {required this.classes, required this.currentClassName});

  final List<SchoolClass> classes;
  final String currentClassName;

  @override
  State<_MoveChildSheet> createState() => _MoveChildSheetState();
}

class _MoveChildSheetState extends State<_MoveChildSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AppStrings.moveChild,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.moveChildBody,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 18),
          InfoRow(
            label: AppStrings.currentClass,
            value: widget.currentClassName,
            icon: Icons.class_outlined,
          ),
          const SizedBox(height: 12),
          if (widget.classes.isEmpty)
            const Text(
              AppStrings.noClasses,
              style: TextStyle(color: AppColors.muted),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: AppStrings.newClass),
              items: widget.classes
                  .map((item) => DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(item.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selected = value),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            child: const Text(AppStrings.confirm),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
        ],
      ),
    );
  }
}

/// The profile's tabs, pinned under the app bar while the header scrolls away.
class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader(this.tabs);

  final TabBar tabs;

  @override
  double get minExtent => tabs.preferredSize.height;

  @override
  double get maxExtent => tabs.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      Material(
        color: AppColors.surface,
        elevation: overlapsContent || shrinkOffset > 0 ? 2 : 0,
        child: tabs,
      );

  @override
  bool shouldRebuild(_TabsHeader old) => old.tabs != tabs;
}
