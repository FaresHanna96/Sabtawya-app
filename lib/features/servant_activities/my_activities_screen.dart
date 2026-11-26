import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/attendance.dart';
import '../../data/models/profile.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import 'lesson_prep_screen.dart';
import 'prep_review_sheet.dart';
import 'servant_badges.dart';
import 'servant_covers.dart';
import '../../data/repositories/servant_repository.dart';
import 'servant_summary_card.dart';
import 'servant_year.dart';

class MyActivitiesScreen extends StatefulWidget {
  const MyActivitiesScreen({super.key, this.showAppBar = false});

  /// The home shell already has an app bar for this tab; a pushed screen
  /// (from the dashboard) needs its own.
  final bool showAppBar;

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  static const _repo = ServantActivityRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ActivitiesData>>();

  Future<_ActivitiesData> _load() async {
    final session = context.read<SessionController>();
    final classIds = session.myClasses.map((c) => c.classId).toList();
    final year = session.currentYear;
    if (year == null) {
      return const _ActivitiesData(
        sessions: [],
        preps: [],
        marks: [],
        sundaySchool: 0,
        servantMeeting: 0,
        mass: 0,
        confession: 0,
      );
    }

    final (sessions, preps, marks, yearDates, activityDays, subs, people) =
        await (
      _repo.sessionsForClasses(classIds, yearId: year.id),
      // Status and Saturday only; a prep's page loads its files.
      _repo.myPrepsSummary(),
      // This servant's own marks of this year, in one query: the counts
      // (the percentages divide by this year's Saturdays) and «حضوري».
      _repo.marksForServant(
        servantId: Db.userId!,
        from: year.startDate,
        to: year.endDate,
      ),
      // Every Saturday of the year, for the badges (a general servant has
      // no class sessions of their own); best effort.
      _repo
          .sessionDatesForYear(year.id)
          .catchError((Object _) => const <DateTime>[]),
      // The نشاط ترفيهي days among them: no prep that day.
      _repo
          .activityDatesForYear(year.id)
          .catchError((Object _) => const <DateTime>[]),
      // «التغطيات», with names from the servants' directory; best effort.
      _repo
          .substitutesForServant(
            Db.userId!,
            from: year.startDate,
            to: year.endDate,
          )
          .catchError((Object _) => const <ServantSubstitute>[]),
      const ServantRepository()
          .directory()
          .catchError((Object _) => const <ServantContact>[]),
    ).wait;
    final counts = ServantActivityRepository.countByType(
      [
        for (final m in marks) {'activity_type': m.activityType}
      ],
    );

    return _ActivitiesData(
      sessions: sessions,
      preps: [
        for (final p in preps)
          if (year.contains(p.sessionDate)) p,
      ],
      marks: marks,
      sundaySchool: counts['sunday_school'] ?? 0,
      servantMeeting: counts['servant_meeting'] ?? 0,
      mass: counts['mass'] ?? 0,
      confession: counts['confession'] ?? 0,
      yearDates: yearDates,
      activityDays: activityDays,
      isClassServant: classIds.isNotEmpty,
      subs: subs,
      names: {for (final p in people) p.id: p.fullName},
    );
  }

  /// "عرض الكل" under the upcoming Saturdays.
  bool _showAllUpcoming = false;

  /// "عرض الكل" under the past Saturdays (newest three otherwise).
  bool _showAllPast = false;

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _openSession(AttendanceSession session) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LessonPrepScreen(
          sessionId: session.id,
          sessionDate: session.sessionDate,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(title: const Text(AppStrings.myActivities))
          : null,
      body: SafeArea(
        child: AsyncSection<_ActivitiesData>(
          key: _sectionKey,
          load: _load,
          builder: (context, data, _) {
            if (data.sessions.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.06),
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: AppStrings.noLessonPreps,
                    body: AppStrings.noLessonPrepsBody,
                  ),
                ],
              );
            }

            // Only sessions already held count towards the percentage, not
            // the whole year.
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final held = data.sessions
                .where((s) => !s.sessionDate.isAfter(today))
                .toList();
            final submitted =
                held.where((s) => data.prepFor(s.id) != null).length;
            final accepted = held
                .where((s) => data.prepFor(s.id)?.status == 'accepted')
                .length;
            final total = held.length;

