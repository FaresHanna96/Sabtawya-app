import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';
import '../auth/change_password_screen.dart';
import '../home/welcome_tour.dart';
import '../profile/my_profile_screen.dart';
import 'absence_alert_tile.dart';
import 'caller_id_tile.dart';

/// Asks first (warning about changes still waiting to sync), then signs out.
/// Shared by Settings and the profile header on المزيد.
Future<void> confirmLogout(BuildContext context) async {
  final waiting = context.read<SyncService>().pendingCount;
  final confirmed = await Ui.confirm(
    context,
    title: AppStrings.logout,
    message: waiting > 0
        ? AppStrings.confirmLogoutPending(waiting)
        : AppStrings.confirmLogout,
    confirmLabel: AppStrings.logout,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await context.read<SessionController>().signOut();
}

/// Settings in clear groups: the profile on top, then الحساب, التطبيق and,
/// for the admin only, تنبيهات الغياب and سنة الحضور.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen),
      );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.profile;
    final year = session.currentYear;
    final name = profile?.fullName ?? session.displayName;
    final email = profile?.email;
    final who = [
      if (profile != null) profile.roleLabel,
      if (email != null && email.isNotEmpty) email,
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: staggerAll([
            _ProfileCard(
              name: name,
              subtitle: who,
              onTap: () => _push(context, const MyProfileScreen()),
            ),
            const _GroupTitle(AppStrings.account),
            _GroupCard(children: [
              _SettingsRow(
                icon: Icons.key_rounded,
                color: AppColors.gold,
                title: AppStrings.changePassword,
                onTap: () => _push(context, const ChangePasswordScreen()),
              ),
              _SettingsRow(
                icon: Icons.logout_rounded,
                color: AppColors.danger,
                title: AppStrings.logout,
                danger: true,
                onTap: () => confirmLogout(context),
              ),
            ]),
            const _GroupTitle(AppStrings.moreApp),
            _GroupCard(children: [
              const CallerIdTile(),
              _SettingsRow(
                icon: Icons.school_rounded,
                color: AppColors.navyLight,
                title: AppStrings.tourMenu,
                onTap: () => _push(context, const WelcomeTourScreen()),
              ),
            ]),
            if (session.isAdmin) ...[
              const _GroupTitle(AppStrings.absenceAlertSettings),
              const AbsenceAlertTile(),
            ],
            if (session.isAdmin && year != null) ...[
              const _GroupTitle('${AppStrings.attendanceYear} (للأمين)'),
              _GroupCard(children: [
                _SettingsRow(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.sky,
                  title: year.name,
                  subtitle: '${AppDateUtils.formatDate(year.startDate)}'
                      ' ← ${AppDateUtils.formatDate(year.endDate)}',
                  trailingText: '${year.sessionCount} سبت',
                ),
                _SettingsRow(
                  icon: Icons.star_rounded,
                  color: AppColors.gold,
                  title: AppStrings.maxPoints,
                  trailingText: '${year.maxPointsPerSession}',
                  bold: true,
                ),
              ]),
            ],
            const SizedBox(height: 20),
            const Center(
              child: Text(
                AppStrings.appTitle,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;

  static String _initial(String name) {
    final t = name.trim();
    return t.isEmpty ? '؟' : t.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppColors.navy,
                child: Text(
                  _initial(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const Text(
                AppStrings.edit,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const Icon(AppIcons.forward, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: AppColors.muted,
          ),
        ),
      );
}

/// A white card holding rows separated by hairlines.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// The coloured icon badge shared by every settings row.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, this.color, {super.key});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: color),
      );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.color,
    required this.title,
    this.onTap,
    this.trailingText,
    this.subtitle,
    this.danger = false,
    this.bold = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? trailingText;
  final bool danger;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SettingsIcon(icon, color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: danger ? AppColors.danger : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: TextStyle(
                  fontSize: bold ? 15 : 12.5,
                  fontWeight: bold ? FontWeight.w800 : null,
                  color: bold ? null : AppColors.muted,
                ),
              ),
            if (onTap != null && !danger)
              const Icon(AppIcons.forward, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
