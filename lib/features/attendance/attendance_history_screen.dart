import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/date_granularity_filter.dart';
import '../../data/models/attendance.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../state/session_controller.dart';
import 'attendance_screen.dart';

/// The Saturdays of the year for one class, earliest first, with what was
/// recorded on each. Tapping a Saturday opens it for editing.
///
/// Saturdays that have not happened yet are hidden by default: the year holds
/// 49 of them. Upcoming dates, when shown, stay chronological so the next
/// Saturday is at the top rather than under months of empty future ones.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key, this.initialClassId});

  final String? initialClassId;

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  static const _repository = AttendanceRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<SessionSummary>>>();

  String? _classId;

  /// When on, Saturdays with no records yet are hidden.
  bool _recordedOnly = false;

  /// When on, the rest of the year's calendar is shown as well.
  bool _showUpcoming = false;

  DateGranularity? _granularity;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    final classes = context.read<SessionController>().myClasses;
    _classId = widget.initialClassId ??
        (classes.isEmpty ? null : classes.first.classId);
  }

  Future<List<SessionSummary>> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    final classId = _classId;
    if (yearId == null || classId == null) return <SessionSummary>[];
    return _repository.sessionSummaries(classId: classId, yearId: yearId);
  }

  Future<void> _reload() => _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _open(SessionSummary summary) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(
          showAppBar: true,
          initialClassId: summary.classId,
          initialDate: summary.sessionDate,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final classes = session.myClasses;
    final maxPerSession = session.currentYear?.maxPointsPerSession ?? 20;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.attendanceHistory)),
      body: SafeArea(
        child: Column(
          children: [
            _controls(classes),
            Expanded(
              child: AsyncSection<List<SessionSummary>>(
                key: _sectionKey,
                load: _load,
                builder: (context, all, reload) {
                  final today = AppDateUtils.dateOnly(DateTime.now());

                  final visible = all
                      .where(
                        (item) {
                          bool passes;
                          if (_showUpcoming && _recordedOnly) {
                            // Union: upcoming unrecorded + all recorded.
                            passes = (item.sessionDate.isAfter(today) &&
                                    !item.hasData) ||
                                item.hasData;
                          } else if (_showUpcoming) {
                            passes = item.sessionDate.isAfter(today);
                          } else if (_recordedOnly) {
                            passes = item.hasData;
                          } else {
                            // Default: past + any future that already has data.
                            passes = !item.sessionDate.isAfter(today) ||
                                item.hasData;
                          }
                          return passes &&
                              DateGranularityFilter.matchesFilter(
                                date: item.sessionDate,
                                granularity: _granularity,
                                from: _filterFrom,
                                to: _filterTo,
                              );
                        },
                      )
                      .toList()
                    ..sort((a, b) {
                      final aUpcoming =
                          a.sessionDate.isAfter(today) && !a.hasData;
                      final bUpcoming =
                          b.sessionDate.isAfter(today) && !b.hasData;
                      if (aUpcoming != bUpcoming) return aUpcoming ? 1 : -1;
                      if (aUpcoming) {
                        return a.sessionDate.compareTo(b.sessionDate);
                      }
                      return b.sessionDate.compareTo(a.sessionDate);
                    });

                  // Dates used as picker options.
                  final allDates = all.map((s) => s.sessionDate).toList()
                    ..sort();

                  final isFiltered =
                      _granularity != null &&
                      (_filterFrom != null || _filterTo != null);

                  // Total score when a filter is active.
                  final totalPoints =
                      isFiltered
                          ? visible.fold(0, (s, r) => s + r.points)
                          : 0;
                  final maxTotalPoints =
                      isFiltered
                          ? visible.fold(
                              0,
                              (s, r) => s + r.activeChildren * maxPerSession,
                            )
                          : 0;

                  return Column(
                    children: [
                      if (allDates.isNotEmpty)
                        DateGranularityFilter(
                          availableDates: allDates,
                          initialGranularity: _granularity,
                          onChanged: (g, from, to) => setState(() {
                            _granularity = g;
                            _filterFrom = from;
                            _filterTo = to;
                          }),
                        ),
                      if (isFiltered)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                          child: Row(
                            children: [
                              Text(
                                AppStrings.pointsInPeriod,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                              const Spacer(),
                              ScoreChip(
                                score: totalPoints,
                                maxScore: maxTotalPoints,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      if (visible.isEmpty)
                        Expanded(
                          child: ListView(
                            children: const [
                              SizedBox(height: 40),
                              EmptyState(
                                icon: Icons.event_busy_outlined,
                                title: AppStrings.noSessionsTitle,
                                body: AppStrings.noSessionsBody,
                              ),
                            ],
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => _SummaryTile(
                              summary: visible[index],
                              maxPerSession: maxPerSession,
                              onTap: () => _open(visible[index]),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(List<ClassOverview> classes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (classes.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _classId,
              isDense: true,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: AppStrings.classLabel),
              items: classes
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item.classId,
                      child: Text(item.className),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || value == _classId) return;
                setState(() => _classId = value);
                _reload();
              },
            )
          else if (classes.isNotEmpty)
            Text(
              classes.first.className,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              FilterChip(
                label: const Text(AppStrings.recordedOnly),
                selected: _recordedOnly,
                onSelected: (value) => setState(() => _recordedOnly = value),
              ),
              FilterChip(
                label: const Text(AppStrings.showUpcoming),
                selected: _showUpcoming,
                onSelected: (value) => setState(() => _showUpcoming = value),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.summary,
    required this.maxPerSession,
    required this.onTap,
  });

  final SessionSummary summary;
  final int maxPerSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxPoints = summary.activeChildren * maxPerSession;
    final future = summary.sessionDate.isAfter(
      AppDateUtils.dateOnly(DateTime.now()),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          summary.isLocked
              ? Icons.lock_outline
              : summary.hasData
                  ? Icons.event_available_outlined
                  : Icons.event_note_outlined,
          color: summary.hasData ? AppColors.olive : AppColors.muted,
        ),
        title: Text(
          AppDateUtils.formatDayDate(summary.sessionDate),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          future && !summary.hasData
              ? AppStrings.nextAttendance
              : '${AppStrings.presentCount} ${summary.presentCount}/${summary.activeChildren}'
                  ' • ${AppStrings.recordedCount} ${summary.recordedCount}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: summary.hasData
            ? ScoreChip(score: summary.points, maxScore: maxPoints, compact: true)
            : null,
      ),
    );
  }
}
