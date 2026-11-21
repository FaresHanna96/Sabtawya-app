import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/repositories/child_repository.dart';
import '../children/missing_info.dart';
import '../children/missing_info_screen.dart';

/// On the home page: how complete the children's records are, and a way into
/// the list of what is missing. Nothing is shown while loading, when it
/// failed, or when every record is complete.
class MissingInfoSection extends StatefulWidget {
  const MissingInfoSection({super.key, this.load, this.reloadToken = 0});

  /// Changes when the home reloads (pull-to-refresh, or data changed
  /// elsewhere); the card then fetches again, keeping what it shows meanwhile.
  final int reloadToken;

  /// The children; defaults to the real ones (a servant's classes, or all for
  /// an admin, through row level security). Tests give their own.
  final Future<List<Child>> Function()? load;

  @override
  State<MissingInfoSection> createState() => _MissingInfoSectionState();
}

class _MissingInfoSectionState extends State<MissingInfoSection> {
  late Future<List<Child>> _future = _fetch();

  Future<List<Child>> _fetch() =>
      (widget.load ?? () => const ChildRepository().all())();

  @override
  void didUpdateWidget(MissingInfoSection old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _future = _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Child>>(
      future: _future,
      builder: (context, snapshot) {
        final children = snapshot.data;
        if (children == null || children.isEmpty) {
          return const SizedBox.shrink();
        }
        final missing = MissingInfo.filter(children, null).length;
        if (missing == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MissingInfoCard(
            total: children.length,
            missing: missing,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const MissingInfoScreen(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The card itself: the count, the bar and "عرض القائمة".
class MissingInfoCard extends StatelessWidget {
  const MissingInfoCard({
    super.key,
    required this.total,
    required this.missing,
    required this.onTap,
  });

  final int total;
  final int missing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = total - missing;
    final ratio = total == 0 ? 1.0 : done / total;
    final color = ratio >= 0.9
        ? AppColors.success
        : ratio >= 0.6
            ? AppColors.warning
            : AppColors.danger;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.rule_rounded, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppStrings.missingInfoTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppStrings.missingHomeCount(missing),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(AppIcons.forward, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.missingDoneOf(done, total),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
