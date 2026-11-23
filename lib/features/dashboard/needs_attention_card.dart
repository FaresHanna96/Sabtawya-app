import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../home/more_counts.dart';
import '../home/more_entries.dart';

/// One line of «محتاج متابعة»: an المزيد entry and how many wait in it.
class AttentionItem {
  const AttentionItem(this.entry, this.count);

  final MoreEntry entry;
  final int count;
}

/// The lines «محتاج متابعة» shows for [counts], in this order, skipping
/// anything at zero and anything [isAdmin] does not allow (join requests
/// and preps to review are the admin's).
List<AttentionItem> attentionItems(
  Map<MoreCount, int> counts, {
  required bool isAdmin,
}) {
  const order = <(String, MoreCount, bool)>[
    ('absence', MoreCount.absence, false),
    ('missingInfo', MoreCount.missingInfo, false),
    ('preps', MoreCount.pendingPreps, true),
    ('servants', MoreCount.invites, true),
  ];
  return [
    for (final (id, key, adminOnly) in order)
      if ((counts[key] ?? 0) > 0 && (isAdmin || !adminOnly))
        AttentionItem(
          MoreCatalog.all.firstWhere((e) => e.id == id),
          counts[key]!,
        ),
  ];
}

/// What waits on the admin (or the general servant) right now, one tappable
/// line each with its number: absences to follow up, children with missing
/// details, preps to review, join requests. Nothing at all hides the card.
class NeedsAttentionCard extends StatefulWidget {
  const NeedsAttentionCard({
    super.key,
    required this.isAdmin,
    required this.yearId,
    required this.onOpen,
    this.reloadToken = 0,
    this.load,
  });

  final bool isAdmin;
  final String? yearId;

  /// Opens a line's screen; the home reloads when it comes back.
  final Future<void> Function(Widget screen) onOpen;

  /// Changes when the home reloads; the counts are fetched again.
  final int reloadToken;

  /// Replaces [MoreCounts.load] in tests.
  final Future<Map<MoreCount, int>> Function()? load;

  @override
  State<NeedsAttentionCard> createState() => _NeedsAttentionCardState();
}

class _NeedsAttentionCardState extends State<NeedsAttentionCard> {
  late Future<Map<MoreCount, int>> _counts = _fetch();

  Future<Map<MoreCount, int>> _fetch() =>
      widget.load?.call() ??
      MoreCounts.load(yearId: widget.yearId, isAdmin: widget.isAdmin);

  @override
  void didUpdateWidget(NeedsAttentionCard old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _counts = _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<MoreCount, int>>(
      future: _counts,
      builder: (context, snapshot) {
        final items = attentionItems(
          snapshot.data ?? const {},
          isAdmin: widget.isAdmin,
        );
        // Kept on screen while reloading (the previous counts stay in data).
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SectionCard(
            title: AppStrings.needsAttention,
            icon: Icons.priority_high_rounded,
            accent: AppColors.coral,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(
              children: [
                for (final item in items)
                  _AttentionRow(
                    item: item,
                    // The home reloads every card (and so these counts)
                    // once the screen is closed.
                    onTap: () {
                      final open = item.entry.open;
                      if (open != null) widget.onOpen(open());
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap});

  final AttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.entry.color;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: statusTint(color),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.entry.icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 28),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusTint(color),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${item.count}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(AppIcons.forward, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
