import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/image_viewer.dart';
import '../../data/models/lesson.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../state/session_controller.dart';
import '../lessons/lesson_widgets.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';

/// How a review sheet ended: the prep was reviewed, skipped («تخطي», only
/// offered in a review run), or the sheet was closed.
enum PrepReviewResult { reviewed, skipped, closed }

/// Shared bottom sheet for reviewing a lesson prep submission.
/// Opens via [showPrepReviewSheet].
///
/// In a review run ([position] like «2 من 7», [canSkip]) the caller opens the
/// next prep when this one comes back reviewed or skipped.
Future<PrepReviewResult> showPrepReviewSheet(
  BuildContext context, {
  required LessonPrep prep,
  required Future<void> Function(String status, String? comment) onReview,
  String? position,
  bool canSkip = false,
}) async {
  final result = await showModalBottomSheet<PrepReviewResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PrepReviewSheet(
      prep: prep,
      onReview: onReview,
      position: position,
      canSkip: canSkip,
    ),
  );
  return result ?? PrepReviewResult.closed;
}

class PrepReviewSheet extends StatefulWidget {
  const PrepReviewSheet({
    super.key,
    required this.prep,
    required this.onReview,
    this.position,
    this.canSkip = false,
  });

  final LessonPrep prep;
  final Future<void> Function(String status, String? comment) onReview;

  /// Where this prep is in a review run, e.g. «2 من 7».
  final String? position;

  /// Shows «تخطي», which closes the sheet as [PrepReviewResult.skipped].
  final bool canSkip;

  @override
  State<PrepReviewSheet> createState() => _PrepReviewSheetState();
}

class _PrepReviewSheetState extends State<PrepReviewSheet> {
  final _commentController = TextEditingController();
  int _photoPage = 0;

  static const _lessons = LessonRepository();

  /// "مشاركة كمثال": applied at once for an accepted prep, otherwise on accept.
  late bool _share = widget.prep.isShared;
  bool _sharing = false;

  /// The lesson the prep was for: its slot in the programme and its grade.
  /// Null when that Saturday had no lesson (or the class has no grade).
  Future<({LessonSlot slot, int grade})?> _lessonOfPrep() async {
    final prep = widget.prep;
    final grade = LessonProgramme.gradeOf(prep.className ?? '');
    final first = firstSessionDay(context.read<SessionController>());
    if (grade == null || first == null) return null;
    final programme = await _lessons.programme();
    final lesson = programme.lessonOn(prep.sessionDate, grade, firstDay: first);
    return lesson == null ? null : (slot: lesson.slot, grade: grade);
  }

  Future<void> _toggleShare(bool on) async {
    final prep = widget.prep;
    if (!prep.isAccepted) {
      // Not accepted yet: remembered, done together with "قبول".
      setState(() => _share = on);
      return;
    }
    setState(() => _sharing = true);
    try {
      if (on) {
        final target = await _lessonOfPrep();
        if (!mounted) return;
        if (target == null) {
          Ui.info(context, AppStrings.sharePrepNoLesson);
          return;
        }
        await _lessons.sharePrep(prep.id, target.slot, target.grade);
      } else {
        await _lessons.unsharePrep(prep.id);
      }
      if (!mounted) return;
      setState(() => _share = on);
      Ui.success(context, on ? AppStrings.prepShared : AppStrings.prepUnshared);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

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
            // Who sent it and for which class: going through everyone's
            // preps, the date alone does not say whose this is.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prep.servantName.isNotEmpty)
                        Text(
                          prep.servantName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        [
                          if (prep.className != null) prep.className!,
                          AppDateUtils.formatDayDate(prep.sessionDate),
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.position != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.position!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    prepStatusLabel(prep.status),
                    style: TextStyle(
                      fontSize: 13,
                      color: prepStatusColor(prep.status),
                    ),
                  ),
                ),
                if (widget.canSkip)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(PrepReviewResult.skipped),
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text(AppStrings.skip),
                  ),
              ],
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
                    child:
                        _StorageImage(storagePath: prep.photos[i].storagePath),
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
            // No session (a test) counts as not an admin.
            if (context.read<SessionController?>()?.isAdmin ?? false) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _share,
                onChanged: _sharing ? null : _toggleShare,
                title: const Text(
                  AppStrings.sharePrep,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  prep.isAccepted
                      ? AppStrings.sharePrepHint
                      : AppStrings.sharePrepNeedsAccept,
                  style: const TextStyle(fontSize: 12),
                ),
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
    // Accepted with "مشاركة كمثال" ticked: share it once it is accepted.
    final shareAfter = status == 'accepted' && _share && !widget.prep.isShared;
    final target = shareAfter ? await _lessonOfPrep() : null;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(PrepReviewResult.reviewed);
    await widget.onReview(status, comment);
    if (!shareAfter) return;
    if (target == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text(AppStrings.sharePrepNoLesson)));
      return;
    }
    try {
      await _lessons.sharePrep(widget.prep.id, target.slot, target.grade);
      messenger
          .showSnackBar(const SnackBar(content: Text(AppStrings.prepShared)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

/// A prep's status in words: «قيد المراجعة», «مقبول», «يوجد تعليق».
String prepStatusLabel(String status) => switch (status) {
      'accepted' => AppStrings.prepAccepted,
      'commented' => AppStrings.prepCommented,
      _ => AppStrings.prepPending,
    };

Color prepStatusColor(String status) => switch (status) {
      'accepted' => AppColors.success,
      'commented' => AppColors.warning,
      _ => AppColors.muted,
    };

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
    // A PDF is not an image: show a card that opens it.
    if (widget.storagePath.toLowerCase().endsWith('.pdf')) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.picture_as_pdf_outlined,
              color: AppColors.danger),
          title: Text(widget.storagePath.split('/').last,
              style: const TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(Uri.parse(_url!)),
        ),
      );
    }
    return GestureDetector(
      onTap: () => showZoomableImage(context, _url!),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(_url!, fit: BoxFit.contain),
            ),
          ),
          // Hint that the picture opens full screen.
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
