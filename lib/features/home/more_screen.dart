import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_history_screen.dart';
import '../calendar/calendar_screen.dart';
import '../children/birthday_screen.dart';
import '../attendance/attendance_years_screen.dart';
import '../excel/export_screen.dart';
import '../excel/import_children_screen.dart';
import '../reports/reports_screen.dart';
import '../servants/servant_assignments_screen.dart';
import '../servants/servants_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../settings/settings_screen.dart';
import '../lessons/lesson_schedule_screen.dart';
import '../sync/sync_screen.dart';

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
    final isGeneralServant = session.isGeneralServant;

    return Scaffold(
      appBar: showAppBar ? AppBar(title: const Text(AppStrings.more)) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: staggerAll([
            SectionCard(
              title: AppStrings.reportsTitle,
              icon: Icons.insights_rounded,
              accent: AppColors.sky,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  _Entry(
                    icon: Icons.insert_chart_outlined,
                    title: AppStrings.reportsTitle,
                    screen: const ReportsScreen(),
                    color: AppColors.sky,
                  ),
                  _Entry(
                    icon: Icons.history,
                    title: AppStrings.attendanceHistory,
                    screen: const AttendanceHistoryScreen(),
                    color: AppColors.navyLight,
                  ),
                  _Entry(
                    icon: Icons.cake_outlined,
                    title: AppStrings.birthdaysTitle,
                    screen: const BirthdayScreen(),
                    color: AppColors.coral,
                  ),
                  _Entry(
                    icon: Icons.calendar_month_outlined,
                    title: AppStrings.calendarTitle,
                    screen: const CalendarScreen(),
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
            if (!isGeneralServant) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.importTitle,
                icon: Icons.swap_vert_rounded,
                accent: AppColors.navyLight,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: [
                    _Entry(
                      icon: Icons.upload_file,
                      title: AppStrings.importChildren,
                      screen: const ImportChildrenScreen(),
                      color: AppColors.navyLight,
                    ),
                    _Entry(
                      icon: Icons.ios_share,
                      title: AppStrings.exportTitle,
                      screen: const ExportScreen(),
                      color: AppColors.navyLight,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.competitions,
              icon: Icons.emoji_events_rounded,
              accent: AppColors.gold,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: _Entry(
                icon: Icons.emoji_events_outlined,
                title: AppStrings.competitions,
                screen: const CompetitionsScreen(),
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.events,
              icon: Icons.celebration_rounded,
              accent: AppColors.olive,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: _Entry(
                icon: Icons.event_outlined,
                title: AppStrings.events,
                screen: const EventsScreen(),
                color: AppColors.olive,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.systemManagement,
                icon: Icons.admin_panel_settings_rounded,
                accent: AppColors.maroon,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Column(
                  children: [
                    _Entry(
                      icon: Icons.volunteer_activism_outlined,
                      title: AppStrings.servantsTitle,
                      screen: const ServantsScreen(),
                      color: AppColors.maroon,
                    ),
                    _Entry(
                      icon: Icons.link,
                      title: AppStrings.assignmentsTitle,
                      screen: const ServantAssignmentsScreen(),
                      color: AppColors.maroon,
                    ),
                    _Entry(
                      icon: Icons.calendar_month_outlined,
                      title: AppStrings.attendanceYears,
                      screen: const AttendanceYearsScreen(),
                      color: AppColors.maroon,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.account,
              icon: Icons.person_rounded,
              accent: AppColors.muted,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                children: [
                  _Entry(
                    icon: Icons.menu_book_outlined,
                    title: AppStrings.lessonSchedule,
                    screen: const LessonScheduleScreen(),
                    color: AppColors.olive,
                  ),
                  _Entry(
                    icon: Icons.sync_rounded,
                    title: AppStrings.syncTitle,
                    screen: const SyncScreen(),
                    color: AppColors.sky,
                  ),
                  _Entry(
                    icon: Icons.settings_outlined,
                    title: AppStrings.settingsTitle,
                    screen: const SettingsScreen(),
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.screen,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final String title;
  final Widget screen;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
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
