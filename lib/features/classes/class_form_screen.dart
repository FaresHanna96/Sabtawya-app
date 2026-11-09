import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import 'patron_avatar.dart';

/// Admin-only add/edit form for a class. The policies reject the write for a
/// servant even if this screen were reached another way.
class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.existing});

  final SchoolClass? existing;

  bool get isEditing => existing != null;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  static const _repository = ClassRepository();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _patronName;
  XFile? _pickedPatron;
  Uint8List? _patronPreview;
  bool _removePatron = false;

  /// Id of the class inserted by an earlier attempt in this form, if any.
  String? _createdId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _patronName = TextEditingController(text: existing?.patronName ?? '');
  }

  /// The service's fixed class names (grades 3-6, boys and girls), plus the
  /// current name when a class was saved under something else.
  List<String> get _classNameOptions {
    final names = [
      for (final grade in [3, 4, 5, 6]) ...['$grade ولاد', '$grade بنات'],
    ];
    final current = _name.text.trim();
    if (current.isNotEmpty && !names.contains(current)) {
      names.insert(0, current);
    }
    return names;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _patronName.dispose();
    super.dispose();
  }

  Future<void> _choosePatronPhoto() async {
    final hasPhoto = _pickedPatron != null ||
        (!_removePatron && (widget.existing?.hasPatronPhoto ?? false));

    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.fromGallery),
              onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(AppStrings.takePhoto),
              onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text(
                  AppStrings.removePhoto,
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    if (action == _PhotoAction.remove) {
      setState(() {
        _pickedPatron = null;
        _patronPreview = null;
        _removePatron = true;
      });
      return;
    }

    try {
      final file = await PhotoService.pick(
        fromCamera: action == _PhotoAction.camera,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedPatron = file;
        _patronPreview = bytes;
        _removePatron = false;
      });
    } catch (e) {
      if (mounted) Ui.error(context, e);
    }
  }

  /// Applies the pending picture choice once the class row exists.
  Future<void> _syncPatronPhoto(String classId) async {
    final picked = _pickedPatron;
    final previous = widget.existing?.patronPhotoPath;

    if (picked != null) {
      final path = await PhotoService.upload(
        bucket: Db.bucketClassPatrons,
        ownerId: classId,
        file: picked,
      );
      await _repository.setPatronPhoto(classId: classId, path: path);
      await PhotoService.remove(
        bucket: Db.bucketClassPatrons,
        path: previous,
      );
      return;
    }

    if (_removePatron && (widget.existing?.hasPatronPhoto ?? false)) {
      await _repository.setPatronPhoto(classId: classId, path: null);
      await PhotoService.remove(
        bucket: Db.bucketClassPatrons,
        path: previous,
      );
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _name.text.trim();
    final description = _description.text.trim();
    final patronName = _patronName.text.trim();
    final existing = widget.existing;

    final ok = await Ui.runGuarded(
      context,
      () async {
        // A retry after a failed photo upload must update the class created by
        // the first attempt; creating again would hit the unique name rule.
        final knownId = existing?.id ?? _createdId;
        if (knownId == null) {
          final classId = await _repository.create(
            name: name,
            description: description,
            patronName: patronName,
          );
          _createdId = classId;
          await _syncPatronPhoto(classId);
        } else {
          await _repository.update(
            classId: knownId,
            name: name,
            description: description,
            patronName: patronName,
          );
          await _syncPatronPhoto(knownId);
        }
      },
      successMessage: AppStrings.saved,
    );
    if (!ok || !mounted) return;

    await context.read<SessionController>().refreshClasses();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEditing ? AppStrings.editClass : AppStrings.addClass),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: staggerAll([
              SectionCard(
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _name.text.isEmpty ? null : _name.text,
                      decoration: const InputDecoration(
                        labelText: AppStrings.className,
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      items: [
                        for (final name in _classNameOptions)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (value) =>
                          setState(() => _name.text = value ?? ''),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? AppStrings.classNameRequired
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: AppStrings.classDescription,
                        helperText: AppStrings.optional,
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.patronSaint,
                icon: Icons.auto_awesome_rounded,
                accent: AppColors.gold,
                child: Column(
                  children: [
                    _patronPicker(),
                    TextFormField(
                      controller: _patronName,
                      decoration: const InputDecoration(
                        labelText: AppStrings.patronName,
                        helperText: AppStrings.optional,
                        prefixIcon: Icon(Icons.auto_awesome_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text(AppStrings.save),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _patronPicker() {
    final storedPath = _removePatron ? null : widget.existing?.patronPhotoPath;
    final hasPhoto = _patronPreview != null || storedPath != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          InkWell(
            onTap: _choosePatronPhoto,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                PatronAvatar(
                  photoPath: storedPath,
                  size: 104,
                  localPreview: _patronPreview,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.maroon,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasPhoto ? Icons.edit : Icons.photo_camera_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _choosePatronPhoto,
            child: Text(
              hasPhoto ? AppStrings.changePhoto : AppStrings.patronPhoto,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }
