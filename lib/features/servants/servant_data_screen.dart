import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import 'servant_data_fields.dart';

/// أمين الخدمة's view of one servant's data, editable in place.
class ServantDataScreen extends StatefulWidget {
  const ServantDataScreen({
    super.key,
    required this.servant,
    required this.details,
    required this.classes,
    required this.assignment,
  });

  final Profile servant;
  final ServantDetails? details;

  /// Every class a servant can be attached to.
  final List<SchoolClass> classes;

  /// The servant's current class, if any (a servant serves one class).
  final ClassServant? assignment;

  @override
  State<ServantDataScreen> createState() => _ServantDataScreenState();
}

class _ServantDataScreenState extends State<ServantDataScreen> {
  static const _repository = ServantRepository();
  static const _classes = ClassRepository();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.servant.fullName);
  late final TextEditingController _mobile =
      TextEditingController(text: widget.servant.mobile);
  late final ServantDataControllers _data = ServantDataControllers(
    address: widget.details?.address,
    confessor: widget.details?.confessor,
    occupation: widget.details?.occupation,
    birthDate: widget.servant.birthDate,
  );

  late String? _classId = widget.assignment?.classId;

  /// خادم عام: serves everyone, so no class. Not offered for أمين الخدمة.
  late bool _general = widget.servant.isGeneralServant;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _data.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final ok = await Ui.runGuarded(
      context,
      () async {
        await _repository.saveDetails(
          servantId: widget.servant.id,
          fullName: _name.text,
          mobile: _mobile.text,
          birthDate: _data.birthDate,
          address: _data.address.text,
          confessor: _data.confessor.text,
          occupation: _data.occupation.text,
          role: _newRole,
        );
        await _saveClass();
      },
      successMessage: AppStrings.saved,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  /// The role to write, or null when it does not change.
  AppRole? get _newRole {
    if (widget.servant.isAdmin) return null;
    final wanted = _general ? AppRole.generalServant : AppRole.servant;
    return wanted == widget.servant.role ? null : wanted;
  }

  /// The class is a real relation (`class_servants`), not a text field.
  Future<void> _saveClass() async {
    final before = widget.assignment;
    if (_classId == before?.classId) return;
    if (_classId == null) {
      if (before != null) await _classes.removeAssignment(before.assignmentId);
    } else {
      await _classes.assignServant(
        classId: _classId!,
        servantId: widget.servant.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.servant.fullName)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: staggerAll([
              SectionCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: AppStrings.servantName,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? AppStrings.servantNameRequired
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: AppStrings.mobile,
                        helperText: AppStrings.optional,
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    if (widget.servant.email != null) ...[
                      const SizedBox(height: 4),
                      InfoRow(
                        label: AppStrings.email,
                        value: widget.servant.email,
                        icon: Icons.alternate_email,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.classLabel,
                icon: Icons.class_rounded,
                accent: AppColors.olive,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!widget.servant.isAdmin)
                      FilterChip(
                        avatar: const Icon(Icons.public_rounded, size: 16),
                        label: const Text(AppStrings.roleGeneralServant),
                        selected: _general,
                        onSelected: (selected) => setState(() {
                          _general = selected;
                          if (selected) _classId = null;
                        }),
                      ),
                    for (final item in widget.classes)
                      FilterChip(
                        label: Text(item.name),
                        selected: _classId == item.id,
                        onSelected: (selected) => setState(() {
                          _classId = selected ? item.id : null;
                          if (selected) _general = false;
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ServantDataFields(
                controllers: _data,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text(AppStrings.save),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
