import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/servant_activity.dart';

/// Under a «حضور الخدام» row: who covered this servant (each with undo),
/// whom they covered, or «مين غطّى؟».
class ServantCoverFooter extends StatelessWidget {
  const ServantCoverFooter({
    super.key,
    this.coveredBy = const [],
    this.coveredFor = const [],
    this.onAsk,
  });

  final List<({String name, VoidCallback onRemove})> coveredBy;
  final List<String> coveredFor;

  /// Shown as «مين غطّى؟» when not null.
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final c in coveredBy)
            InputChip(
              avatar: const Icon(Icons.swap_horiz_rounded,
                  size: 16, color: AppColors.olive),
              label: Text(AppStrings.coveredBy(c.name)),
              labelStyle: const TextStyle(fontSize: 12),
              visualDensity: VisualDensity.compact,
              deleteButtonTooltipMessage: AppStrings.removeSubstitute,
              onDeleted: c.onRemove,
            ),
          for (final name in coveredFor)
            Chip(
              avatar: const Icon(Icons.volunteer_activism_rounded,
                  size: 16, color: AppColors.olive),
              label: Text(AppStrings.coveredFor(name)),
              labelStyle: const TextStyle(fontSize: 12),
              visualDensity: VisualDensity.compact,
            ),
          if (onAsk != null)
            TextButton.icon(
              onPressed: onAsk,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text(AppStrings.whoCovered),
            ),
        ],
      ),
    );
  }
}

/// «التغطيات» on a servant's page: the classes they covered and who
/// covered theirs. Hidden when there are none.
class ServantCoversCard extends StatelessWidget {
  const ServantCoversCard({
    super.key,
    required this.servantId,
    required this.subs,
    required this.nameOf,
  });

  final String servantId;
  final List<ServantSubstitute> subs;
  final String Function(String id) nameOf;

  @override
  Widget build(BuildContext context) {
    if (subs.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: AppStrings.coversTitle,
      icon: Icons.swap_horiz_rounded,
      accent: AppColors.olive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in subs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                s.substituteServantId == servantId
                    ? AppStrings.coveredForOn(
                        nameOf(s.absentServantId),
                        AppDateUtils.formatDayDate(s.date),
                      )
                    : AppStrings.wasCoveredByOn(
                        nameOf(s.substituteServantId),
                        AppDateUtils.formatDayDate(s.date),
                      ),
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
