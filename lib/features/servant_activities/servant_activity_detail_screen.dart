import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/attendance.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';

/// Admin view of one servant's activities: lesson preps + two attendance types.
class ServantActivityDetailScreen extends StatefulWidget {
  const ServantActivityDetailScreen({
    super.key,
    required this.servantId,
    required this.servantName,
  });

  final String servantId;
  final String servantName;

  @override
  State<ServantActivityDetailScreen> createState() =>
      _ServantActivityDetailScreenState();
}

class _ServantActivityDetailScreenState
    extends State<ServantActivityDetailScreen> {
  static const _repo = ServantActivityRepository();
  static const _classRepo = ClassRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_DetailData>>();

  Future<_DetailData> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    final assignments = await _classRepo.classesOfServant(widget.servantId);
    final classIds = assignments.map((a) => a.classId).toList();

    final results = await Future.wait([
      _repo.prepsForServant(widget.servantId),
      _repo.attendancesForServant(widget.servantId, 'sunday_school'),
      _repo.attendancesForServant(widget.servantId, 'servant_meeting'),
      _repo.attendancesForServant(widget.servantId, 'mass'),
      _repo.attendancesForServant(widget.servantId, 'confession'),
      _repo.sessionsForClasses(classIds, yearId: yearId),
    ]);
    return _DetailData(
      preps: results[0] as List<LessonPrep>,
      sundaySchool: results[1] as List<ServantAttendance>,
      servantMeeting: results[2] as List<ServantAttendance>,
      mass: results[3] as List<ServantAttendance>,
      confession: results[4] as List<ServantAttendance>,
      sessions: results[5] as List<AttendanceSession>,
    );
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _reviewPrep(LessonPrep prep) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewSheet(
        prep: prep,
        onReview: (status, comment) async {
          final ok = await Ui.runGuarded(
            context,
            () => _repo.reviewPrep(
              prepId: prep.id,
              status: status,
              comment: comment,
            ),
            successMessage: AppStrings.reviewedSuccessfully,
          );
          if (ok) await _reload();
        },
      ),
    );
  }

  Future<void> _toggleAttendance(
    AttendanceSession session,
    String activityType,
    ServantAttendance? existing,
  ) async {
    if (existing != null) {
      final ok = await Ui.runGuarded(
        context,
        () => _repo.deleteAttendance(existing.id),
        successMessage: AppStrings.saved,
      );
      if (ok) await _reload();
    } else {
      final ok = await Ui.runGuarded(
        context,
        () => _repo.recordAttendance(
          servantId: widget.servantId,
          activityType: activityType,
          date: session.sessionDate,
        ),
        successMessage: AppStrings.saved,
      );
      if (ok) await _reload();
    }
  }

  Widget _summary(_DetailData data) {
    final pending = data.preps.where((p) => p.status == 'pending').length;
    // Only sessions already held (one per date, whatever the class count).
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day);
    final total = data.sessions
        .where((x) => !x.sessionDate.isAfter(cutoff))
        .map((x) => x.sessionDate)
        .toSet()
        .length;

    String pct(int n) => total == 0 ? '' : ' (${(n / total * 100).round()}%)';

    Widget row(Widget a, Widget b) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: a),
              const SizedBox(width: 8),
              Expanded(child: b),
            ],
          ),
        );

    return SectionCard(
      title: AppStrings.servantActivityReport,
      icon: Icons.insert_chart_rounded,
      accent: AppColors.navy,
      child: Column(
        children: [
          row(
            StatTile(
              label: '${AppStrings.sundaySchoolShort}${pct(data.sundaySchool.length)}',
              value: '${data.sundaySchool.length}/$total',
              color: AppColors.success,
              icon: Icons.church_outlined,
            ),
            StatTile(
              label: '${AppStrings.servantMeetingShort}${pct(data.servantMeeting.length)}',
              value: '${data.servantMeeting.length}/$total',
              color: AppColors.success,
              icon: Icons.groups_outlined,
            ),
          ),
          row(
            StatTile(
              label: '${AppStrings.mass}${pct(data.mass.length)}',
              value: '${data.mass.length}/$total',
              color: AppColors.gold,
              icon: Icons.account_balance_outlined,
            ),
            StatTile(
              label: '${AppStrings.confession}${pct(data.confession.length)}',
              value: '${data.confession.length}/$total',
              color: AppColors.coral,
              icon: Icons.volunteer_activism_outlined,
            ),
          ),
          row(
            StatTile(
              label: AppStrings.lessonPrep,
              value: '${data.preps.length}',
              color: AppColors.navy,
              icon: Icons.assignment_outlined,
            ),
            StatTile(
              label: AppStrings.prepPending,
              value: '$pending',
              color: pending > 0 ? AppColors.warning : AppColors.muted,
              icon: Icons.hourglass_empty_outlined,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.servantName)),
      body: SafeArea(
        child: AsyncSection<_DetailData>(
          key: _sectionKey,
          load: _load,
          builder: (context, data, reload) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                _summary(data),
                const SizedBox(height: 12),
                // ------------------------------------------------- Lesson Prep
                _SectionHeader(title: AppStrings.lessonPrep),
                const SizedBox(height: 8),
                if (data.preps.isEmpty)
                  const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: AppStrings.noLessonPreps,
                    body: AppStrings.noLessonPrepsBody,
                  )
                else
                  ...data.preps.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PrepRow(prep: p, onTap: () => _reviewPrep(p)),
                    ),
                  ),
                const SizedBox(height: 4),
                // ------------------------------------------ Attendance sessions
                _SectionHeader(title: AppStrings.attendanceTitle),
                const SizedBox(height: 8),
                if (data.sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      AppStrings.noAttendanceRecords,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  )
                else
                  ...data.sessions.map((session) {
                    final sundayRec = data.sundaySchoolFor(session.sessionDate);
                    final meetingRec =
                        data.servantMeetingFor(session.sessionDate);
                    final massRec = data.massFor(session.sessionDate);
                    final confessionRec =
                        data.confessionFor(session.sessionDate);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AttendanceSessionCard(
                        session: session,
                        sundaySchoolPresent: sundayRec != null,
                        servantMeetingPresent: meetingRec != null,
                        massPresent: massRec != null,
                        confessionPresent: confessionRec != null,
                        onToggleSundaySchool: () => _toggleAttendance(
                          session,
                          'sunday_school',
                          sundayRec,
                        ),
                        onToggleServantMeeting: () => _toggleAttendance(
                          session,
                          'servant_meeting',
                          meetingRec,
                        ),
                        onToggleMass: () => _toggleAttendance(
                          session,
                          'mass',
                          massRec,
                        ),
                        onToggleConfession: () => _toggleAttendance(
                          session,
                          'confession',
                          confessionRec,
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PrepRow extends StatelessWidget {
  const _PrepRow({required this.prep, required this.onTap});

  final LessonPrep prep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(prep.status);
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_statusIcon(prep.status), size: 22, color: color),
        ),
        title: Text(
          AppDateUtils.formatDayDate(prep.sessionDate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            _statusLabel(prep.status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppColors.muted),
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

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({
    required this.session,
    required this.sundaySchoolPresent,
    required this.servantMeetingPresent,
    required this.massPresent,
    required this.confessionPresent,
    required this.onToggleSundaySchool,
    required this.onToggleServantMeeting,
    required this.onToggleMass,
    required this.onToggleConfession,
  });

  final AttendanceSession session;
  final bool sundaySchoolPresent;
  final bool servantMeetingPresent;
  final bool massPresent;
  final bool confessionPresent;
  final VoidCallback onToggleSundaySchool;
  final VoidCallback onToggleServantMeeting;
  final VoidCallback onToggleMass;
  final VoidCallback onToggleConfession;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppDateUtils.formatDayDate(session.sessionDate),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActivityToggle(
                    label: AppStrings.sundaySchoolShort,
                    present: sundaySchoolPresent,
                    onTap: onToggleSundaySchool,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActivityToggle(
                    label: AppStrings.servantMeetingShort,
                    present: servantMeetingPresent,
                    onTap: onToggleServantMeeting,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActivityToggle(
                    label: AppStrings.massShort,
                    present: massPresent,
                    onTap: onToggleMass,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActivityToggle(
                    label: AppStrings.confessionShort,
                    present: confessionPresent,
                    onTap: onToggleConfession,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ActivityToggle extends StatelessWidget {
  const _ActivityToggle({
    required this.label,
    required this.present,
    required this.onTap,
  });

  final String label;
  final bool present;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = present ? AppColors.success : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: present ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: present ? 0.5 : 0.25),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              present ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review bottom sheet
// ---------------------------------------------------------------------------

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.prep, required this.onReview});

  final LessonPrep prep;
  final Future<void> Function(String status, String? comment) onReview;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _commentController = TextEditingController();
  int _photoPage = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prep = widget.prep;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppDateUtils.formatDayDate(prep.sessionDate),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _statusLabel(prep.status),
              style: TextStyle(
                fontSize: 13,
                color: _statusColor(prep.status),
              ),
            ),
            // Photos
            if (prep.photos.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: PageView.builder(
                  itemCount: prep.photos.length,
                  onPageChanged: (i) => setState(() => _photoPage = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _StorageImage(
                      storagePath: prep.photos[i].storagePath,
                    ),
                  ),
                ),
              ),
              if (prep.photos.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < prep.photos.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _photoPage == i
                              ? AppColors.navy
                              : AppColors.muted.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
            ],
            // Admin comment field
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: AppStrings.addComment,
                hintText: AppStrings.enterComment,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submit('commented'),
                    icon: const Icon(Icons.comment_outlined, size: 18),
                    label: const Text(AppStrings.addComment),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _submit('accepted'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(AppStrings.acceptPrep),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(String status) async {
    final comment =
        _commentController.text.trim().isEmpty ? null : _commentController.text.trim();
    if (status == 'commented' && comment == null) {
      Ui.info(context, AppStrings.commentRequired);
      return;
    }
    Navigator.of(context).pop();
    await widget.onReview(status, comment);
  }

  static String _statusLabel(String status) => switch (status) {
        'accepted' => AppStrings.prepAccepted,
        'commented' => AppStrings.prepCommented,
        _ => AppStrings.prepPending,
      };

  static Color _statusColor(String status) => switch (status) {
        'accepted' => AppColors.success,
        'commented' => AppColors.warning,
        _ => AppColors.muted,
      };
}

// ---------------------------------------------------------------------------

class _StorageImage extends StatefulWidget {
  const _StorageImage({required this.storagePath});

  final String storagePath;

  @override
  State<_StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<_StorageImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    PhotoService.signedUrl(
      bucket: Db.bucketServantSubmissions,
      path: widget.storagePath,
    ).then((url) {
      if (mounted) setState(() => _url = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(_url!, fit: BoxFit.contain),
    );
  }
}

class _DetailData {
  const _DetailData({
    required this.preps,
    required this.sundaySchool,
    required this.servantMeeting,
    required this.mass,
    required this.confession,
    required this.sessions,
  });

  final List<LessonPrep> preps;
  final List<ServantAttendance> sundaySchool;
  final List<ServantAttendance> servantMeeting;
  final List<ServantAttendance> mass;
  final List<ServantAttendance> confession;
  final List<AttendanceSession> sessions;

  ServantAttendance? sundaySchoolFor(DateTime date) =>
      _find(sundaySchool, date);
  ServantAttendance? servantMeetingFor(DateTime date) =>
      _find(servantMeeting, date);
  ServantAttendance? massFor(DateTime date) => _find(mass, date);
  ServantAttendance? confessionFor(DateTime date) => _find(confession, date);

  ServantAttendance? _find(List<ServantAttendance> list, DateTime date) {
    final key = _key(date);
    for (final a in list) {
      if (_key(a.date) == key) return a;
    }
    return null;
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
