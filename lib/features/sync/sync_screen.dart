import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/offline_store.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';

/// What is waiting to sync and what the server refused, with retry and discard.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  static String _what(QueuedRequest r) {
    final verb = switch (r.method) {
      'POST' => 'إضافة',
      'PATCH' || 'PUT' => 'تعديل',
      'DELETE' => 'حذف',
      _ => r.method,
    };
    return '$verb • ${r.label}';
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final pending = OfflineStore.pendingWrites();
    final failed = OfflineStore.failedWrites();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.syncTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: staggerAll([
            FilledButton.icon(
              onPressed: sync.syncing ? null : sync.flush,
              icon: const Icon(Icons.sync),
              label: Text(
                sync.syncing ? AppStrings.syncingNow : AppStrings.syncNow,
              ),
            ),
            const SizedBox(height: 16),
            if (pending.isEmpty && failed.isEmpty)
              const EmptyState(
                icon: Icons.cloud_done_outlined,
                title: AppStrings.syncNothing,
                body: '',
              ),
            if (pending.isNotEmpty)
              SectionCard(
                title: AppStrings.syncPending,
                icon: Icons.schedule_rounded,
                accent: AppColors.sky,
                child: Column(
                  children: [
                    for (final r in pending)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.cloud_upload_outlined),
                        title: Text(_what(r)),
                        subtitle: Text(
                          r.createdAt.toLocal().toString().substring(0, 16),
                        ),
                      ),
                  ],
                ),
              ),
            if (failed.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.syncFailed,
                icon: Icons.error_outline_rounded,
                accent: AppColors.coral,
                child: Column(
                  children: [
                    for (final r in failed)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(_what(r)),
                        subtitle: Text(r.error ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: AppStrings.syncRetry,
                              icon: const Icon(Icons.refresh),
                              onPressed: () => sync.retryFailed(r.id),
                            ),
                            IconButton(
                              tooltip: AppStrings.syncDiscard,
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.danger),
                              onPressed: () => sync.discardFailed(r.id),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
