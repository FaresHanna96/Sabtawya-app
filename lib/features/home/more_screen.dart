import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_history_screen.dart';
import '../children/birthday_screen.dart';
import '../attendance/attendance_years_screen.dart';
import '../excel/export_screen.dart';
import '../excel/import_children_screen.dart';
import '../reports/reports_screen.dart';
import '../servants/pending_requests_screen.dart';
import '../servants/servant_assignments_screen.dart';
import '../servants/servants_screen.dart';
import '../competitions/competitions_screen.dart';
import '../settings/settings_screen.dart';

/// The hub for everything that does not deserve its own tab.
///
/// Admin-only entries are hidden for a servant, but the policies are what
/// actually stop the writes: hiding the tile is a convenience, not the control.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text(AppStrings.more)) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            SectionCard(
              title: AppStrings.reportsTitle,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  _Entry(
                    icon: Icons.insert_chart_outlined,
                    title: AppStrings.reportsTitle,
                    screen: const ReportsScreen(),
                  ),
                  _Entry(
                    icon: Icons.history,
                    title: AppStrings.attendanceHistory,
                    screen: const AttendanceHistoryScreen(),
                  ),
                  _Entry(
                    icon: Icons.cake_outlined,
                    title: AppStrings.birthdaysTitle,
                    screen: const BirthdayScreen(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.importTitle,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  _Entry(
                    icon: Icons.upload_file,
                    title: AppStrings.importChildren,
                    screen: const ImportChildrenScreen(),
                  ),
                  _Entry(
                    icon: Icons.ios_share,
                    title: AppStrings.exportTitle,
                    screen: const ExportScreen(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.competitions,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: _Entry(
                icon: Icons.emoji_events_outlined,
                title: AppStrings.competitions,
                screen: const CompetitionsScreen(),
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.systemManagement,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: [
                    _Entry(
                      icon: Icons.how_to_reg_outlined,
                      title: AppStrings.pendingRequests,
                      screen: const PendingRequestsScreen(),
                    ),
                    _Entry(
                      icon: Icons.volunteer_activism_outlined,
                      title: AppStrings.servantsTitle,
                      screen: const ServantsScreen(),
                    ),
                    _Entry(
                      icon: Icons.link,
                      title: AppStrings.assignmentsTitle,
                      screen: const ServantAssignmentsScreen(),
                    ),
                    _Entry(
                      icon: Icons.calendar_month_outlined,
                      title: AppStrings.attendanceYears,
                      screen: const AttendanceYearsScreen(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.account,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: _Entry(
                icon: Icons.settings_outlined,
                title: AppStrings.settingsTitle,
                screen: const SettingsScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.title, required this.screen});

  final IconData icon;
  final String title;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.navy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.navy, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_left, color: AppColors.muted),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen),
      ),
    );
  }
}
