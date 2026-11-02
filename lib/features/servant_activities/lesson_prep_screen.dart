import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Picked but not yet uploaded — images carry preview bytes; PDFs carry only XFile
  final List<XFile> _pickedImages = [];
  final List<Uint8List> _imagePreviews = [];
  final List<XFile> _pickedPdfs = [];

  Future<void> _pickPhoto() async {
    final files = await PhotoService.pickMultiple();
    if (files.isEmpty || !mounted) return;
    final previews = await Future.wait(files.map((f) => f.readAsBytes()));
    setState(() {
      _pickedImages.addAll(files);
      _imagePreviews.addAll(previews);
    });
  }

  Future<void> _pickPdf() async {
    final file = await PhotoService.pickPdf();
    if (file == null || !mounted) return;
    setState(() => _pickedPdfs.add(file));
  }

  void _removePickedImage(int index) => setState(() {
        _pickedImages.removeAt(index);
        _imagePreviews.removeAt(index);
      });

  void _removePickedPdf(int index) =>
      setState(() => _pickedPdfs.removeAt(index));

  Future<void> _submit() async {
    if (_pickedImages.isEmpty && _pickedPdfs.isEmpty) {
      Ui.info(context, AppStrings.noPhotosSelected);
      return;
    }

    final ok = await Ui.runGuarded(
      context,
      () async {
        final prep = await _repo.createLessonPrep(widget.sessionId);
        for (final file in [..._pickedImages, ..._pickedPdfs]) {
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
        _pickedImages.clear();
        _imagePreviews.clear();
        _pickedPdfs.clear();
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
              imagePreviews: _imagePreviews,
              pdfFiles: _pickedPdfs,
              onPickPhoto: _pickPhoto,
              onPickPdf: _pickPdf,
              onRemovePhoto: _removePickedImage,
              onRemovePdf: _removePickedPdf,
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
    required this.imagePreviews,
    required this.pdfFiles,
    required this.onPickPhoto,
    required this.onPickPdf,
    required this.onRemovePhoto,
    required this.onRemovePdf,
    required this.onSubmit,
  });

  final List<Uint8List> imagePreviews;
  final List<XFile> pdfFiles;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickPdf;
  final void Function(int) onRemovePhoto;
  final void Function(int) onRemovePdf;
  final VoidCallback onSubmit;

  bool get _isEmpty => imagePreviews.isEmpty && pdfFiles.isEmpty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        SectionCard(
          title: AppStrings.lessonPrep,
          icon: Icons.menu_book_rounded,
          accent: AppColors.olive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(
                    icon: Icons.photo_library_outlined,
                    title: AppStrings.noPhotosSelected,
                    body: AppStrings.noLessonPrepsBody,
                  ),
                )
              else ...[
                if (imagePreviews.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < imagePreviews.length; i++)
                        _PhotoThumb(
                          bytes: imagePreviews[i],
                          onRemove: () => onRemovePhoto(i),
                        ),
                    ],
                  ),
                if (pdfFiles.isNotEmpty) ...[
                  if (imagePreviews.isNotEmpty) const SizedBox(height: 8),
                  for (var i = 0; i < pdfFiles.length; i++)
                    _PdfTile(
                      name: pdfFiles[i].name,
                      onRemove: () => onRemovePdf(i),
                    ),
                ],
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickPhoto,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text(AppStrings.pickPhotos),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text(AppStrings.pickPdf),
                    ),
                  ),
                ],
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

class _PdfTile extends StatelessWidget {
  const _PdfTile({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
        title: Text(name, style: const TextStyle(fontSize: 13)),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
          onPressed: onRemove,
        ),
        dense: true,
      ),
    );
  }
}

class _StoragePdfTile extends StatefulWidget {
  const _StoragePdfTile({required this.storagePath});

  final String storagePath;

  @override
  State<_StoragePdfTile> createState() => _StoragePdfTileState();
}

class _StoragePdfTileState extends State<_StoragePdfTile> {
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

  String get _fileName {
    final parts = widget.storagePath.split('/');
    return parts.isNotEmpty ? parts.last : widget.storagePath;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.danger),
      title: Text(_fileName, style: const TextStyle(fontSize: 13)),
      trailing: _url == null
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.open_in_new, size: 18, color: AppColors.navy),
      dense: true,
      onTap: _url == null ? null : () => launchUrl(Uri.parse(_url!)),
    );
  }
}

// ---------------------------------------------------------------------------
// Already submitted: read-only view
// ---------------------------------------------------------------------------

class _SubmittedView extends StatelessWidget {
  const _SubmittedView({required this.prep});

  final LessonPrep prep;

  static bool _isPdf(String path) => path.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final imagePhotos =
        prep.photos.where((p) => !_isPdf(p.storagePath)).toList();
    final pdfPhotos =
        prep.photos.where((p) => _isPdf(p.storagePath)).toList();

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
            icon: Icons.chat_bubble_rounded,
            accent: AppColors.sky,
            child: Text(
              prep.adminComment!,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
        if (imagePhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: AppStrings.lessonPrepTitle,
            icon: Icons.edit_note_rounded,
            accent: AppColors.navyLight,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imagePhotos
                  .map((p) => _StorageThumb(storagePath: p.storagePath))
                  .toList(),
            ),
          ),
        ],
        if (pdfPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: AppStrings.pdfFile,
            icon: Icons.picture_as_pdf_rounded,
            accent: AppColors.coral,
            child: Column(
              children: pdfPhotos
                  .map((p) => _StoragePdfTile(storagePath: p.storagePath))
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
