import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/file_kind.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/file_fallback.dart';
import '../../core/widgets/image_viewer.dart';
import '../../data/models/servant_activity.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import '../lessons/lesson_widgets.dart';
import 'prep_files.dart';
import 'prep_review_sheet.dart';

/// A servant's lesson prep for one Saturday.
///
/// Not sent yet: pick photos (or take one) and PDFs, then send. Sent and
/// waiting, or sent back with a comment: the files can be added to or
/// removed, and a commented prep goes back for review with one button. An
/// accepted prep is read-only.
///
/// Files upload three at a time, never through the offline queue (a prep
/// sent offline used to say "sent" while its photos were still on the phone),
/// and one that fails stays here to try again.
class LessonPrepScreen extends StatefulWidget {
  const LessonPrepScreen({
    super.key,
    required this.sessionId,
    required this.sessionDate,
    this.initialFiles = const <XFile>[],
  });

  final String sessionId;
  final DateTime sessionDate;

  /// Files already chosen (shared to the app): attached, not yet sent.
  final List<XFile> initialFiles;

  @override
  State<LessonPrepScreen> createState() => _LessonPrepScreenState();
}

class _LessonPrepScreenState extends State<LessonPrepScreen> {
  static const _repo = ServantActivityRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<LessonPrep?>>();

  /// Chosen here, not uploaded yet.
  final List<PickedPrepFile> _picked = [];

  /// Uploading: (done, total); null when idle.
  (int, int)? _progress;

  Future<LessonPrep?> _load() => _repo.lessonPrepForSession(widget.sessionId);

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  bool get _busy => _progress != null;

  @override
  void initState() {
    super.initState();
    _add(widget.initialFiles);
  }

  // ── picking ───────────────────────────────────────────────────────────────

  Future<void> _add(List<XFile> files) async {
    if (files.isEmpty || !mounted) return;
    final picked = [
      for (final f in files) PickedPrepFile(f, await f.readAsBytes()),
    ];
    if (mounted) setState(() => _picked.addAll(picked));
  }

  Future<void> _pickPhotos({bool camera = false}) async {
    try {
      await _add(await PhotoService.pickMultiple(camera: camera));
    } catch (e) {
      if (mounted) Ui.error(context, e);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final file = await PhotoService.pickPdf();
      if (file != null) await _add([file]);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    }
  }

  // ── sending ───────────────────────────────────────────────────────────────

