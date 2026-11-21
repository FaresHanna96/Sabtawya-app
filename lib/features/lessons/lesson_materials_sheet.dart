import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/image_viewer.dart';
import '../../data/models/lesson.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';

/// "وسائل الإيضاح" of one lesson: what أمين الخدمة attached (PDFs, pictures,
/// links) and the preps he shared as examples. Opened from a lesson line.
Future<void> showLessonMaterials(
  BuildContext context, {
  required Lesson lesson,
}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => LessonMaterialsSheet(lesson: lesson),
    );

class LessonMaterialsSheet extends StatefulWidget {
  const LessonMaterialsSheet({super.key, required this.lesson});

  final Lesson lesson;

  @override
  State<LessonMaterialsSheet> createState() => _LessonMaterialsSheetState();
}

typedef _Data = ({List<LessonMaterial> materials, List<SharedPrep> preps});

class _LessonMaterialsSheetState extends State<LessonMaterialsSheet> {
  static const _repository = LessonRepository();
  final _key = GlobalKey<AsyncSectionState<_Data>>();

  Lesson get _lesson => widget.lesson;

  Future<_Data> _load() async {
    final materials = await _repository.materials(_lesson.slot, _lesson.grade);
    List<SharedPrep> preps;
    try {
      preps = await _repository.sharedPreps(_lesson.slot, _lesson.grade);
    } catch (_) {
      preps = const <SharedPrep>[]; // an extra; offline it is just left out
    }
    return (materials: materials, preps: preps);
  }

  Future<void> _reload() => _key.currentState?.reload() ?? Future.value();

  Future<void> _openFile(String bucket, String path) async {
    final url = await PhotoService.signedUrl(bucket: bucket, path: path);
    if (url == null) {
      if (mounted) Ui.info(context, AppStrings.materialUnavailable);
      return;
    }
    if (!mounted) return;
    if (path.toLowerCase().endsWith('.pdf')) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      await showZoomableImage(context, url);
    }
  }

  Future<void> _open(LessonMaterial m) async {
    if (m.isLink) {
      final uri = Uri.tryParse(m.url ?? '');
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await _openFile(Db.bucketLessonMaterials, m.storagePath!);
  }

  Future<void> _add() async {
    final draft = await showDialog<_MaterialDraft>(
      context: context,
      builder: (_) => _AddMaterialDialog(grade: _lesson.grade),
    );
    if (draft == null || !mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () => draft.file != null
          ? _repository.addFile(
              slot: _lesson.slot,
              grade: draft.allGrades ? null : _lesson.grade,
              title: draft.title,
              file: draft.file!,
            )
          : _repository.addLink(
              slot: _lesson.slot,
              grade: draft.allGrades ? null : _lesson.grade,
              title: draft.title,
              url: draft.url!,
            ),
      successMessage: AppStrings.materialAdded,
    );
    if (ok) await _reload();
  }

  Future<void> _delete(LessonMaterial m) async {
    final yes = await Ui.confirm(
      context,
      title: AppStrings.deleteMaterial,
      message: m.title,
      destructive: true,
    );
    if (!yes || !mounted) return;
    final ok =
        await Ui.runGuarded(context, () => _repository.deleteMaterial(m));
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final me = session.profile?.id;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (context, controller) => AsyncSection<_Data>(
        key: _key,
        load: _load,
        enableRefresh: false,
        builder: (context, data, reload) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              AppStrings.materialsTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '${AppStrings.gradeLabel(_lesson.grade)} • ${_lesson.title} • '
              '${_lesson.slot.label}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (data.materials.isEmpty && data.preps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AppStrings.noMaterials,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            for (final m in data.materials)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    m.isLink
                        ? Icons.link_rounded
                        : m.isPdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.image_outlined,
                    color: m.isPdf ? AppColors.danger : AppColors.sky,
                  ),
                  title: Text(m.title),
                  subtitle: Text(
                    [
                      if (m.authorName != null) m.authorName!,
                      if (m.grade == null) AppStrings.allGrades,
                    ].join(' • '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _open(m),
                  // أمين الخدمة removes any; a servant only their own.
                  trailing: isAdmin || (me != null && m.createdBy == me)
                      ? IconButton(
                          tooltip: AppStrings.deleteMaterial,
                          onPressed: () => _delete(m),
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.danger),
                        )
                      : null,
                ),
              ),
            OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addMaterial),
            ),
            if (data.preps.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                AppStrings.sharedPrepsTitle,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final p in data.preps)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.servantName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          AppDateUtils.formatDate(p.sessionDate),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (i, path) in p.storagePaths.indexed)
                              ActionChip(
                                avatar: Icon(
                                  path.toLowerCase().endsWith('.pdf')
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                  size: 18,
                                ),
                                label: Text('${AppStrings.prepFile} ${i + 1}'),
                                onPressed: () => _openFile(
                                    Db.bucketServantSubmissions, path),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialDraft {
  const _MaterialDraft({
    required this.title,
    required this.allGrades,
    this.url,
    this.file,
  });

  final String title;
  final bool allGrades;
  final String? url;
  final XFile? file;
}

/// A link or a file (PDF / picture), its title, and whether it is for every
/// grade.
class _AddMaterialDialog extends StatefulWidget {
  const _AddMaterialDialog({required this.grade});

  final int grade;

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _url = TextEditingController();
  bool _isLink = true;
  bool _allGrades = false;
  XFile? _file;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pick(bool pdf) async {
    try {
      final f = pdf
          ? await PhotoService.pickPdf()
          : await PhotoService.pick(fromCamera: false);
      if (f == null || !mounted) return;
      setState(() {
        _file = f;
        if (_title.text.trim().isEmpty) {
          final dot = f.name.lastIndexOf('.');
          _title.text = dot > 0 ? f.name.substring(0, dot) : f.name;
        }
      });
    } catch (e) {
      if (mounted) Ui.error(context, e);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isLink && _file == null) {
      Ui.info(context, AppStrings.pickFileFirst);
      return;
    }
    Navigator.of(context).pop(_MaterialDraft(
      title: _title.text,
      allGrades: _allGrades,
      url: _isLink ? _url.text.trim() : null,
      file: _isLink ? null : _file,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.addMaterial, style: TextStyle(fontSize: 17)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.link_rounded),
                    label: Text(AppStrings.materialLink),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.attach_file_rounded),
                    label: Text(AppStrings.materialFile),
                  ),
                ],
                selected: {_isLink},
                onSelectionChanged: (s) => setState(() => _isLink = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                maxLength: 120,
                decoration:
                    const InputDecoration(labelText: AppStrings.materialTitle),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? AppStrings.requiredField
                    : null,
              ),
              if (_isLink)
                TextFormField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: AppStrings.materialUrl,
                    hintText: 'https://',
                  ),
                  validator: (v) {
                    final uri = Uri.tryParse(v?.trim() ?? '');
                    final ok = uri != null &&
                        (uri.scheme == 'https' || uri.scheme == 'http') &&
                        uri.host.isNotEmpty;
                    return ok ? null : AppStrings.materialBadUrl;
                  },
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(true),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text(AppStrings.pdfFile),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(false),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text(AppStrings.picture),
                      ),
                    ),
                  ],
                ),
                if (_file != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _file!.name,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
              ],
              CheckboxListTile(
                value: _allGrades,
                onChanged: (v) => setState(() => _allGrades = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(AppStrings.forAllGrades,
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(onPressed: _submit, child: const Text(AppStrings.save)),
      ],
    );
  }
}
