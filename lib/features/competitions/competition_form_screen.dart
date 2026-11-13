import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/unsaved_changes_guard.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../data/models/competition.dart';
import '../../data/repositories/competition_repository.dart';

class CompetitionFormScreen extends StatefulWidget {
  const CompetitionFormScreen({super.key, this.competition});

  final Competition? competition;

  bool get isEdit => competition != null;

  @override
  State<CompetitionFormScreen> createState() => _CompetitionFormScreenState();
}

class _CompetitionFormScreenState extends State<CompetitionFormScreen> {
  /// Something was changed and not saved yet: leaving asks first.
  bool _dirty = false;

  static const _repository = CompetitionRepository();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.competition?.title ?? '');
  late final TextEditingController _maxMark =
      TextEditingController(text: '${widget.competition?.maxMark ?? 10}');

  late DateTime _weekDate = widget.competition?.weekDate ?? _nearestSaturday();

  @override
  void dispose() {
    _title.dispose();
    _maxMark.dispose();
    super.dispose();
  }

  static DateTime _nearestSaturday() {
    final now = DateTime.now();
    final daysUntilSaturday = (6 - now.weekday) % 7;
    return DateTime(now.year, now.month, now.day + daysUntilSaturday);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: AppStrings.competitionWeekDate,
    );
    if (picked != null) {
      setState(() {
        _dirty = true;
        _weekDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final title = _title.text.trim();
    final maxMark = int.tryParse(_maxMark.text.trim()) ?? 10;

    final saved = await Ui.runGuarded(
      context,
      () async {
        if (widget.isEdit) {
          await _repository.updateCompetition(
            widget.competition!.id,
            title: title,
            weekDate: _weekDate,
            maxMark: maxMark,
          );
        } else {
          await _repository.createCompetition(
            title: title,
            weekDate: _weekDate,
            maxMark: maxMark,
          );
        }
      },
    );

    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit
              ? AppStrings.editCompetition
              : AppStrings.addCompetition),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: AppStrings.competitionTitle,
                    prefixIcon: Icon(Icons.emoji_events_outlined),
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? AppStrings.competitionTitleRequired
                      : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: AppStrings.competitionWeekDate,
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      suffixIcon: Icon(Icons.edit_calendar_outlined, size: 20),
                    ),
                    child: Text(
                      AppDateUtils.formatDate(_weekDate),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maxMark,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: AppStrings.competitionMaxMark,
                    prefixIcon: Icon(Icons.star_border_outlined),
                    helperText: '1 – 100',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1 || n > 100) {
                      return '${AppStrings.competitionMaxMark}: 1–100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _MaxMarkPresets(
                  current: int.tryParse(_maxMark.text) ?? 10,
                  onSelect: (v) => setState(() => _maxMark.text = '$v'),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text(AppStrings.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaxMarkPresets extends StatelessWidget {
  const _MaxMarkPresets({required this.current, required this.onSelect});

  final int current;
  final void Function(int) onSelect;

  static const _presets = [5, 10, 20, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _presets.map((v) {
        final selected = current == v;
        return ChoiceChip(
          label: Text('$v'),
          selected: selected,
          selectedColor: AppColors.navy.withValues(alpha: 0.15),
          onSelected: (_) => onSelect(v),
        );
      }).toList(),
    );
  }
}
