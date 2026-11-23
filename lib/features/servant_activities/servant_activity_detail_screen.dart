import '../../core/widgets/image_viewer.dart';
import 'package:flutter/material.dart';

import 'prep_review_sheet.dart';
import 'servant_summary_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/file_fallback.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import 'servant_badges.dart';
import 'servant_covers.dart';
import 'servant_year.dart';

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

  final _sectionKey = GlobalKey<AsyncSectionState<_DetailData>>();

  /// The data last shown, for the «تقرير الشهر» action.
  _DetailData? _shown;

  /// Whether they serve a class (preps expected) and their mobile; best
  /// effort, the page works without them.
  Future<(bool, String?, Map<String, String>)> _servantInfo() async {
    try {
      final r = await Future.wait([
        const ClassRepository().classesOfServant(widget.servantId),
        const ServantRepository().servants(),
      ]);
      final classes = r[0] as List;
      final me = (r[1] as List<Profile>)
          .where((p) => p.id == widget.servantId)
          .firstOrNull;
      return (
        classes.isNotEmpty,
        me?.mobile,
        {for (final p in r[1] as List<Profile>) p.id: p.fullName},
      );
    } catch (_) {
      return (false, null, const <String, String>{});
    }
  }

  Future<_DetailData> _load() async {
    final year = context.read<SessionController>().currentYear;
    final yearId = year?.id;
    final info = _servantInfo();
    final subs = _repo
        .substitutesForServant(
          widget.servantId,
          from: year?.startDate,
          to: year?.endDate,
        )
        .catchError((Object _) => const <ServantSubstitute>[]);

    // This year only: the summary divides by this year's Saturdays.
    Future<List<ServantAttendance>> marks(String type) =>
        _repo.attendancesForServant(
          widget.servantId,
          type,
          from: year?.startDate,
          to: year?.endDate,
        );

    final results = await Future.wait([
      _repo.prepsForServant(widget.servantId),
      marks('sunday_school'),
      marks('servant_meeting'),
      marks('mass'),
      marks('confession'),
      // One row per Saturday of the year (no-lesson days left out): a
      // servant is marked per date, so a class servant and a خادم عام (no
      // class) get the same list.
      yearId == null
          ? Future.value(const <DateTime>[])
          : _repo.sessionDatesForYear(yearId),
    ]);
    return _DetailData(
      preps: results[0] as List<LessonPrep>,
      sundaySchool: results[1] as List<ServantAttendance>,
      servantMeeting: results[2] as List<ServantAttendance>,
      mass: results[3] as List<ServantAttendance>,
      confession: results[4] as List<ServantAttendance>,
      dates: _heldNewestFirst(results[5] as List<DateTime>),
      isClassServant: (await info).$1,
      mobile: (await info).$2,
      names: (await info).$3,
      subs: await subs,
    );
  }

  /// Saturdays already held, the latest first.
  static List<DateTime> _heldNewestFirst(List<DateTime> dates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (final d in dates)
        if (!d.isAfter(today)) d,
    ]..sort((a, b) => b.compareTo(a));
  }

  /// Marks being saved, by "date|type": only that chip waits.
  final _saving = <String>{};

  /// Shows the change at once and saves it; a refusal puts it back.
  Future<void> _toggle(_DetailData data, DateTime date, String type) async {
    final key = '${_DetailData._key(date)}|$type';
    if (!_saving.add(key)) return;
    final list = data.listFor(type);
    final existing = data.findIn(list, date);
    final placeholder = ServantAttendance(
      id: '',
      servantId: widget.servantId,
      activityType: type,
      date: date,
      recordedBy: '',
    );
    setState(() {
      if (existing != null) {
        list.remove(existing);
      } else {
        list.add(placeholder);
      }
    });
    try {
      if (existing != null) {
        await _repo.deleteAttendance(existing.id);
      } else {
        final saved = await _repo.recordAttendance(
          servantId: widget.servantId,
          activityType: type,
          date: date,
        );
        if (mounted) {
          setState(() {
            final i = list.indexOf(placeholder);
            if (i >= 0) list[i] = saved;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (existing != null) {
            list.add(existing);
          } else {
            list.remove(placeholder);
          }
        });
        Ui.error(context, e);
      }
    } finally {
      _saving.remove(key);
    }
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

  ServantYear _year(_DetailData data) => ServantYear(
        heldSaturdays: data.dates,
        marks: [
          ...data.sundaySchool,
          ...data.servantMeeting,
          ...data.mass,
          ...data.confession,
        ],
        preps: data.preps,
        today: DateTime.now(),
        classServantIds: {if (data.isClassServant) widget.servantId},
      );

  void _openReport() {
    final data = _shown;
    if (data == null) return;
    final year = _year(data);
    final now = DateTime.now();
    ServantMonthReport report(DateTime month) {
      final preps = data.preps
          .where((p) =>
              p.sessionDate.year == month.year &&
              p.sessionDate.month == month.month)
          .toList();
      return ServantMonthReport.of(
        year,
        widget.servantId,
        month,
        prepsSent: preps.length,
        prepsAccepted: preps.where((p) => p.isAccepted).length,
      );
    }

    showServantReportSheet(
      context,
      servantName: widget.servantName,
      mobile: data.mobile,
      thisMonth: report(DateTime(now.year, now.month)),
      lastMonth: report(DateTime(now.year, now.month - 1)),
    );
  }

  Widget _summary(_DetailData data) {
    // The Saturdays already held (one per date).
    final held = data.dates.length;
    // The list below keeps every prep; the counts are this year's only.
    final year = context.read<SessionController>().currentYear;
    final preps = year == null
        ? data.preps
        : data.preps.where((p) => year.contains(p.sessionDate)).toList();
    return ServantSummaryCard(
      sundaySchool: data.sundaySchool.length,
      servantMeeting: data.servantMeeting.length,
      mass: data.mass.length,
      confession: data.confession.length,
      preps: preps.length,
      pendingPreps: preps.where((p) => p.isPending).length,
      heldSessions: held,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.servantName),
        actions: [
          IconButton(
            tooltip: AppStrings.monthReportTitle,
            icon: const Icon(Icons.summarize_outlined),
            onPressed: _openReport,
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncSection<_DetailData>(
          key: _sectionKey,
          load: _load,
          builder: (context, data, reload) {
            _shown = data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                _summary(data),
                const SizedBox(height: 12),
                ServantBadgesCard(
                  badges: _year(data).badges(widget.servantId),
                ),
                const SizedBox(height: 12),
                if (data.subs.isNotEmpty) ...[
                  ServantCoversCard(
                    servantId: widget.servantId,
                    subs: data.subs,
                    nameOf: (id) => data.names[id] ?? '',
                  ),
                  const SizedBox(height: 12),
                ],
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
                if (data.dates.isEmpty)
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
                  for (final date in data.dates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AttendanceSessionCard(
                        date: date,
                        sundaySchoolPresent: data.sundaySchoolFor(date) != null,
                        servantMeetingPresent:
                            data.servantMeetingFor(date) != null,
                        massPresent: data.massFor(date) != null,
                        confessionPresent: data.confessionFor(date) != null,
                        onToggleSundaySchool: () =>
                            _toggle(data, date, 'sunday_school'),
                        onToggleServantMeeting: () =>
                            _toggle(data, date, 'servant_meeting'),
                        onToggleMass: () => _toggle(data, date, 'mass'),
                        onToggleConfession: () =>
                            _toggle(data, date, 'confession'),
                      ),
                    ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            style: TextStyle(fontSize: 12, color: AppColors.readable(color)),
          ),
        ),
        trailing: const Icon(AppIcons.forward, color: AppColors.muted),
      ),
    );
  }

  static String _statusLabel(String status) => prepStatusLabel(status);

  static IconData _statusIcon(String status) => prepStatusIcon(status);

  static Color _statusColor(String status) => prepStatusColor(status);
}

// ---------------------------------------------------------------------------

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({
    required this.date,
    required this.sundaySchoolPresent,
    required this.servantMeetingPresent,
    required this.massPresent,
    required this.confessionPresent,
    required this.onToggleSundaySchool,
    required this.onToggleServantMeeting,
    required this.onToggleMass,
    required this.onToggleConfession,
  });

  final DateTime date;
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
                  AppDateUtils.formatDayDate(date),
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
                    label: AppStrings.chipService,
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
                  color: AppColors.readable(color),
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
    final comment = _commentController.text.trim().isEmpty
        ? null
        : _commentController.text.trim();
    if (status == 'commented' && comment == null) {
      Ui.info(context, AppStrings.commentRequired);
      return;
    }
    Navigator.of(context).pop();
    await widget.onReview(status, comment);
  }

  static String _statusLabel(String status) => prepStatusLabel(status);

  static Color _statusColor(String status) => prepStatusColor(status);
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
    // A PDF is not an image: show a card that opens it.
    if (widget.storagePath.toLowerCase().endsWith('.pdf')) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined,
              color: AppColors.danger),
          title: Text(widget.storagePath.split('/').last,
              style: const TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(Uri.parse(_url!)),
        ),
      );
    }
    return GestureDetector(
      onTap: () => showZoomableImage(context, _url!),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _url!,
                fit: BoxFit.contain,
                // A PDF stored under a picture's name: offer to open it.
                errorBuilder: (_, __, ___) => FileFallbackCard(url: _url),
              ),
            ),
          ),
          // Hint that the picture opens full screen.
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
          ),
        ],
      ),
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
    required this.dates,
    this.isClassServant = false,
    this.mobile,
    this.names = const {},
    this.subs = const [],
  });

  final Map<String, String> names;
  final List<ServantSubstitute> subs;

  final bool isClassServant;
  final String? mobile;

  final List<LessonPrep> preps;
  final List<ServantAttendance> sundaySchool;
  final List<ServantAttendance> servantMeeting;
  final List<ServantAttendance> mass;
  final List<ServantAttendance> confession;

  /// The Saturdays held so far, the latest first (one per date).
  final List<DateTime> dates;

  List<ServantAttendance> listFor(String type) => switch (type) {
        'sunday_school' => sundaySchool,
        'servant_meeting' => servantMeeting,
        'mass' => mass,
        _ => confession,
      };

  ServantAttendance? findIn(List<ServantAttendance> list, DateTime date) =>
      _find(list, date);

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
