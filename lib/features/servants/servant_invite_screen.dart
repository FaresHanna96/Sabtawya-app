import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import 'servant_data_fields.dart';

/// Creates an invite for a new servant.
///
/// A mobile app has no service-role key and therefore cannot create an auth
/// user. Instead this records the email, role, and classes; the `handle_new_user`
/// trigger applies them the moment that email signs up, which also means the
/// role can never be chosen by the person registering.
class ServantInviteScreen extends StatefulWidget {
  const ServantInviteScreen({super.key});

  @override
  State<ServantInviteScreen> createState() => _ServantInviteScreenState();
}

class _ServantInviteScreenState extends State<ServantInviteScreen> {
  static const _repository = ServantRepository();
  static const _classes = ClassRepository();

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _data = ServantDataControllers();

  AppRole _role = AppRole.servant;
  final Set<String> _classIds = <String>{};

  @override
  void dispose() {
    _email.dispose();
    _fullName.dispose();
    _mobile.dispose();
    _data.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!Ui.requireOnline(context)) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final ok = await Ui.runGuarded(
      context,
      () => _repository.createInvite(
        email: _email.text,
        fullName: _fullName.text,
        role: _role,
        mobile: _mobile.text,
        birthDate: _data.birthDate,
        address: _data.address.text,
        confessor: _data.confessor.text,
        occupation: _data.occupation.text,
        classIds: _classIds.toList(),
      ),
      successMessage: AppStrings.inviteCreated,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.addServant)),
      body: SafeArea(
        child: AsyncSection<List<SchoolClass>>(
          load: () => _classes.list(),
          enableRefresh: false,
          builder: (context, classes, reload) => Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullName,
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
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: AppStrings.email,
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: _validateEmail,
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
                      const SizedBox(height: 14),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: AppStrings.role,
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        child: SegmentedButton<AppRole>(
                          segments: AppRole.values
                              .map(
                                (role) => ButtonSegment<AppRole>(
                                  value: role,
                                  label: Text(role.label),
                                ),
                              )
                              .toList(),
                          selected: <AppRole>{_role},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) =>
                              setState(() => _role = selection.first),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ServantDataFields(
                  controllers: _data,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: AppStrings.assignedClasses,
                  icon: Icons.class_rounded,
                  accent: AppColors.olive,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        AppStrings.inviteHint,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        AppStrings.servantOneClass,
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: classes
                            .map(
                              (item) => FilterChip(
                                label: Text(item.name),
                                selected: _classIds.contains(item.id),
                                onSelected: (selected) => setState(() {
                                  _classIds.clear();
                                  if (selected) _classIds.add(item.id);
                                }),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text(AppStrings.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return AppStrings.emailRequired;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : AppStrings.emailInvalid;
  }
}
