import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';

/// Servant view for a single attendance session's lesson prep submission.
///
/// If not yet submitted: shows photo picker and submit button.
/// If already submitted: shows status, photos, and any admin comment (read-only).
class LessonPrepScreen extends StatefulWidget {
  const LessonPrepScreen({
    super.key,
    required this.sessionId,
    required this.sessionDate,
  });

  final String sessionId;
  final DateTime sessionDate;

  @override
  State<LessonPrepScreen> createState() => _LessonPrepScreenState();
}

class _LessonPrepScreenState extends State<LessonPrepScreen> {
  static const _repo = ServantActivityRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<LessonPrep?>>();

  Future<LessonPrep?> _load() =>
      _repo.lessonPrepForSession(widget.sessionId);

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  // Picked but not yet uploaded
  final List<XFile> _pickedFiles = [];
  final List<Uint8List> _previews = [];

  Future<void> _pickPhoto() async {
    final files = await PhotoService.pickMultiple();
    if (files.isEmpty || !mounted) return;
    final previews = await Future.wait(files.map((f) => f.readAsBytes()));
    setState(() {
      _pickedFiles.addAll(files);
      _previews.addAll(previews);
    });
  }

  void _removePickedPhoto(int index) {
    setState(() {
      _pickedFiles.removeAt(index);
      _previews.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_pickedFiles.isEmpty) {
      Ui.info(context, AppStrings.noPhotosSelected);
      return;
    }

    final ok = await Ui.runGuarded(
      context,
      () async {
        // Create prep row first to get its id (used as the storage path prefix).
        final prep = await _repo.createLessonPrep(widget.sessionId);
        // Upload each photo and record the path.
        for (final file in _pickedFiles) {
          final path = await PhotoService.upload(
            bucket: Db.bucketServantSubmissions,
            ownerId: prep.id,
            file: file,
          );
          await _repo.addPrepPhoto(prepId: prep.id, storagePath: path);
        }
      },
      successMessage: AppStrings.submittedSuccessfully,
    );

    if (ok) {
      setState(() {
        _pickedFiles.clear();
        _previews.clear();
      });
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppDateUtils.formatDayDate(widget.sessionDate)),
      ),
      body: SafeArea(
        child: AsyncSection<LessonPrep?>(
          key: _sectionKey,
          load: _load,
          builder: (context, prep, reload) {
            if (prep != null) {
              return _SubmittedView(prep: prep);
            }
            return _SubmitForm(
              previews: _previews,
              onPickPhoto: _pickPhoto,
              onRemovePhoto: _removePickedPhoto,
              onSubmit: _submit,
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Not yet submitted: pick photos and submit
// ---------------------------------------------------------------------------

class _SubmitForm extends StatelessWidget {
  const _SubmitForm({
    required this.previews,
    required this.onPickPhoto,
    required this.onRemovePhoto,
    required this.onSubmit,
  });

  final List<Uint8List> previews;
  final VoidCallback onPickPhoto;
  final void Function(int) onRemovePhoto;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        SectionCard(
          title: AppStrings.lessonPrep,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (previews.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: AppStrings.noPhotosSelected,
                    body: AppStrings.noLessonPrepsBody,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < previews.length; i++)
                      _PhotoThumb(
                        bytes: previews[i],
                        onRemove: () => onRemovePhoto(i),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onPickPhoto,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text(AppStrings.pickPhotos),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onSubmit,
          icon: const Icon(Icons.upload_outlined),
          label: const Text(AppStrings.submitLessonPrep),
        ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Already submitted: read-only view
// ---------------------------------------------------------------------------

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.prep});

  final LessonPrep prep;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        SectionCard(
          child: InfoRow(
            label: AppStrings.alreadySubmitted,
            value: _statusLabel(prep.status),
            icon: _statusIcon(prep.status),
          ),
        ),
        if (prep.isCommented && prep.adminComment != null) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: AppStrings.addComment,
            child: Text(
              prep.adminComment!,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
        if (prep.photos.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: AppStrings.lessonPrepTitle,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: prep.photos
                  .map((p) => _StorageThumb(storagePath: p.storagePath))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'accepted' => AppStrings.prepAccepted,
        'commented' => AppStrings.prepCommented,
        _ => AppStrings.prepPending,
      };

  static IconData _statusIcon(String status) => switch (status) {
        'accepted' => Icons.check_circle_outline,
        'commented' => Icons.comment_outlined,
        _ => Icons.hourglass_empty_outlined,
      };
}

class _StorageThumb extends StatefulWidget {
  const _StorageThumb({required this.storagePath});

  final String storagePath;

  @override
  State<_StorageThumb> createState() => _StorageThumbState();
}

class _StorageThumbState extends State<_StorageThumb> {
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
    if (_url == null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _openPhoto(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _url!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context) {
    if (_url == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Image.network(_url!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
