import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/whatsapp_icon.dart';
import 'servant_day_widgets.dart' show servantDayActivities;
import 'servant_year.dart';

extension ServantBadgeLook on ServantBadge {
  String get title => switch (this) {
        ServantBadge.faithful => AppStrings.servantBadgeFaithful,
        ServantBadge.greatPrep => AppStrings.servantBadgeGreatPrep,
        ServantBadge.meeting => AppStrings.servantBadgeMeeting,
        ServantBadge.confession => AppStrings.servantBadgeConfession,
      };

  String get rule => switch (this) {
        ServantBadge.faithful => AppStrings.servantBadgeFaithfulRule,
        ServantBadge.greatPrep => AppStrings.servantBadgeGreatPrepRule,
        ServantBadge.meeting => AppStrings.servantBadgeMeetingRule,
        ServantBadge.confession => AppStrings.servantBadgeConfessionRule,
      };

  IconData get icon => switch (this) {
        ServantBadge.faithful => Icons.verified_rounded,
        ServantBadge.greatPrep => Icons.workspace_premium_rounded,
        ServantBadge.meeting => Icons.groups_rounded,
        ServantBadge.confession => Icons.favorite_rounded,
      };

  Color get color => switch (this) {
        ServantBadge.faithful => AppColors.navy,
        ServantBadge.greatPrep => AppColors.gold,
        ServantBadge.meeting => AppColors.olive,
        ServantBadge.confession => AppColors.coral,
      };
}

/// The servant's four badges, one row each: the badge in its own colour
/// (faded with a small lock until earned), its rule in words, and how far
/// along — so nothing needs a tap to be understood.
class ServantBadgesCard extends StatelessWidget {
  const ServantBadgesCard({super.key, required this.badges});

  final List<ServantBadgeState> badges;

  @override
  Widget build(BuildContext context) {
    final earned = badges.where((b) => b.earned).length;
    return SectionCard(
      title: AppStrings.badgesTitle,
      icon: Icons.military_tech_rounded,
      accent: AppColors.gold,
      trailing: Text(
        AppStrings.badgesOf(earned, badges.length),
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          for (final (i, b) in badges.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _BadgeRow(state: b),
          ],
        ],
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.state});

  final ServantBadgeState state;

  @override
  Widget build(BuildContext context) {
    final b = state.badge;
    final earned = state.earned;
    final color = b.color;
    final share = state.target <= 0
        ? 0.0
        : (state.progress / state.target).clamp(0, 1).toDouble();
    return Semantics(
      label: '${b.title}: ${earned ? AppStrings.badgeEarnedShort : AppStrings.progressOf(state.progress, state.target)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: earned
              ? color.withValues(alpha: 0.08)
              : AppColors.muted.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: earned
                ? color.withValues(alpha: 0.3)
                : AppColors.muted.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: earned ? 0.18 : 0.10),
                  ),
                  child: Icon(
                    b.icon,
                    size: 24,
                    color: earned ? color : color.withValues(alpha: 0.45),
                  ),
                ),
                if (!earned)
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded,
                          size: 11, color: AppColors.muted),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: earned ? AppColors.navy : AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    b.rule,
                    style: const TextStyle(
                        fontSize: 12, height: 1.35, color: AppColors.muted),
                  ),
                  if (!earned) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: share),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                backgroundColor:
                                    color.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.progressOf(state.progress, state.target),
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (earned)
              Icon(Icons.check_circle_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

/// One servant's month, for «تقرير الشهر».
class ServantMonthReport {
  const ServantMonthReport({
    required this.month,
    required this.held,
    required this.counts,
    required this.prepsSent,
    required this.prepsAccepted,
  });

  final DateTime month;

  /// Saturdays held that month.
  final int held;

  /// Marks per activity (sunday_school, servant_meeting, mass, confession).
  final Map<String, int> counts;
  final int prepsSent;
  final int prepsAccepted;

  static ServantMonthReport of(
    ServantYear year,
    String servantId,
    DateTime month, {
    required int prepsSent,
    required int prepsAccepted,
  }) {
    final days = year.held
        .where((d) => d.year == month.year && d.month == month.month)
        .toList();
    return ServantMonthReport(
      month: DateTime(month.year, month.month),
      held: days.length,
      counts: {
        for (final t in servantDayActivities)
          t: days.where((d) => year.typesOn(servantId, d).contains(t)).length,
      },
      prepsSent: prepsSent,
      prepsAccepted: prepsAccepted,
    );
  }

  /// «تقرير نوفمبر لـ مينا: خدمة 3 من 4 • اجتماع 2 • قداس 3 • اعتراف 1 •
  /// تحضير 3 (اتقبل 2)», then a kind line.
  String text(String servantName) {
    final first = servantName.trim().split(RegExp(r'\s+')).first;
    final m = AppDateUtils.monthName(month.month);
    final parts = [
      '${AppStrings.chipService} ${counts['sunday_school'] ?? 0} ${AppStrings.ofWord} $held',
      '${AppStrings.chipMeeting} ${counts['servant_meeting'] ?? 0}',
      '${AppStrings.massShort} ${counts['mass'] ?? 0}',
      '${AppStrings.confessionShort} ${counts['confession'] ?? 0}',
      AppStrings.reportPreps(prepsSent, prepsAccepted),
    ];
    return '${AppStrings.reportHeader(m, first)}\n'
        '${parts.join(' • ')}\n'
        '${AppStrings.reportThanks}';
  }
}

/// «تقرير الشهر»: this month or last, the text, and where to send it.
Future<void> showServantReportSheet(
  BuildContext context, {
  required String servantName,
  required String? mobile,
  required ServantMonthReport thisMonth,
  required ServantMonthReport lastMonth,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(
      servantName: servantName,
      mobile: mobile,
      reports: [thisMonth, lastMonth],
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.servantName,
    required this.mobile,
    required this.reports,
  });

  final String servantName;
  final String? mobile;
  final List<ServantMonthReport> reports;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final report = widget.reports[_i];
    final text = report.text(widget.servantName);
    final number = WhatsApp.normalise(widget.mobile);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AppStrings.monthReportTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: [
                for (final (i, r) in widget.reports.indexed)
                  ButtonSegment(
                    value: i,
                    label: Text(AppDateUtils.monthName(r.month.month)),
                  ),
              ],
              selected: {_i},
              onSelectionChanged: (s) => setState(() => _i = s.first),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                text,
                style: const TextStyle(fontSize: 14, height: 1.7),
              ),
            ),
            const SizedBox(height: 12),
            if (number != null)
              FilledButton.icon(
                onPressed: () => launchUrl(
                  WhatsApp.link(number, text),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const WhatsAppIcon(size: 20),
                label: const Text(AppStrings.sendToServant),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: text)),
              icon: const Icon(Icons.share_outlined),
              label: const Text(AppStrings.shareReport),
            ),
          ],
        ),
      ),
    );
  }
}
