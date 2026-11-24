import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';

/// The home's numbers in one card instead of four big tiles and a card of
/// their own for boys and girls: children, classes, servants and admins on
/// one row, the boys/girls split under them.
class HomeNumbersCard extends StatelessWidget {
  const HomeNumbersCard({
    super.key,
    required this.children,
    required this.classes,
    required this.servants,
    required this.admins,
    required this.boys,
    required this.girls,
  });

  final int children;
  final int classes;
  final int servants;
  final int admins;
  final int boys;
  final int girls;

  @override
  Widget build(BuildContext context) {
    final split = boys + girls;
    final boysShare = split == 0 ? 0.5 : boys / split;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                children: [
                  _Number(
                    value: children,
                    label: AppStrings.totalChildren,
                    icon: Icons.diversity_3,
                    color: AppColors.navy,
                  ),
                  const _Divider(),
                  _Number(
                    value: classes,
                    label: AppStrings.totalClasses,
                    icon: Icons.school,
                    color: AppColors.olive,
                  ),
                  const _Divider(),
                  _Number(
                    value: servants,
                    label: AppStrings.totalServants,
                    icon: Icons.supervisor_account,
                    color: AppColors.navyLight,
                  ),
                  const _Divider(),
                  _Number(
                    value: admins,
                    label: AppStrings.adminsShort,
                    icon: Icons.admin_panel_settings,
                    color: AppColors.gold,
                  ),
                ],
              ),
            ),
            if (split > 0) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Icon(Icons.boy_rounded,
                        size: 16, color: AppColors.sky),
                    Flexible(
                      child: Text(
                        ' ${AppStrings.boys} $boys',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.skyText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.5, end: boysShare),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (_, share, __) => SizedBox(
                            height: 6,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: (share * 1000).round().clamp(1, 999),
                                  child: Container(color: AppColors.sky),
                                ),
                                Expanded(
                                  flex: ((1 - share) * 1000)
                                      .round()
                                      .clamp(1, 999),
                                  child: Container(color: AppColors.coral),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '$girls ${AppStrings.girls} ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.coralText,
                        ),
                      ),
                    ),
                    const Icon(Icons.girl_rounded,
                        size: 16, color: AppColors.coral),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
          const SizedBox(height: 6),
          AnimatedCount(
            value: value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.readable(color),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => VerticalDivider(
        width: 1,
        thickness: 1,
        color: AppColors.navy.withValues(alpha: 0.08),
      );
}
