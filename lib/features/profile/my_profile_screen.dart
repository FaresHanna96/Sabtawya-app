import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import '../servants/servant_data_fields.dart';

/// Every signed-in user edits their own data here. Role, class and activation
/// stay with the admin: this screen never sends them, and the database refuses
/// them from anyone but an admin anyway.
class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  static const _repository = ServantRepository();

  @override
  Widget build(BuildContext context) {
    final profile = context.read<SessionController>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myData)),
      body: SafeArea(
        child: profile == null
            ? const SizedBox.shrink()
            : AsyncSection<ServantDetails?>(
                load: _repository.myDetails,
                builder: (context, details, reload) =>
                    _Form(profile: profile, details: details),
              ),
      ),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form({required this.profile, required this.details});

  final Profile profile;
  final ServantDetails? details;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  static const _repository = ServantRepository();

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _mobile = TextEditingController(text: widget.profile.mobile);
  late final _data = ServantDataControllers(
    address: widget.details?.address,
    confessor: widget.details?.confessor,
    occupation: widget.details?.occupation,
    birthDate: widget.profile.birthDate,
  );

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
    final session = context.read<SessionController>();

    final ok = await Ui.runGuarded(
      context,
      () => _repository.saveDetails(
        servantId: widget.profile.id,
        fullName: _name.text,
        mobile: _mobile.text,
        birthDate: _data.birthDate,
        address: _data.address.text,
        confessor: _data.confessor.text,
        occupation: _data.occupation.text,
      ),
      successMessage: AppStrings.saved,
    );
    if (ok) {
      await session.refreshAll();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              AppStrings.myDataHint,
              style: TextStyle(fontSize: 13),
            ),
          ),
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
                  validator: (value) => (value == null || value.trim().isEmpty)
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
                if (widget.profile.email != null) ...[
                  const SizedBox(height: 4),
                  InfoRow(
                    label: AppStrings.email,
                    value: widget.profile.email,
                    icon: Icons.alternate_email,
                  ),
                ],
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
        ],
      ),
    );
  }
}
