import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';
import '../auth/change_password_screen.dart';
import '../profile/my_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.logout,
      message: AppStrings.confirmLogout,
      confirmLabel: AppStrings.logout,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: staggerAll([
            SectionCard(
              title: AppStrings.myProfile,
              icon: Icons.person_rounded,
              accent: AppColors.navyLight,
              child: Column(
                children: [
                  InfoRow(
                    label: AppStrings.servantName,
                    value: profile?.fullName,
                    icon: Icons.person_outline,
                  ),
                  InfoRow(
                    label: AppStrings.email,
                    value: profile?.email,
                    icon: Icons.alternate_email,
                  ),
                  InfoRow(
                    label: AppStrings.mobile,
                    value: profile?.mobile,
                    icon: Icons.phone_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.birthDate,
                    value: profile?.birthDate == null
                        ? null
                        : AppDateUtils.formatDate(profile!.birthDate!),
                    icon: Icons.cake_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.role,
                    value: profile?.roleLabel,
                    icon: Icons.shield_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.assignedClasses,
                    value: session.myClasses.isEmpty
                        ? null
                        : session.myClasses
                            .map((item) => item.className)
                            .join('، '),
                    icon: Icons.class_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.attendanceYear,
              icon: Icons.calendar_month_rounded,
              accent: AppColors.olive,
              child: Column(
                children: [
                  InfoRow(
                    label: AppStrings.yearName,
                    value: session.currentYear?.name,
                    icon: Icons.calendar_month_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.startDate,
                    value: session.currentYear == null
                        ? null
                        : AppDateUtils.formatDate(
                            session.currentYear!.startDate,
                          ),
                    icon: Icons.play_arrow_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.endDate,
                    value: session.currentYear == null
                        ? null
                        : AppDateUtils.formatDate(session.currentYear!.endDate),
                    icon: Icons.stop_outlined,
                  ),
                  InfoRow(
                    label: AppStrings.maxPoints,
                    value: session.currentYear == null
                        ? null
                        : '${session.currentYear!.maxPointsPerSession} '
                            '${AppStrings.points}',
                    icon: Icons.star_outline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.about,
              icon: Icons.info_rounded,
              accent: AppColors.gold,
              child: Column(
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              AppStrings.appTitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              AppStrings.appSubtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: AppStrings.account,
              icon: Icons.lock_rounded,
              accent: AppColors.maroon,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: const Text(AppStrings.myData),
                    trailing: const Icon(AppIcons.forward),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MyProfileScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: const Text(AppStrings.changePassword),
                    trailing: const Icon(AppIcons.forward),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text(AppStrings.logout),
            ),
          ]),
        ),
      ),
    );
  }
}
