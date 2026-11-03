import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../state/session_controller.dart';

/// Report showing per-servant prep and attendance stats for the current year.
class ServantActivitiesReportScreen extends StatefulWidget {
  const ServantActivitiesReportScreen({super.key});

  @override
  State<ServantActivitiesReportScreen> createState() =>
      _ServantActivitiesReportScreenState();
}

class _ServantActivitiesReportScreenState
    extends State<ServantActivitiesReportScreen> {
  static const _repo = ServantActivityRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ReportData>>();

  Future<_ReportData> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    final results = await Future.wait([
      _repo.activitySummaries(),
      yearId != null ? _repo.sessionCountForYear(yearId) : Future.value(0),
    ]);
    return _ReportData(
      summaries: results[0] as List<ServantActivitySummary>,
      totalSessions: results[1] as int,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.servantActivityReport)),
      body: SafeArea(
        child: AsyncSection<_ReportData>(
          key: _sectionKey,
          load: _load,
          builder: (context, data, _) {
            if (data.summaries.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.06,
                  ),
                  const EmptyState(
                    icon: Icons.insert_chart_outlined,
                    title: AppStrings.noLessonPreps,
                    body: AppStrings.noLessonPrepsBody,
                  ),
                ],
              );
            }

            final totalSessions = data.totalSessions;
            final totalServants = data.summaries.length;
            final totalPreps =
                data.summaries.fold(0, (s, e) => s + e.totalPreps);
            final totalPending =
                data.summaries.fold(0, (s, e) => s + e.pendingPreps);
            final totalSunday =
                data.summaries.fold(0, (s, e) => s + e.sundaySchoolCount);
            final totalMeeting =
                data.summaries.fold(0, (s, e) => s + e.servantMeetingCount);
            final totalMass =
                data.summaries.fold(0, (s, e) => s + e.massCount);
            final totalConfession =
                data.summaries.fold(0, (s, e) => s + e.confessionCount);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // Summary header
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.servantActivityReport,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                label: 'إجمالي الخدام',
                                value: '$totalServants',
                                color: AppColors.navy,
                                icon: Icons.people_outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StatTile(
                                label: 'جلسات السنة',
                                value: '$totalSessions',
                                color: AppColors.olive,
                                icon: Icons.calendar_month_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                label: AppStrings.sundaySchoolShort,
                                value: '$totalSunday',
                                color: AppColors.success,
                                icon: Icons.church_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StatTile(
                                label: AppStrings.servantMeetingShort,
                                value: '$totalMeeting',
                                color: AppColors.success,
                                icon: Icons.groups_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                label: AppStrings.massShort,
                                value: '$totalMass',
                                color: AppColors.success,
                                icon: Icons.brightness_high_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StatTile(
                                label: AppStrings.confessionShort,
                                value: '$totalConfession',
                                color: AppColors.success,
                                icon: Icons.volunteer_activism_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                label: AppStrings.lessonPrep,
                                value: '$totalPreps',
                                color: AppColors.navy,
                                icon: Icons.assignment_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StatTile(
                                label: AppStrings.prepPending,
                                value: '$totalPending',
                                color: totalPending > 0
                                    ? AppColors.warning
                                    : AppColors.muted,
                                icon: Icons.hourglass_empty_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Per-servant breakdown
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'تفاصيل الخدام',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                ...data.summaries.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ServantReportRow(
                      summary: s,
                      totalSessions: totalSessions,
                    ),
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

class _ServantReportRow extends StatelessWidget {
  const _ServantReportRow({
    required this.summary,
    required this.totalSessions,
  });

  final ServantActivitySummary summary;
  final int totalSessions;

  String _pct(int count) {
    if (totalSessions == 0) return '—';
    return '${(count / totalSessions * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 20,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.servantName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (summary.pendingPreps > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${summary.pendingPreps} ${AppStrings.prepPending}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chip(
                  Icons.assignment_outlined,
                  AppStrings.lessonPrep,
                  '${summary.totalPreps}',
                  AppColors.navy,
                ),
                _chip(
                  Icons.church_outlined,
                  AppStrings.sundaySchoolShort,
                  '${summary.sundaySchoolCount} (${_pct(summary.sundaySchoolCount)})',
                  AppColors.success,
                ),
                _chip(
                  Icons.groups_outlined,
                  AppStrings.servantMeetingShort,
                  '${summary.servantMeetingCount} (${_pct(summary.servantMeetingCount)})',
                  AppColors.success,
                ),
                _chip(
                  Icons.brightness_high_outlined,
                  AppStrings.massShort,
                  '${summary.massCount} (${_pct(summary.massCount)})',
                  AppColors.success,
                ),
                _chip(
                  Icons.volunteer_activism_outlined,
                  AppStrings.confessionShort,
                  '${summary.confessionCount} (${_pct(summary.confessionCount)})',
                  AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.summaries,
    required this.totalSessions,
  });

  final List<ServantActivitySummary> summaries;
  final int totalSessions;
}
