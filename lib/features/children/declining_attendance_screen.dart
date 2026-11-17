import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/reports.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import 'child_profile_screen.dart';

/// حضور في تراجع: children who still come but noticeably less than before
/// (25 points or more down over the last four Saturdays against the four
/// before). A servant sees only their own classes; the database filters.
class DecliningAttendanceScreen extends StatelessWidget {
  const DecliningAttendanceScreen({super.key});

  static const _reports = ReportRepository();

  Future<List<ChildTrend>> _load(BuildContext context) async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const [];
    return _reports.decliningChildren(yearId: yearId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.decliningAttendance)),
      body: SafeArea(
        child: AsyncSection<List<ChildTrend>>(
          load: () => _load(context),
          loading: const SkeletonList(),
          builder: (context, list, _) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 32),
                  EmptyState(
                    icon: Icons.trending_up_rounded,
                    title: AppStrings.decliningEmpty,
                    body: AppStrings.decliningEmptyBody,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final t = list[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.trending_down_rounded,
                        color: AppColors.danger),
                    title: Text(t.childName),
                    subtitle: Text(
                        '${t.className} · '
                        '${AppStrings.decliningLine(t.recentRate, t.previousRate)}'),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ChildProfileScreen(childId: t.childId),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
