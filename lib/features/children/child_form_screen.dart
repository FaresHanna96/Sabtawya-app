import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/services/photo_service.dart';
import '../../data/supabase/db.dart';
import '../../state/session_controller.dart';
import 'child_avatar.dart';

/// Add or edit a child.
///
/// The class dropdown is populated through the class repository, which is
/// already restricted by row level security, so a servant can only ever file a
/// child under a class they are assigned to.
class ChildFormScreen extends StatefulWidget {
  const ChildFormScreen({super.key, this.child, this.initialClassId});

  final Child? child;
  final String? initialClassId;

  bool get isEdit => child != null;

  @override
  State<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends State<ChildFormScreen> {
  static const _repository = ChildRepository();
  static const _classes = ClassRepository();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name =
      TextEditingController(text: widget.child?.fullName ?? '');
  late final TextEditingController _mobile =
      TextEditingController(text: widget.child?.mobile ?? '');
  late final TextEditingController _motherName =
      TextEditingController(text: widget.child?.motherName ?? '');
  late final TextEditingController _motherMobile =
      TextEditingController(text: widget.child?.motherMobile ?? '');
  late final TextEditingController _fatherName =
      TextEditingController(text: widget.child?.fatherName ?? '');
  late final TextEditingController _fatherMobile =
      TextEditingController(text: widget.child?.fatherMobile ?? '');
  late final TextEditingController _confessionFather =
      TextEditingController(text: widget.child?.confessionFather ?? '');
  late final TextEditingController _school =
      TextEditingController(text: widget.child?.school ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.child?.address ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.child?.notes ?? '');

  String? _classId;

  /// The row inserted by an earlier save attempt in this form, if any.
  Child? _created;
  Gender _gender = Gender.boy;
  DateTime? _birthDate;

  /// A photo chosen but not uploaded yet: the upload needs the child id, which
  /// a new child only gets once the row is inserted.
  XFile? _pickedPhoto;
  Uint8List? _photoPreview;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _classId = widget.child?.classId ?? widget.initialClassId;
    _gender = widget.child?.gender ?? Gender.boy;
    _birthDate = widget.child?.birthDate;
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _mobile,
      _motherName,
      _motherMobile,
      _fatherName,
      _fatherMobile,
      _confessionFather,
      _school,
      _address,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: AppStrings.pickBirthDate,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _choosePhoto() async {
    final hasPhoto = _pickedPhoto != null ||
        (!_removePhoto && (widget.child?.hasPhoto ?? false));

    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(AppStrings.takePhoto),
              onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.fromGallery),
              onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
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
        _pickedPhoto = null;
        _photoPreview = null;
        _removePhoto = true;
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
        _pickedPhoto = file;
        _photoPreview = bytes;
        _removePhoto = false;
      });
    } catch (e) {
      if (mounted) Ui.error(context, e);
    }
  }

  /// Applies the pending photo choice once the child row exists.
  Future<void> _syncPhoto(Child saved) async {
    final picked = _pickedPhoto;

    if (picked != null) {
      final path = await PhotoService.upload(
        bucket: Db.bucketChildPhotos,
        ownerId: saved.id,
        file: picked,
      );
      await _repository.setPhoto(childId: saved.id, path: path);
      // Drop the file the child used to point at, now that nothing refers to it.
      await PhotoService.remove(
        bucket: Db.bucketChildPhotos,
        path: widget.child?.photoPath,
      );
      return;
    }

    if (_removePhoto && (widget.child?.hasPhoto ?? false)) {
      await _repository.setPhoto(childId: saved.id, path: null);
      await PhotoService.remove(
        bucket: Db.bucketChildPhotos,
        path: widget.child?.photoPath,
      );
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final classId = _classId;
    if (classId == null) {
      Ui.info(context, AppStrings.selectClass);
      return;
    }
    FocusScope.of(context).unfocus();

    // If a previous attempt created the row but the photo step failed, saving
    // again must update that row, not insert a duplicate child.
    final target = widget.child ?? _created;

    final draft = Child(
      id: target?.id ?? '',
      classId: classId,
      fullName: _name.text,
      gender: _gender,
      isActive: target?.isActive ?? true,
      birthDate: _birthDate,
      code: target?.code,
      mobile: _mobile.text,
      motherName: _motherName.text,
      motherMobile: _motherMobile.text,
      fatherName: _fatherName.text,
      fatherMobile: _fatherMobile.text,
      confessionFather: _confessionFather.text,
      school: _school.text,
      address: _address.text,
      notes: _notes.text,
    );

    Child? stored;
    final saved = await Ui.runGuarded(
      context,
      () async {
        stored = target != null
            ? await _repository.update(draft)
            : await _repository.create(draft);
        if (target == null) _created = stored;
        await _syncPhoto(stored!);
      },
    );

    if (saved && mounted) {
      final code = stored?.code;
      Ui.success(
        context,
        (code == null || code.isEmpty)
            ? AppStrings.childSaved
            : '${AppStrings.childSaved} — $code',
      );
      // The class counters on the dashboard change with every add.
      await context.read<SessionController>().refreshClasses();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? AppStrings.editChild : AppStrings.addChild),
      ),
      body: AsyncSection<List<SchoolClass>>(
        load: () => _classes.list(),
        enableRefresh: false,
        builder: (context, classes, reload) {
          if (_classId == null && classes.isNotEmpty) {
            _classId = classes.first.id;
          }
          // An archived class (or one the servant no longer serves) may be
          // missing from the list; a dropdown whose value has no matching item
          // throws, so keep the child's current class as an extra entry.
          final items = <SchoolClass>[...classes];
          final currentId = _classId;
          if (currentId != null && !items.any((c) => c.id == currentId)) {
            if (widget.isEdit) {
              items.add(SchoolClass(
                id: currentId,
                name: AppStrings.classLabel,
                sortOrder: 0,
                isActive: false,
              ));
            } else {
              _classId = items.isEmpty ? null : items.first.id;
            }
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _photoPicker(),
                _group(AppStrings.personalInfo, [
                  DropdownButtonFormField<String>(
                    initialValue: _classId,
                    decoration: const InputDecoration(
                      labelText: AppStrings.classLabel,
                      prefixIcon: Icon(Icons.class_outlined),
                    ),
                    items: items
                        .map((item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _classId = value),
                    validator: (value) =>
                        value == null ? AppStrings.selectClass : null,
                  ),
                  _field(
                    controller: _name,
                    label: AppStrings.childName,
                    icon: Icons.person_outline,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? AppStrings.childNameRequired
                        : null,
                    textCapitalization: TextCapitalization.words,
                  ),
                  _genderPicker(),
                  _birthDateField(),
                  _field(
                    controller: _mobile,
                    label: AppStrings.childMobile,
                    icon: Icons.phone_outlined,
                    isPhone: true,
                  ),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: AppStrings.childCode,
                      helperText: AppStrings.childCodeHint,
                      prefixIcon: Icon(Icons.tag),
                    ),
                    child: Text(
                      (widget.child?.code?.isNotEmpty ?? false)
                          ? widget.child!.code!
                          : AppStrings.childCodePending,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: (widget.child?.code?.isNotEmpty ?? false)
                            ? null
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ]),
                _group(AppStrings.parentsInfo, [
                  _field(
                    controller: _motherName,
                    label: AppStrings.motherName,
                    icon: Icons.woman_outlined,
                  ),
                  _field(
                    controller: _motherMobile,
                    label: AppStrings.motherMobile,
                    icon: Icons.phone_outlined,
                    isPhone: true,
                  ),
                  _field(
                    controller: _fatherName,
                    label: AppStrings.fatherName,
                    icon: Icons.man_outlined,
                  ),
                  _field(
                    controller: _fatherMobile,
                    label: AppStrings.fatherMobile,
                    icon: Icons.phone_outlined,
                    isPhone: true,
                  ),
                ]),
                _group(AppStrings.churchInfo, [
                  _field(
                    controller: _confessionFather,
                    label: AppStrings.confessionFather,
                    icon: Icons.church_outlined,
                  ),
                ]),
                _group(AppStrings.schoolInfo, [
                  _field(
                    controller: _school,
                    label: AppStrings.school,
                    icon: Icons.apartment_outlined,
                  ),
                  _field(
                    controller: _address,
                    label: AppStrings.address,
                    icon: Icons.location_on_outlined,
                  ),
                  _field(
                    controller: _notes,
                    label: AppStrings.notes,
                    icon: Icons.notes_outlined,
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text(AppStrings.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _photoPicker() {
    // A throwaway child just for display, carrying the gender currently
    // selected so the placeholder matches what is being typed in.
    final display = (widget.child ?? Child.empty(_classId ?? '')).copyWith(
      gender: _gender,
      clearPhoto: _removePhoto,
    );
    final hasPhoto = _photoPreview != null || display.hasPhoto;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          InkWell(
            onTap: _choosePhoto,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ChildAvatar(
                  child: display,
                  size: 104,
                  localPreview: _photoPreview,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
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
            onPressed: _choosePhoto,
            child: Text(hasPhoto ? AppStrings.changePhoto : AppStrings.addPhoto),
          ),
        ],
      ),
    );
  }

  Widget _genderPicker() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: AppStrings.gender,
        prefixIcon: Icon(Icons.wc_outlined),
      ),
      child: SegmentedButton<Gender>(
        segments: Gender.values
            .map(
              (gender) => ButtonSegment<Gender>(
                value: gender,
                label: Text(gender.label),
                icon: Icon(
                  gender == Gender.boy ? Icons.boy_outlined : Icons.girl_outlined,
                ),
              ),
            )
            .toList(),
        selected: <Gender>{_gender},
        showSelectedIcon: false,
        onSelectionChanged: (selection) =>
            setState(() => _gender = selection.first),
      ),
    );
  }

  Widget _birthDateField() {
    final age = _birthDate == null
        ? null
        : Child(
            id: '',
            classId: '',
            fullName: '',
            gender: _gender,
            isActive: true,
            birthDate: _birthDate,
          ).ageLabel;

    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.birthDate,
          prefixIcon: const Icon(Icons.cake_outlined),
          suffixIcon: _birthDate == null
              ? const Icon(Icons.calendar_today_outlined, size: 20)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _birthDate = null),
                ),
          helperText: age,
        ),
        child: Text(
          _birthDate == null
              ? AppStrings.pickBirthDate
              : AppDateUtils.formatDate(_birthDate!),
          style: TextStyle(
            fontSize: 15,
            color: _birthDate == null ? AppColors.muted : null,
          ),
        ),
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
          ),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool isPhone = false,
    String? helper,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: isPhone
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: Icon(icon),
      ),
      validator: validator ?? (isPhone ? _validatePhone : null),
    );
  }

  static String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return (text.length < 7 || text.length > 15) ? AppStrings.mobileInvalid : null;
  }
}

enum _PhotoAction { camera, gallery, remove }
