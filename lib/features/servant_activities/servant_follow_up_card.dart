import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/whatsapp_icon.dart';
import 'servant_year.dart';

/// One servant on the card, with what the card needs to reach them.
class ServantFollowUpEntry {
  const ServantFollowUpEntry({
    required this.followUp,
    required this.name,
    this.mobile,
    this.className,
  });

  final ServantFollowUp followUp;
  final String name;
  final String? mobile;
  final String? className;
}

/// The kind message a servant gets on WhatsApp from the card.
String servantFollowUpMessage(ServantFollowUpEntry e, String senderName) =>
    switch (e.followUp.reason) {
      ServantFollowUpReason.absent => WhatsApp.servantCheckInMessage(
          name: e.name,
          senderName: senderName,
        ),
      ServantFollowUpReason.preps => WhatsApp.servantPrepNudgeMessage(
          name: e.name,
          senderName: senderName,
        ),
    };

/// «محتاج متابعة» for servants, at the top of «الخدام»: who missed two
/// Saturdays or more in a row, or (class servants) two of the last three
/// preps, each with a call and a kind WhatsApp. Nothing at all when nobody
/// needs a word.
class ServantFollowUpCard extends StatelessWidget {
  const ServantFollowUpCard({
    super.key,
    required this.entries,
    required this.senderName,
    this.onOpen,
    this.embedded = false,
  });

  /// Inside another card (under the «الخدام» stats): a small title row and
  /// the lines, no card of its own.
  final bool embedded;

  final List<ServantFollowUpEntry> entries;

  /// Signs the WhatsApp message.
  final String senderName;

  /// Opens the servant's page.
  final void Function(ServantFollowUpEntry entry)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    if (embedded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Icon(Icons.priority_high_rounded,
                      size: 18, color: AppColors.coralText),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      AppStrings.needsAttention,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusTint(AppColors.coral, 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${entries.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.coralText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final (i, e) in entries.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 52),
              _Line(entry: e, card: this),
            ],
          ],
        ),
      );
    }
    return SectionCard(
      title: AppStrings.needsAttention,
      icon: Icons.priority_high_rounded,
      accent: AppColors.coral,
      trailing: Text(
        '${entries.length}',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.coralText,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [for (final e in entries) _Line(entry: e, card: this)],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.entry, required this.card});

  final ServantFollowUpEntry entry;
  final ServantFollowUpCard card;

  @override
  Widget build(BuildContext context) {
    final f = entry.followUp;
    final absent = f.reason == ServantFollowUpReason.absent;
    final color = absent ? AppColors.danger : AppColors.warning;
    final number = WhatsApp.normalise(entry.mobile);
    final phone = (entry.mobile ?? '').trim();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: card.onOpen == null ? null : () => card.onOpen!(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: statusTint(color, 0.14),
              child: Text(
                entry.name.trim().isEmpty ? '?' : entry.name.trim()[0],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.readable(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.className == null
                        ? entry.name
                        : '${entry.name}  •  ${entry.className}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        absent
                            ? Icons.event_busy_rounded
                            : Icons.assignment_late_outlined,
                        size: 14,
                        color: AppColors.readable(color),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          absent
                              ? AppStrings.servantAbsentRun(f.count)
                              : AppStrings.servantMissedPreps(f.count),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.readable(color),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (phone.isNotEmpty)
              IconButton(
                tooltip: AppStrings.call,
                icon: const Icon(Icons.call_rounded, color: AppColors.success),
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
              ),
            if (number != null)
              IconButton(
                tooltip: AppStrings.whatsapp,
                icon: const WhatsAppIcon(size: 24),
                onPressed: () => launchUrl(
                  WhatsApp.link(
                      number, servantFollowUpMessage(entry, card.senderName)),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            if (phone.isEmpty && number == null && card.onOpen != null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(AppIcons.forward, size: 18, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
