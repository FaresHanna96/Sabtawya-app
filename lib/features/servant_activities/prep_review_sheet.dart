import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../data/models/servant_activity.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';

/// Shared bottom sheet for reviewing a lesson prep submission.
/// Opens via [showPrepReviewSheet].
Future<void> showPrepReviewSheet(
  BuildContext context, {
  required LessonPrep prep,
  required Future<void> Function(String status, String? comment) onReview,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PrepReviewSheet(prep: prep, onReview: onReview),
  );
}

class PrepReviewSheet extends StatefulWidget {
  const PrepReviewSheet({
    super.key,
    required this.prep,
    required this.onReview,
  });

  final LessonPrep prep;
  final Future<void> Function(String status, String? comment) onReview;

  @override
  State<PrepReviewSheet> createState() => _PrepReviewSheetState();
}

class _PrepReviewSheetState extends State<PrepReviewSheet> {
  final _commentController = TextEditingController();
  int _photoPage = 0;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prep = widget.prep;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppDateUtils.formatDayDate(prep.sessionDate),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              _statusLabel(prep.status),
              style: TextStyle(fontSize: 13, color: _statusColor(prep.status)),
            ),
            if (prep.photos.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: PageView.builder(
                  itemCount: prep.photos.length,
                  onPageChanged: (i) => setState(() => _photoPage = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _StorageImage(
                        storagePath: prep.photos[i].storagePath),
                  ),
                ),
              ),
              if (prep.photos.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < prep.photos.length; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _photoPage == i
                              ? AppColors.navy
                              : AppColors.muted.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: AppStrings.addComment,
                hintText: AppStrings.enterComment,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submit('commented'),
                    icon: const Icon(Icons.comment_outlined, size: 18),
                    label: const Text(AppStrings.addComment),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _submit('accepted'),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(AppStrings.acceptPrep),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(String status) async {
    final comment = _commentController.text.trim().isEmpty
        ? null
        : _commentController.text.trim();
    if (status == 'commented' && comment == null) {
      Ui.info(context, AppStrings.commentRequired);
      return;
    }
    Navigator.of(context).pop();
    await widget.onReview(status, comment);
  }

  static String _statusLabel(String status) => switch (status) {
        'accepted' => AppStrings.prepAccepted,
        'commented' => AppStrings.prepCommented,
        _ => AppStrings.prepPending,
      };

  static Color _statusColor(String status) => switch (status) {
        'accepted' => AppColors.success,
        'commented' => AppColors.warning,
        _ => AppColors.muted,
      };
}

class _StorageImage extends StatefulWidget {
  const _StorageImage({required this.storagePath});
  final String storagePath;

  @override
  State<_StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<_StorageImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    PhotoService.signedUrl(
      bucket: Db.bucketServantSubmissions,
      path: widget.storagePath,
    ).then((url) {
      if (mounted) setState(() => _url = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) return const Center(child: CircularProgressIndicator());
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(_url!, fit: BoxFit.contain),
    );
  }
}
