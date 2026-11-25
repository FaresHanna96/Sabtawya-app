import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../state/session_controller.dart';
import '../home/more_counts.dart';
import '../home/more_entries.dart';

/// One number the home asks the servant to act on.
class AttentionItem {
  const AttentionItem(this.count, this.entryId, this.icon, this.label, this.color);

  final MoreCount count;

  /// The المزيد entry whose screen opens on tap.
  final String entryId;
  final IconData icon;
  final String label;
  final Color color;
}

const attentionItems = <AttentionItem>[
  AttentionItem(MoreCount.absence, 'absence', Icons.support_agent_rounded,
      AppStrings.attnAbsence, AppColors.coral),
  AttentionItem(MoreCount.missingInfo, 'missingInfo', Icons.rule_rounded,
      AppStrings.attnMissing, AppColors.gold),
  AttentionItem(MoreCount.pendingPreps, 'preps', Icons.fact_check_rounded,
      AppStrings.attnPreps, AppColors.sky),
  AttentionItem(MoreCount.invites, 'servants', Icons.person_add_alt_1_rounded,
      AppStrings.attnInvites, AppColors.olive),
];

/// A slim «محتاج متابعة» row on the home: only the numbers above zero, each
/// opening its screen. Nothing at all when there is nothing to act on.
class NeedsAttentionStrip extends StatelessWidget {
  const NeedsAttentionStrip({
    super.key,
    required this.counts,
    required this.onOpen,
  });

  final Map<MoreCount, int> counts;
  final void Function(String entryId) onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final i in attentionItems)
        if ((counts[i.count] ?? 0) > 0) i,
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AppStrings.needsAttention,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in shown)
                Material(
                  color: i.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onOpen(i.entryId),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(i.icon,
                                size: 16, color: AppColors.readable(i.color)),
                            const SizedBox(width: 6),
                            Flexible(
                                child: Text(
                              '${i.label} · ${counts[i.count]}',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.readable(i.color),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loads the same numbers as the badges on المزيد and shows the strip; loads
/// again when [reloadToken] changes. Quiet while loading or when it fails.
class NeedsAttentionSection extends StatefulWidget {
  const NeedsAttentionSection({super.key, this.reloadToken = 0, this.load});

  final int reloadToken;

  /// Tests give their own numbers.
  final Future<Map<MoreCount, int>> Function()? load;

  @override
  State<NeedsAttentionSection> createState() => _NeedsAttentionSectionState();
}

class _NeedsAttentionSectionState extends State<NeedsAttentionSection> {
  Future<Map<MoreCount, int>>? _future;

  Future<Map<MoreCount, int>> _fetch() {
    if (widget.load != null) return widget.load!();
    final session = context.read<SessionController>();
    return MoreCounts.load(
      yearId: session.currentYear?.id,
      isAdmin: session.isAdmin,
    );
  }

  @override
  void didUpdateWidget(NeedsAttentionSection old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _future = _fetch();
  }

  void _open(String id) {
    for (final e in MoreCatalog.all) {
      if (e.id != id || e.open == null) continue;
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => e.open!()))
          .then((_) {
        if (mounted) setState(() => _future = _fetch());
      });
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<MoreCount, int>>(
      future: _future ??= _fetch(),
      builder: (context, snapshot) => NeedsAttentionStrip(
        counts: snapshot.data ?? const {},
        onOpen: _open,
      ),
    );
  }
}