  /// New prep, more files for a waiting one, or a commented one sent back.
  Future<void> _send(LessonPrep? prep) async {
    if (!ConnectivityService.instance.isOnline) {
      Ui.info(context, AppStrings.uploadNeedsInternet);
      return;
    }
    final resend = prep != null && prep.isCommented;
    if (_picked.isEmpty && !(resend && prep.photos.isNotEmpty)) {
      Ui.info(context, AppStrings.noPhotosSelected);
      return;
    }

    final session = context.read<SessionController>();
    setState(() => _progress = (0, _picked.length));
    try {
      final id = prep?.id ?? (await _repo.createLessonPrep(widget.sessionId)).id;
      final result = await uploadPrepFiles(
        files: List.of(_picked),
        upload: (f) => PhotoService.upload(
          bucket: Db.bucketServantSubmissions,
          ownerId: id,
          file: f.file,
        ),
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = (done, total));
        },
      );
      await _repo.addPrepPhotos(prepId: id, storagePaths: result.paths);
      if (!mounted) return;
      setState(() {
        _picked
          ..clear()
          ..addAll(result.failed);
      });
      if (result.failed.isNotEmpty) {
        Ui.error(context, AppStrings.uploadFailedSome(result.failed.length));
      } else if (resend) {
        await _repo.resubmitPrep(id);
        if (mounted) Ui.success(context, AppStrings.prepResent);
      } else {
        Ui.success(context, AppStrings.submittedSuccessfully);
      }
      session.markChanged();
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _progress = null);
      await _reload();
    }
  }

  Future<void> _removeStored(LessonPrepPhoto photo) async {
    final yes = await Ui.confirm(
      context,
      title: AppStrings.removeFileTitle,
      confirmLabel: AppStrings.delete,
      destructive: true,
    );
    if (!yes || !mounted) return;
    final ok = await Ui.runGuarded(context, () => _repo.removePrepPhoto(photo));
    if (ok) await _reload();
  }

  // ── page ──────────────────────────────────────────────────────────────────

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
          builder: (context, prep, _) => _page(prep),
        ),
      ),
    );
  }

  Widget _page(LessonPrep? prep) {
    final editable = prep == null || prep.isPending || prep.isCommented;
    final stored = prep?.photos ?? const <LessonPrepPhoto>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        if (prep != null) ...[
          _StatusCard(prep: prep),
          // What أمين الخدمة asked for comes first.
          if (prep.adminComment != null &&
              prep.adminComment!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionCard(
              title: AppStrings.adminCommentTitle,
              icon: Icons.chat_bubble_rounded,
              accent: AppColors.sky,
              child: Text(
                prep.adminComment!,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        // The lesson this prep is for, from the weekly programme.
        LessonOfDay(
          date: widget.sessionDate,
          title: AppStrings.lessonForPrep,
          showExtras: false,
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: AppStrings.lessonPrepTitle,
          icon: Icons.photo_library_rounded,
          accent: AppColors.olive,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stored.isEmpty && _picked.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    AppStrings.prepAddFilesHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              if (stored.isNotEmpty || _picked.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in stored)
                      _StoredFile(
                        photo: p,
                        onRemove: editable && !_busy
                            ? () => _removeStored(p)
                            : null,
                      ),
                    for (final f in _picked)
                      _PickedFile(
                        file: f,
                        onRemove: _busy
                            ? null
                            : () => setState(() => _picked.remove(f)),
                      ),
                  ],
                ),
              if (_picked.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.prepNewFiles}: ${pickedSummary(_picked)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
              if (editable) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pickPhotos(),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text(AppStrings.pickPhotos),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: AppStrings.takePhoto,
                      onPressed: _busy ? null : () => _pickPhotos(camera: true),
                      icon: const Icon(Icons.photo_camera_outlined),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickPdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text(AppStrings.pickPdf),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_progress != null) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress!.$2 == 0 ? null : _progress!.$1 / _progress!.$2,
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.uploadingProgress(_progress!.$1, _progress!.$2),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
        if (editable) ...[
          const SizedBox(height: 16),
          _sendButton(prep),
        ],
      ],
    );
  }

  Widget _sendButton(LessonPrep? prep) {
    final (label, icon) = prep == null
        ? (AppStrings.submitLessonPrep, Icons.upload_rounded)
        : prep.isCommented
            ? (AppStrings.prepResend, Icons.send_rounded)
            : (AppStrings.prepUploadAdded, Icons.upload_rounded);
    // A waiting prep needs new files to upload; a commented one can be sent
    // back as it is once its files are fixed.
    final enabled = !_busy &&
        (_picked.isNotEmpty ||
            (prep != null && prep.isCommented && prep.photos.isNotEmpty));
    return FilledButton.icon(
      onPressed: enabled ? () => _send(prep) : null,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// The status, and the "shared as an example" mark when it is.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.prep});

  final LessonPrep prep;

  @override
  Widget build(BuildContext context) {
    final color = prepStatusColor(prep.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(prepStatusIcon(prep.status), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prepStatusLabel(prep.status),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.readable(color),
                  ),
                ),
                if (prep.isCommented)
                  const Text(
                    AppStrings.prepFixHint,
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          if (prep.isShared)
            const Tooltip(
              message: AppStrings.prepSharedAsExample,
              child: Chip(
                avatar: Icon(Icons.star_rounded,
                    size: 16, color: AppColors.gold),
                label: Text(AppStrings.prepSharedShort),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

const double _thumb = 104;

/// A chosen file: its preview (or a PDF card) with a remove button.
class _PickedFile extends StatelessWidget {
  const _PickedFile({required this.file, required this.onRemove});

  final PickedPrepFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget body = file.isPdf
        ? _FileCard(
            icon: Icons.picture_as_pdf_rounded,
            label: file.file.name,
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              file.bytes,
              width: _thumb,
              height: _thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _FileCard(
                icon: Icons.insert_drive_file_outlined,
                label: file.file.name,
              ),
            ),
          );
    return _Removable(onRemove: onRemove, child: body);
  }
}

/// A sent file: the picture (full screen on tap), or a PDF card that opens
/// it. A picture that cannot be drawn offers to open the file instead, and a
/// link that cannot be made offers a retry instead of spinning forever.
class _StoredFile extends StatefulWidget {
  const _StoredFile({required this.photo, required this.onRemove});

  final LessonPrepPhoto photo;
  final VoidCallback? onRemove;

  @override
  State<_StoredFile> createState() => _StoredFileState();
}

class _StoredFileState extends State<_StoredFile> {
  String? _url;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _sign();
  }

  Future<void> _sign() async {
    setState(() => _failed = false);
    final url = await PhotoService.signedUrl(
      bucket: Db.bucketServantSubmissions,
      path: widget.photo.storagePath,
    );
    if (!mounted) return;
    setState(() {
      _url = url;
      _failed = url == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = FileKind.isPdfPath(widget.photo.storagePath);
    final Widget body;
    if (_failed) {
      body = _FileCard(
        icon: Icons.refresh_rounded,
        label: AppStrings.couldNotLoad,
        onTap: _sign,
      );
    } else if (_url == null) {
      body = const SizedBox(
        width: _thumb,
        height: _thumb,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (isPdf) {
      body = _FileCard(
        icon: Icons.picture_as_pdf_rounded,
        label: AppStrings.pdfFile,
        onTap: () => launchUrl(
          Uri.parse(_url!),
          mode: LaunchMode.externalApplication,
        ),
      );
    } else {
      body = GestureDetector(
        onTap: () => showZoomableImage(context, _url!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _url!,
            width: _thumb,
            height: _thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => FileFallbackCard(
              url: _url,
              width: _thumb,
              height: _thumb,
            ),
          ),
        ),
      );
    }
    return _Removable(onRemove: widget.onRemove, child: body);
  }
}

class _Removable extends StatelessWidget {
  const _Removable({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _thumb,
      height: _thumb,
      child: Stack(
        children: [
          Positioned.fill(child: child),
          if (onRemove != null)
            PositionedDirectional(
              top: 2,
              end: 2,
              child: Material(
                color: AppColors.danger,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: _thumb,
          height: _thumb,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.danger, size: 30),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
