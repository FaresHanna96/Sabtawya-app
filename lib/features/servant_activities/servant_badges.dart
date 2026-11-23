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

/// The servant's four badges in a row: earned in colour, the others grey
/// with how far along; a tap explains the rule.
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
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      child: Row(
        children: [
          for (final b in badges) Expanded(child: _Medal(state: b)),
        ],
      ),
    );
  }
}

class _Medal extends StatelessWidget {
  const _Medal({required this.state});

  final ServantBadgeState state;

  @override
  Widget build(BuildContext context) {
    final b = state.badge;
    final color = state.earned ? b.color : AppColors.muted;
    return Tooltip(
      message:
          '${b.rule}\n${state.earned ? AppStrings.badgeEarnedShort : AppStrings.progressOf(state.progress, state.target)}',
      triggerMode: TooltipTriggerMode.tap,
      child: Semantics(
        label:
            '${b.title}: ${state.earned ? AppStrings.badgeEarnedShort : AppStrings.notYet}',
        excludeSemantics: true,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: state.earned
                    ? statusTint(b.color, 0.16)
                    : AppColors.muted.withValues(alpha: 0.10),
              ),
              child: Icon(
                state.earned ? b.icon : Icons.lock_outline_rounded,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                b.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: state.earned ? AppColors.navy : AppColors.muted,
                ),
              ),
            ),
            if (!state.earned)
              Text(
                AppStrings.progressOf(state.progress, state.target),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
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
