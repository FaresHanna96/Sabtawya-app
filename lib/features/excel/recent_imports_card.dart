import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/import_batch.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';

/// The Excel imports of the last two weeks that can still be undone (the
/// person's own, or all of them for an admin). Shows nothing when there are
/// none, or when they cannot be loaded (offline).
class RecentImportsCard extends StatefulWidget {
  const RecentImportsCard({super.key, this.load, this.undo});

  /// Replaceable in tests.
  final Future<List<ImportBatch>> Function()? load;
  final Future<void> Function(String batchId)? undo;

  @override
  State<RecentImportsCard> createState() => _RecentImportsCardState();
}

class _RecentImportsCardState extends State<RecentImportsCard> {
  static const _repository = ChildRepository();

  List<ImportBatch> _batches = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final list = await (widget.load ?? _repository.recentImports)();
      if (mounted) setState(() => _batches = list);
    } catch (_) {
      if (mounted) setState(() => _batches = const []);
    }
  }

  Future<void> _undo(ImportBatch b) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.undoImportTitle,
      message: AppStrings.undoImportMessage,
      confirmLabel: AppStrings.undo,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final session = context.read<SessionController>();
    final ok = await Ui.runGuarded(
      context,
      () async {
        final undo = widget.undo;
        if (undo != null) {
          await undo(b.id);
        } else {
          await _repository.undoImport(b.id);
        }
      },
      successMessage: AppStrings.undoDone,
    );
    if (!ok) return;
    await session.refreshClasses();
    session.markChanged();
    if (mounted) await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    if (_batches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: AppStrings.recentImports,
        icon: Icons.history_rounded,
        accent: AppColors.coral,
        child: Column(
          children: [
            for (final b in _batches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(AppStrings.importBatchLine(
                  AppDateUtils.formatDate(b.createdAt),
                  b.inserted,
                  b.updated,
                )),
                subtitle: b.actorName == null ? null : Text(b.actorName!),
                trailing: TextButton(
                  onPressed: () => _undo(b),
                  child: const Text(AppStrings.undo),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
