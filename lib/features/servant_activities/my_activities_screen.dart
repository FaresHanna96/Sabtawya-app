import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/attendance.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import 'lesson_prep_screen.dart';
import 'servant_summary_card.dart';

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
    final yearId = session.currentYear?.id;

    final results = await Future.wait([
      _repo.sessionsForClasses(classIds, yearId: yearId),
      _repo.myLessonPreps(),
      // Only this servant's own records: the database allows no others.
      _repo.attendancesForServant(Db.userId!, 'sunday_school'),
      _repo.attendancesForServant(Db.userId!, 'servant_meeting'),
      _repo.attendancesForServant(Db.userId!, 'mass'),
      _repo.attendancesForServant(Db.userId!, 'confession'),
    ]);

    return _ActivitiesData(
      sessions: results[0] as List<AttendanceSession>,
      preps: results[1] as List<LessonPrep>,
      sundaySchool: (results[2] as List).length,
      servantMeeting: (results[3] as List).length,
      mass: (results[4] as List).length,
      confession: (results[5] as List).length,
    );
  }

  /// "عرض الكل" under the upcoming Saturdays.
  bool _showAllUpcoming = false;

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

            // Next Saturday first (the one to prepare), then the past ones
            // oldest first, then the rest of the year folded to three.
            final next = data.sessions
                .where((s) => !s.sessionDate.isBefore(today))
                .toList()
              ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
            final current = next.isEmpty ? null : next.first;
            final later =
                next.length > 1 ? next.sublist(1) : <AttendanceSession>[];
            final past = held
                .where((s) => current == null || s.id != current.id)
                .toList()
              ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
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
                FadeSlideIn(
                  child: ServantSummaryCard(
                    sundaySchool: data.sundaySchool,
                    servantMeeting: data.servantMeeting,
                    mass: data.mass,
                    confession: data.confession,
                    preps: data.preps.length,
                    pendingPreps:
                        data.preps.where((p) => p.status == 'pending').length,
                    heldSessions: held.map((s) => s.sessionDate).toSet().length,
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: _ProgressHeader(
                    submitted: submitted,
                    accepted: accepted,
                    total: total,
                  ),
                ),
                const SizedBox(height: 20),
                if (current != null) ...[
                  const _GroupTitle(
                    icon: Icons.event_rounded,
                    text: AppStrings.nextSaturdayTitle,
                  ),
                  card(current, highlight: true),
                  const SizedBox(height: 10),
                ],
                if (past.isNotEmpty) ...[
                  _GroupTitle(
                    icon: Icons.history_rounded,
                    text: '${AppStrings.pastSaturdays} (${past.length})',
                  ),
                  for (final s in past) card(s),
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
              color: color,
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
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (prep?.adminComment != null && prep!.adminComment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.comment_outlined,
                  size: 15,
                  color: AppColors.warning,
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

  static String _statusLabel(String status) => switch (status) {
        'accepted' => AppStrings.prepAccepted,
        'commented' => AppStrings.prepCommented,
        _ => AppStrings.prepPending,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'accepted' => Icons.check_circle_outline,
        'commented' => Icons.comment_outlined,
        _ => Icons.hourglass_empty_outlined,
      };

  static Color _statusColor(String status) => switch (status) {
        'accepted' => AppColors.success,
        'commented' => AppColors.warning,
        _ => AppColors.muted,
      };
}

// ---------------------------------------------------------------------------

class _ActivitiesData {
  const _ActivitiesData({
    required this.sessions,
    required this.preps,
    required this.sundaySchool,
    required this.servantMeeting,
    required this.mass,
    required this.confession,
  });

  final List<AttendanceSession> sessions;
  final List<LessonPrep> preps;
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
