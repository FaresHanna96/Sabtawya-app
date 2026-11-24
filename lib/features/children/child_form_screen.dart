import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/unsaved_changes_guard.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/map_location.dart';
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
import 'child_profile_screen.dart';
import 'location_editor.dart';
import 'similar_children_dialog.dart';
import '../../core/widgets/date_picker.dart';

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
  /// Something was changed and not saved yet: leaving asks first.
  bool _dirty = false;

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
  MapLocation? _location;

  late final TextEditingController _notes =
      TextEditingController(text: widget.child?.notes ?? '');

  String? _classId;

  /// The row inserted by an earlier save attempt in this form, if any.
  Child? _created;
  Gender _gender = Gender.boy;
  bool _isDeacon = false;
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
    _isDeacon = widget.child?.isDeacon ?? false;
    _birthDate = widget.child?.birthDate;
    _location = widget.child?.location;
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
    final picked = await pickDate(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 10, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: AppStrings.pickBirthDate,
    );
    if (picked != null) {
      setState(() {
        _dirty = true;
        _birthDate = picked;
      });
    }
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

  /// True when the child may be added: nobody looks the same, the person said
  /// it is a different child, or the check could not run (no connection).
  /// Opening the existing child's profile replaces this form.
  Future<bool> _confirmNotDuplicate(Child draft) async {
    List<SimilarChild> matches;
    try {
      final found = await _repository.similar([
        SimilarQuery(
          key: '',
          name: draft.fullName,
          mobiles: [draft.mobile, draft.motherMobile, draft.fatherMobile],
        ),
      ]);
      matches = found[''] ?? const <SimilarChild>[];
    } catch (_) {
      return true;
    }
    if (matches.isEmpty || !mounted) return true;

    final session = context.read<SessionController>();
    final choice = await showSimilarChildrenDialog(
      context,
      matches,
      canOpen: (classId) =>
          session.isAdmin ||
          session.isGeneralServant ||
          session.myClasses.any((c) => c.classId == classId),
    );
    if (!mounted) return false;
    switch (choice) {
      case SaveAnyway():
        return true;
      case GoBack():
        return false;
      case OpenExisting(:final childId):
        await Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => ChildProfileScreen(childId: childId),
          ),
        );
        return false;
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
      isDeacon: _gender == Gender.boy && _isDeacon,
      school: _school.text,
      address: _address.text,
      notes: _notes.text,
      latitude: _location?.latitude,
      longitude: _location?.longitude,
    );

    // A new child: warn first when one that looks the same is registered.
    if (target == null && !await _confirmNotDuplicate(draft)) return;
    if (!mounted) return;

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
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(widget.isEdit ? AppStrings.editChild : AppStrings.addChild),
        ),
        // The save button stays in reach however far down the form is.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text(AppStrings.save),
            ),
          ),
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
              onChanged: () {
                if (!_dirty) setState(() => _dirty = true);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: staggerAll([
                  _photoPicker(),
                  _group(AppStrings.personalInfo, Icons.badge_rounded, AppColors.navy, [
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
                      onChanged: (value) => setState(() {
                        _dirty = true;
                        _classId = value;
                      }),
                      validator: (value) =>
                          value == null ? AppStrings.selectClass : null,
                    ),
                    _field(
                      controller: _name,
                      label: AppStrings.childName,
                      icon: Icons.person_outline,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) return AppStrings.childNameRequired;
                        if (!RegExp(r'^[؀-ۿ\s]+$').hasMatch(v)) {
                          return AppStrings.nameArabicOnly;
                        }
                        return null;
                      },
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tag,
                              size: 20, color: AppColors.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (widget.child?.code?.isNotEmpty ?? false)
                                      ? '${AppStrings.childCode}: ${widget.child!.code!}'
                                      : '${AppStrings.childCode}: ${AppStrings.childCodePending}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5),
                                ),
                                const Text(
                                  AppStrings.childCodeHint,
                                  style: TextStyle(
                                      fontSize: 11.5, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _group(AppStrings.parentsInfo, Icons.family_restroom_rounded, AppColors.olive, [
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
                  _group(AppStrings.churchInfo, Icons.church_rounded, AppColors.maroon, [
                    _field(
                      controller: _confessionFather,
                      label: AppStrings.confessionFather,
                      icon: Icons.church_outlined,
                    ),
                    if (_gender == Gender.boy)
                      CheckboxListTile(
                        value: _isDeacon,
                        onChanged: (value) => setState(() {
                          _dirty = true;
                          _isDeacon = value ?? false;
                        }),
                        title: const Text(AppStrings.deacon),
                        secondary:
                            const Icon(Icons.volunteer_activism_outlined),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ]),
                  _group(AppStrings.schoolInfo, Icons.school_rounded, AppColors.sky, [
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
                    LocationEditor(
                      value: _location,
                      onChanged: (v) => setState(() {
                        _dirty = true;
                        _location = v;
                      }),
                    ),
                    _field(
                      controller: _notes,
                      label: AppStrings.notes,
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                  ]),
                ]),
              ),
            );
          },
        ),
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
            child:
                Text(hasPhoto ? AppStrings.changePhoto : AppStrings.addPhoto),
          ),
        ],
      ),
    );
  }

  Widget _genderPicker() {
    Widget tile(Gender gender, IconData icon, Color color) {
      final on = _gender == gender;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() {
            _dirty = true;
            _gender = gender;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: on ? color.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: on ? color : AppColors.muted.withValues(alpha: 0.3),
                width: on ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: on ? color : AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  gender.label,
                  style: TextStyle(
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                    color: on ? AppColors.readable(color) : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6, right: 4),
          child: Text(AppStrings.gender,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ),
        Row(
          children: [
            tile(Gender.boy, Icons.boy_rounded, AppColors.sky),
            const SizedBox(width: 10),
            tile(Gender.girl, Icons.girl_rounded, AppColors.coral),
          ],
        ),
      ],
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
                  tooltip: AppStrings.clearField,
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() {
                    _dirty = true;
                    _birthDate = null;
                  }),
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

  /// A section as its own card: a coloured icon and title, then its fields.
  Widget _group(
      String title, IconData icon, Color color, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.readable(color),
                    ),
                  ),
                ],
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
    return (text.length < 7 || text.length > 15)
        ? AppStrings.mobileInvalid
        : null;
  }
}

enum _PhotoAction { camera, gallery, remove }
