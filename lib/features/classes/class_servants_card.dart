import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/round_action_button.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/profile.dart';

/// الخدام المعينون: the servants of a class, one row each: a coloured initial,
/// the name (with "أنت" on your own row and "غير مفعّل" on a servant whose
/// account is off) and, when they have a number, a call and a WhatsApp button
/// to reach them.
class ClassServantsCard extends StatelessWidget {
  const ClassServantsCard({
    super.key,
    required this.servants,
    this.currentUserId,
  });

  final List<ClassServant> servants;

  /// The signed-in person, to mark their own row.
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.assignedServants,
      icon: Icons.volunteer_activism_rounded,
      accent: AppColors.olive,
      trailing: servants.isEmpty ? null : _CountBadge(count: servants.length),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: servants.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                AppStrings.noServants,
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < servants.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: AppColors.navy.withValues(alpha: 0.07),
                    ),
                  ServantRow(
                    servant: servants[i],
                    isMe: servants[i].servantId == currentUserId,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.olive.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.olive,
        ),
      ),
    );
  }
}

/// One servant of the class.
@visibleForTesting
class ServantRow extends StatelessWidget {
  const ServantRow({super.key, required this.servant, this.isMe = false});

  final ClassServant servant;
  final bool isMe;

  static const _palette = <Color>[
    AppColors.navy,
    AppColors.olive,
    AppColors.coral,
    AppColors.sky,
    AppColors.gold,
    AppColors.maroon,
  ];

  /// The same servant always gets the same colour.
  static Color colorFor(String name) {
    var sum = 0;
    for (final unit in name.codeUnits) {
      sum = (sum + unit) & 0xFFFF;
    }
    return _palette[sum % _palette.length];
  }

  /// The first letter of the name, for the avatar.
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '؟' : String.fromCharCode(trimmed.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(servant.servantName);
    final active = servant.servantIsActive;
    final number = WhatsApp.normalise(servant.servantMobile);
    final mobile = (servant.servantMobile ?? '').trim();

    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                initialOf(servant.servantName),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servant.servantName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isMe || !active) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (isMe)
                          const _Tag(
                            label: AppStrings.servantIsMe,
                            color: AppColors.navy,
                          ),
                        if (!active)
                          const _Tag(
                            label: AppStrings.servantInactive,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Nobody needs a button to call themselves.
            if (!isMe && mobile.isNotEmpty) ...[
              if (number != null) ...[
                RoundActionButton(
                  size: 42,
                  tooltip: AppStrings.whatsappTo(servant.servantName),
                  color: WhatsAppIcon.green,
                  onTap: () => launchUrl(
                    WhatsApp.link(number),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const WhatsAppIcon(size: 22),
                ),
                const SizedBox(width: 8),
              ],
              RoundActionButton(
                size: 42,
                tooltip: '${AppStrings.call}: ${servant.servantName}',
                color: AppColors.success,
                onTap: () => launchUrl(Uri(scheme: 'tel', path: mobile)),
                child: const Icon(Icons.call_rounded,
                    size: 21, color: AppColors.success),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
