import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../state/session_controller.dart';
import 'prep_review_sheet.dart';

/// Which preps «التحضيرات» lists.
enum PrepsFilter { pending, reviewed, all }

/// The sorting and grouping behind «التحضيرات», apart from the screen so it
/// can be tested without a server.
class PrepsInbox {
  const PrepsInbox._();

  /// Every prep once: all the waiting ones, plus the latest of the rest.
  static List<LessonPrep> merge(
    List<LessonPrep> pending,
    List<LessonPrep> recent,
  ) {
    final byId = {
      for (final p in recent) p.id: p,
      for (final p in pending) p.id: p
    };
    return byId.values.toList()..sort((a, b) => _sent(b).compareTo(_sent(a)));
  }

  static List<LessonPrep> filter(List<LessonPrep> preps, PrepsFilter f) =>
      switch (f) {
        PrepsFilter.pending => preps.where((p) => p.isPending).toList(),
        PrepsFilter.reviewed => preps.where((p) => !p.isPending).toList(),
        PrepsFilter.all => preps,
      };

  /// By Saturday, the latest Saturday first; each keeps the order it came in.
  static List<(DateTime, List<LessonPrep>)> bySaturday(
    List<LessonPrep> preps,
  ) {
    final groups = <DateTime, List<LessonPrep>>{};
    for (final p in preps) {
      final d = p.sessionDate;
      groups.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(p);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) (d, groups[d]!)];
  }

  /// A review run goes first come, first served: the oldest sent first.
  static List<LessonPrep> runOrder(List<LessonPrep> pending) =>
      [...pending]..sort((a, b) => _sent(a).compareTo(_sent(b)));

  static DateTime _sent(LessonPrep p) =>
      p.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// «التحضيرات»: every servant's lesson prep in one place for أمين الخدمة,
/// the ones waiting for review first. «راجع ورا بعض» opens them one after
/// another. Only an admin can read everyone's preps (row level security).
class PrepsInboxScreen extends StatefulWidget {
  const PrepsInboxScreen({super.key});

  @override
  State<PrepsInboxScreen> createState() => _PrepsInboxScreenState();
}

class _PrepsInboxScreenState extends State<PrepsInboxScreen> {
  static const _repo = ServantActivityRepository();

  final _key = GlobalKey<AsyncSectionState<List<LessonPrep>>>();
  PrepsFilter _filter = PrepsFilter.pending;

  /// Reviews still being saved; waited for before the list reloads.
  final _saving = <Future<void>>[];

  Future<List<LessonPrep>> _load() async {
    final (pending, recent) =
        await (_repo.allPendingPreps(), _repo.recentPreps()).wait;
    return PrepsInbox.merge(pending, recent);
  }

  Future<void> _save(LessonPrep prep, String status, String? comment) {
    final saving = _repo
        .reviewPrep(prepId: prep.id, status: status, comment: comment)
        .then<void>((_) {}, onError: (Object e) {
      if (mounted) Ui.error(context, e);
    });
    _saving.add(saving);
    return saving;
  }

  /// Once the reviews are saved: this list, the badges and «نشاطات الخدام»
  /// all reload.
  Future<void> _afterReviews() async {
    await Future.wait(_saving);
    _saving.clear();
    if (!mounted) return;
    context.read<SessionController>().markChanged();
    await _key.currentState?.reload();
  }

  Future<void> _reviewOne(LessonPrep prep) async {
    await showPrepReviewSheet(
      context,
      prep: prep,
      onReview: (status, comment) => _save(prep, status, comment),
    );
    await _afterReviews();
  }

  /// Opens the waiting preps one after another until the last one, or until
  /// the sheet is closed.
  Future<void> _reviewInRow(List<LessonPrep> pending) async {
    final queue = PrepsInbox.runOrder(pending);
    var reviewedAll = true;
    for (var i = 0; i < queue.length; i++) {
      if (!mounted) return;
      final prep = queue[i];
      final result = await showPrepReviewSheet(
        context,
        prep: prep,
        onReview: (status, comment) => _save(prep, status, comment),
        position: AppStrings.prepPosition(i + 1, queue.length),
        canSkip: true,
      );
      if (result != PrepReviewResult.reviewed) reviewedAll = false;
      if (result == PrepReviewResult.closed) break;
    }
    await _afterReviews();
    if (reviewedAll && mounted) {
      Ui.success(context, AppStrings.prepsAllReviewed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.prepsInboxTitle)),
      body: SafeArea(
        child: AsyncSection<List<LessonPrep>>(
          key: _key,
          load: _load,
          loading: const SkeletonList(),
          builder: (context, preps, reload) {
            final pending = PrepsInbox.filter(preps, PrepsFilter.pending);
            final shown = PrepsInbox.filter(preps, _filter);
            final groups = PrepsInbox.bySaturday(
              // Waiting ones in the order they would be reviewed.
              _filter == PrepsFilter.pending
                  ? PrepsInbox.runOrder(shown)
                  : shown,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in PrepsFilter.values)
                      ChoiceChip(
                        label: Text(switch (f) {
                          PrepsFilter.pending =>
                            AppStrings.prepsPendingChip(pending.length),
                          PrepsFilter.reviewed => AppStrings.prepsReviewed,
                          PrepsFilter.all => AppStrings.all,
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _reviewInRow(pending),
                    icon: const Icon(Icons.playlist_play_rounded),
                    label: Text(AppStrings.reviewAllInRow(pending.length)),
                  ),
                ],
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EmptyState(
                      icon: Icons.fact_check_outlined,
                      title: switch (_filter) {
                        PrepsFilter.pending => AppStrings.noPendingPreps,
                        PrepsFilter.reviewed => AppStrings.noReviewedPreps,
                        PrepsFilter.all => AppStrings.noLessonPreps,
                      },
                    ),
                  ),
                for (final (day, rows) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                    child: Text(
                      AppDateUtils.formatDayDate(day),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, prep) in rows.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          PrepInboxRow(
                            prep: prep,
                            onTap: () => _reviewOne(prep),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One prep in the list: who, which class, how many files, when, status.
class PrepInboxRow extends StatelessWidget {
  const PrepInboxRow({super.key, required this.prep, required this.onTap});

  final LessonPrep prep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = prepStatusColor(prep.status);
    final details = [
      if (prep.className != null) prep.className!,
      if (prep.photos.isNotEmpty) AppStrings.prepFilesCount(prep.photos.length),
      if (prep.createdAt != null) AppDateUtils.agoLabel(prep.createdAt!),
    ].join(' • ');
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(
          prep.isPending
              ? Icons.hourglass_top_rounded
              : prep.isAccepted
                  ? Icons.check_circle_rounded
                  : Icons.comment_rounded,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        prep.servantName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(details, style: const TextStyle(fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          prepStatusLabel(prep.status),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.readable(color),
          ),
        ),
      ),
    );
  }
}
