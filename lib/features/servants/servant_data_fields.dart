import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';

/// The controllers behind the servant data fields, shared by the add form and
/// the edit screen so both ask for exactly the same things.
class ServantDataControllers {
  ServantDataControllers({
    String? address,
    String? confessor,
    String? occupation,
    this.birthDate,
  })  : address = TextEditingController(text: address),
        confessor = TextEditingController(text: confessor),
        occupation = TextEditingController(text: occupation);

  final TextEditingController address;
  final TextEditingController confessor;
  final TextEditingController occupation;
  DateTime? birthDate;

  void dispose() {
    address.dispose();
    confessor.dispose();
    occupation.dispose();
  }
}

/// بيانات الخادم: address, confessor, study/work, service year and birth date.
class ServantDataFields extends StatelessWidget {
  const ServantDataFields({
    super.key,
    required this.controllers,
    required this.onChanged,
  });

  final ServantDataControllers controllers;

  /// Called after the birth date changes so the parent can rebuild.
  final VoidCallback onChanged;

  Future<void> _pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controllers.birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      controllers.birthDate = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final birth = controllers.birthDate;
    return SectionCard(
      title: AppStrings.servantData,
      icon: Icons.badge_rounded,
      accent: AppColors.navyLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            AppStrings.servantDataHint,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pickBirthDate(context),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: AppStrings.birthDate,
                helperText: AppStrings.optional,
                prefixIcon: Icon(Icons.cake_outlined),
              ),
              child: Text(
                birth == null ? '—' : AppDateUtils.formatDate(birth),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.address,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: AppStrings.address,
              helperText: AppStrings.optional,
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.confessor,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: AppStrings.confessor,
              helperText: AppStrings.optional,
              prefixIcon: Icon(Icons.church_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controllers.occupation,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: AppStrings.occupation,
              helperText: AppStrings.optional,
              prefixIcon: Icon(Icons.work_outline),
            ),
          ),
        ],
      ),
    );
  }
}