            // The Saturdays the servant's attendance counts: the class's
            // lesson days plus the whole year's (a نشاط ترفيهي has no lesson
            // but is counted), one per date.
            DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
            final heldDays = <DateTime>{
              for (final s in held) dayOf(s.sessionDate),
              for (final d in data.yearDates)
                if (!d.isAfter(today)) dayOf(d),
            }.toList();

            final g = PrepGroups.of(
              data.sessions,
              hasPrep: (id) => data.prepFor(id) != null,
              today: today,
            );
            final current = g.current;
            final missed = g.missed;
            final past = g.past;
            final later = g.later;
            final pastShown = _showAllPast ? past : past.take(3).toList();
            final laterShown =
                _showAllUpcoming ? later : later.take(3).toList();

            var n = 0;
            Widget card(AttendanceSession s, {bool highlight = false}) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: staggered(
                    n++,
                    _SessionCard(
                      session: s,
                      prep: data.prepFor(s.id),
                      missed: s.sessionDate.isBefore(today) &&
                          data.prepFor(s.id) == null,
                      highlight: highlight,
                      onTap: () => _openSession(s),
                    ),
                  ),
                );

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // The one thing to do this week, first.
                if (current != null) ...[
                  FadeSlideIn(
                    child: PrepTodoCard(
                      date: current.sessionDate,
                      prep: data.prepFor(current.id),
                      onOpen: () => _openSession(current),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // How the preparations stand, right under this week's one.
                FadeSlideIn(
                  index: 1,
                  child: _ProgressHeader(
                    submitted: submitted,
                    accepted: accepted,
                    total: total,
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  child: ServantSummaryCard(
                    sundaySchool: data.sundaySchool,
                    servantMeeting: data.servantMeeting,
                    mass: data.mass,
                    confession: data.confession,
                    // Uploaded, or ticked by the admin: once per Saturday.
                    preps: prepSaturdays(
                      preps: data.preps,
                      marks: data.marks,
                      dates: [
                        ...data.yearDates,
                        for (final s in data.sessions) s.sessionDate,
                      ],
                    ),
                    pendingPreps:
                        data.preps.where((p) => p.status == 'pending').length,
                    heldSessions: heldDays.length,
                    prepSessions: heldDays
                        .where((d) => !data.activityDays.any((a) => dayOf(a) == d))
                        .length,
                  ),
                ),
                const SizedBox(height: 12),
                MyAttendanceCard(
                  held: heldDays,
                  marks: data.marks,
                  activityDays: data.activityDays,
                ),
                const SizedBox(height: 12),
                ServantBadgesCard(
                  badges: ServantYear(
                    heldSaturdays: [
                      ...data.yearDates,
                      for (final s in held) s.sessionDate,
                    ],
                    marks: data.marks,
                    preps: data.preps,
                    today: DateTime.now(),
                    classServantIds: {
                      if (data.isClassServant && Db.userId != null) Db.userId!,
                    },
                    noPrepDays: data.activityDays,
                  ).badges(Db.userId ?? ''),
                ),
                if (data.subs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ServantCoversCard(
                    servantId: Db.userId ?? '',
                    subs: data.subs,
                    nameOf: (id) => data.names[id] ?? '',
                  ),
                ],
                const SizedBox(height: 20),
                if (missed.isNotEmpty) ...[
                  _GroupTitle(
                    icon: Icons.error_outline_rounded,
                    text: '${AppStrings.missedPrepsTitle} (${missed.length})',
                  ),
                  for (final s in missed) card(s),
                  const SizedBox(height: 10),
                ],
                if (past.isNotEmpty) ...[
                  _GroupTitle(
                    icon: Icons.history_rounded,
                    text: '${AppStrings.pastSaturdays} (${past.length})',
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [for (final s in pastShown) card(s)],
                    ),
                  ),
                  if (past.length > 3)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAllPast = !_showAllPast),
                      child: Text(
                        _showAllPast ? AppStrings.showLess : AppStrings.showAll,
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                if (later.isNotEmpty) ...[
                  _GroupTitle(
                    icon: Icons.upcoming_rounded,
                    text: '${AppStrings.upcomingSaturdays} (${later.length})',
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                      children: [for (final s in laterShown) card(s)],
                    ),
                  ),
                  if (later.length > 3)
                    TextButton(
                      onPressed: () => setState(
                        () => _showAllUpcoming = !_showAllUpcoming,
                      ),
                      child: Text(
                        _showAllUpcoming
                            ? AppStrings.showLess
                            : AppStrings.showAll,
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Small heading above each group of Saturdays.
class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.navy),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress header

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.submitted,
    required this.accepted,
    required this.total,
  });

  final int submitted;
  final int accepted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? submitted / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.navyHeader,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                AppStrings.lessonPrep,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                // The percentage counts up when the screen opens.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    '$submitted / $total  ·  ${(v * 100).round()}%',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniBadge(
                icon: Icons.check_circle_outline,
                label: AppStrings.prepAccepted,
                value: '$accepted',
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              _MiniBadge(
                icon: Icons.hourglass_empty_outlined,
                label: AppStrings.prepPending,
                value: '${submitted - accepted}',
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Sits on the dark navy header, so the badge is a light pill: the status
    // colour alone is too dim against the gradient.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.readable(color),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.prep,
    required this.onTap,
    this.missed = false,
    this.highlight = false,
  });

  final AttendanceSession session;
  final LessonPrep? prep;
  final VoidCallback onTap;

  /// A Saturday already gone with nothing uploaded.
  final bool missed;

  /// The next Saturday: the one to prepare now.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final hasPrep = prep != null;
    final status = prep?.status ?? '';
    final color = hasPrep
        ? _statusColor(status)
        : missed
            ? AppColors.coral
            : AppColors.navy;
    final icon = hasPrep
        ? _statusIcon(status)
        : missed
            ? Icons.error_outline_rounded
            : Icons.upload_outlined;
    final label = hasPrep
        ? _statusLabel(status)
        : missed
            ? AppStrings.prepMissing
            : AppStrings.submitLessonPrep;

    return Card(
      color: highlight
          ? Color.alphaBlend(
              AppColors.gold.withValues(alpha: 0.08),
              Colors.white,
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: highlight
            ? BorderSide(
                color: AppColors.gold.withValues(alpha: 0.7), width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            // Color accent bar
            Container(
              width: 4,
              height: 68,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppDateUtils.formatDayDate(session.sessionDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.readable(color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (prep?.isShared ?? false)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Tooltip(
                  message: AppStrings.prepSharedAsExample,
                  child:
                      Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
                ),
              ),
            if (prep?.adminComment != null && prep!.adminComment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  size: 15,
                  color: AppColors.sky,
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(left: 4, right: 12),
              child: Icon(AppIcons.forward, size: 18, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String status) => prepStatusLabel(status);

  static IconData _statusIcon(String status) => prepStatusIcon(status);

  static Color _statusColor(String status) => prepStatusColor(status);
}

// ---------------------------------------------------------------------------

class _ActivitiesData {
  const _ActivitiesData({
    required this.sessions,
    required this.preps,
    required this.marks,
    required this.sundaySchool,
    required this.servantMeeting,
    required this.mass,
    required this.confession,
    this.yearDates = const [],
    this.activityDays = const [],
    this.isClassServant = false,
    this.subs = const [],
    this.names = const {},
  });

  final List<ServantSubstitute> subs;
  final Map<String, String> names;

  /// Every Saturday of the year held or not (no breaks), for the badges.
  final List<DateTime> yearDates;

  /// The نشاط ترفيهي Saturdays: servants are marked, there is no prep.
  final List<DateTime> activityDays;
  final bool isClassServant;

  final List<AttendanceSession> sessions;
  final List<LessonPrep> preps;

  /// This servant's own marks this year (for «حضوري»).
  final List<ServantAttendance> marks;
  final int sundaySchool;
  final int servantMeeting;
  final int mass;
  final int confession;

  LessonPrep? prepFor(String sessionId) {
    for (final p in preps) {
      if (p.sessionId == sessionId) return p;
    }
    return null;
  }
}

/// A servant's Saturdays in the order «نشاطي» shows them: the next one (to
/// prepare), past ones with no prep sent (a to-do), the other past ones
/// newest first, then the rest of the year.
class PrepGroups {
  const PrepGroups({
    required this.current,
    required this.missed,
    required this.past,
    required this.later,
  });

  final AttendanceSession? current;
  final List<AttendanceSession> missed;
  final List<AttendanceSession> past;
  final List<AttendanceSession> later;

  factory PrepGroups.of(
    List<AttendanceSession> sessions, {
    required bool Function(String sessionId) hasPrep,
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final next = sessions.where((s) => !s.sessionDate.isBefore(day)).toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    final current = next.isEmpty ? null : next.first;
    final earlier = sessions
        .where((s) => s.sessionDate.isBefore(day) && s.id != current?.id)
        .toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));
    return PrepGroups(
      current: current,
      missed: [
        for (final s in earlier)
          if (!hasPrep(s.id)) s,
      ],
      past: [
        for (final s in earlier)
          if (hasPrep(s.id)) s,
      ],
      later: next.length > 1 ? next.sublist(1) : const [],
    );
  }
}

/// The week's to-do: next Saturday's prep, sent or not, with one big button.
@visibleForTesting
class PrepTodoCard extends StatelessWidget {
  const PrepTodoCard({
    super.key,
    required this.date,
    required this.prep,
    required this.onOpen,
  });

  final DateTime date;
  final LessonPrep? prep;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sent = prep != null;
    final color = sent ? prepStatusColor(prep!.status) : AppColors.coral;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                sent ? prepStatusIcon(prep!.status) : Icons.assignment_late,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppStrings.prepTodoTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${AppDateUtils.formatDayDate(date)} · '
                      '${sent ? prepStatusLabel(prep!.status) : AppStrings.prepTodoNotSent}',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.readable(color)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          sent
              ? OutlinedButton(
                  onPressed: onOpen,
                  child: Text(
                    prep!.isCommented
                        ? AppStrings.prepResend
                        : AppStrings.lessonPrepTitle,
                  ),
                )
              : FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text(AppStrings.prepTodoUpload),
                ),
        ],
      ),
    );
  }
}

/// «حضوري»: this servant's own Saturdays, month by month (newest first),
/// four small icons each, so "which Saturdays did I miss?" has an answer.
@visibleForTesting
class MyAttendanceCard extends StatelessWidget {
  const MyAttendanceCard({
    super.key,
    required this.held,
    required this.marks,
    this.activityDays = const [],
  });

  /// The Saturdays held so far.
  final List<DateTime> held;

  /// The نشاط ترفيهي ones among them (tagged).
  final List<DateTime> activityDays;
  final List<ServantAttendance> marks;

  static const _activities = <(String, IconData, Color, String)>[
    (
      'sunday_school',
      AppIcons.sundaySchool,
      AppColors.success,
      AppStrings.chipService
    ),
    (
      'servant_meeting',
      AppIcons.servantMeeting,
      AppColors.olive,
      AppStrings.servantMeetingShort
    ),
    ('mass', AppIcons.mass, AppColors.gold, AppStrings.massShort),
    (
      'confession',
      AppIcons.confession,
      AppColors.coral,
      AppStrings.confessionShort
    ),
  ];

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Widget build(BuildContext context) {
    final byDay = <String, Set<String>>{};
    for (final m in marks) {
      (byDay[_day(m.date)] ??= {}).add(m.activityType);
    }
    final days = [...held]..sort((a, b) => b.compareTo(a));
    final came = days.where((d) => (byDay[_day(d)] ?? const {}).isNotEmpty);

    return SectionCard(
      title: AppStrings.myAttendanceTitle,
      icon: Icons.event_available_rounded,
      accent: AppColors.success,
      collapsible: true,
      initiallyExpanded: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.myAttendanceOf(came.length, days.length),
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          // The key, once.
          Wrap(
            spacing: 10,
            children: [
              for (final a in _activities)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.$2, size: 14, color: a.$3),
                    const SizedBox(width: 3),
                    Text(a.$4,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                  ],
                ),
            ],
          ),
          const Divider(height: 16),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${d.day} ${AppDateUtils.monthName(d.month)}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (activityDays.any((a) => _day(a) == _day(d)))
                          const Padding(
                            padding: EdgeInsetsDirectional.only(start: 4),
                            child: Icon(Icons.celebration_rounded,
                                size: 14, color: AppColors.gold),
                          ),
                      ],
                    ),
                  ),
                  for (final a in _activities)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: _Dot(
                        icon: a.$2,
                        color: a.$3,
                        on: byDay[_day(d)]?.contains(a.$1) ?? false,
                        label: a.$4,
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

class _Dot extends StatelessWidget {
  const _Dot({
    required this.icon,
    required this.color,
    required this.on,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final bool on;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? color.withValues(alpha: 0.16) : Colors.transparent,
          border: Border.all(
            color: on
                ? color.withValues(alpha: 0.5)
                : AppColors.muted.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: on ? color : AppColors.muted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
