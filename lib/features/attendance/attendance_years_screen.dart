import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../state/session_controller.dart';

/// Admin-only management of attendance years.
///
/// A year owns the scoring configuration and the Saturday calendar, so adding
/// next year is all it takes to carry the system forward: sessions are
/// generated from its start and end dates for every active class.
class AttendanceYearsScreen extends StatefulWidget {
  const AttendanceYearsScreen({super.key});

  @override
  State<AttendanceYearsScreen> createState() => _AttendanceYearsScreenState();
}

class _AttendanceYearsScreenState extends State<AttendanceYearsScreen> {
  static const _repository = AttendanceRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<AttendanceYear>>>();

  Future<void> _reload() async {
    await _sectionKey.currentState?.reload();
    if (mounted) await context.read<SessionController>().refreshAll();
  }

  Future<void> _addOrEdit([AttendanceYear? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _YearFormScreen(existing: existing),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _setCurrent(AttendanceYear year) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.setAsCurrent,
      message: year.name,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _repository.setCurrentYear(year.id),
      successMessage: AppStrings.saved,
    );
    if (ok) await _reload();
  }

  Future<void> _generate(AttendanceYear year) async {
    var created = 0;
    final ok = await Ui.runGuarded(
      context,
      () async {
        created = await _repository.generateSessions(yearId: year.id);
      },
    );
    if (!ok || !mounted) return;

    Ui.success(context, '${AppStrings.sessionsGenerated}: $created');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.attendanceYears)),
      body: SafeArea(
        child: AsyncSection<List<AttendanceYear>>(
          key: _sectionKey,
          load: _repository.years,
          builder: (context, years, reload) {
            if (years.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: AppStrings.noData,
                    action: FilledButton.icon(
                      onPressed: _addOrEdit,
                      icon: const Icon(Icons.add),
                      label: const Text(AppStrings.addAttendanceYear),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: years.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  staggered(index, Builder(builder: (context) {
                final year = years[index];
                return SectionCard(
                  title: year.name,
                  trailing: year.isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.olive.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            AppStrings.currentYear,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.olive,
                            ),
                          ),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InfoRow(
                        label: AppStrings.startDate,
                        value: AppDateUtils.formatDate(year.startDate),
                        icon: Icons.play_arrow_outlined,
                      ),
                      InfoRow(
                        label: AppStrings.endDate,
                        value: AppDateUtils.formatDate(year.endDate),
                        icon: Icons.stop_outlined,
                      ),
                      InfoRow(
                        label: AppStrings.pointsPerActivity,
                        value: '${year.pointsSundaySchool} / '
                            '${year.pointsVespers} / ${year.pointsMass} / '
                            '${year.pointsConfession}',
                        icon: Icons.star_outline,
                      ),
                      InfoRow(
                        label: AppStrings.maxPoints,
                        value: '${year.maxPointsPerSession}',
                        icon: Icons.emoji_events_outlined,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _addOrEdit(year),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text(AppStrings.edit),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _generate(year),
                            icon: const Icon(Icons.event_repeat, size: 16),
                            label: const Text(AppStrings.generateSessions),
                          ),
                          if (!year.isCurrent)
                            FilledButton.icon(
                              onPressed: () => _setCurrent(year),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text(AppStrings.setAsCurrent),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              })),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOrEdit,
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addAttendanceYear),
      ),
    );
  }
}

class _YearFormScreen extends StatefulWidget {
  const _YearFormScreen({this.existing});

  final AttendanceYear? existing;

  @override
  State<_YearFormScreen> createState() => _YearFormScreenState();
}

class _YearFormScreenState extends State<_YearFormScreen> {
  static const _repository = AttendanceRepository();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sundaySchool;
  late final TextEditingController _vespers;
  late final TextEditingController _mass;
  late final TextEditingController _confession;

  late DateTime _start;
  late DateTime _end;
  bool _makeCurrent = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final now = DateTime.now();

    _name = TextEditingController(text: existing?.name ?? '');
    _sundaySchool =
        TextEditingController(text: '${existing?.pointsSundaySchool ?? 5}');
    _vespers = TextEditingController(text: '${existing?.pointsVespers ?? 5}');
    _mass = TextEditingController(text: '${existing?.pointsMass ?? 5}');
    _confession =
        TextEditingController(text: '${existing?.pointsConfession ?? 5}');
    _start = existing?.startDate ?? DateTime(now.year, 10, 1);
    _end = existing?.endDate ?? DateTime(now.year + 1, 9, 30);
  }

  @override
  void dispose() {
    _name.dispose();
    _sundaySchool.dispose();
    _vespers.dispose();
    _mass.dispose();
    _confession.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_end.isAfter(_start)) {
      Ui.info(context, AppStrings.endBeforeStart);
      return;
    }

    final points = (
      sundaySchool: int.tryParse(_sundaySchool.text.trim()) ?? 5,
      vespers: int.tryParse(_vespers.text.trim()) ?? 5,
      mass: int.tryParse(_mass.text.trim()) ?? 5,
      confession: int.tryParse(_confession.text.trim()) ?? 5,
    );
    final existing = widget.existing;

    final ok = await Ui.runGuarded(
      context,
      () async {
        if (existing == null) {
          await _repository.createYear(
            name: _name.text,
            startDate: _start,
            endDate: _end,
            pointsSundaySchool: points.sundaySchool,
            pointsVespers: points.vespers,
            pointsMass: points.mass,
            pointsConfession: points.confession,
            makeCurrent: _makeCurrent,
          );
        } else {
          await _repository.updateYear(
            yearId: existing.id,
            name: _name.text,
            startDate: _start,
            endDate: _end,
            pointsSundaySchool: points.sundaySchool,
            pointsVespers: points.vespers,
            pointsMass: points.mass,
            pointsConfession: points.confession,
          );
        }
      },
      successMessage: AppStrings.saved,
    );
    if (ok && mounted && existing == null) await _offerPromotion();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  /// A new year is when classes grow a grade; ask before renaming anything.
  Future<void> _offerPromotion() async {
    if (!Ui.requireOnline(context)) return;
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.promoteClassesTitle,
      message: AppStrings.promoteClassesBody,
    );
    if (!confirmed || !mounted) return;
    final session = context.read<SessionController>();
    final ok = await Ui.runGuarded(
      context,
      () => const ClassRepository()
          .promoteGrades(archiveSuffix: _name.text.trim()),
      successMessage: AppStrings.saved,
    );
    if (ok) await session.refreshClasses();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? AppStrings.editAttendanceYear
              : AppStrings.addAttendanceYear,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: AppStrings.yearName,
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? AppStrings.yearNameRequired
                              : null,
                    ),
                    const SizedBox(height: 14),
                    _dateField(
                      label: AppStrings.startDate,
                      value: _start,
                      onTap: () => _pickDate(isStart: true),
                    ),
                    const SizedBox(height: 14),
                    _dateField(
                      label: AppStrings.endDate,
                      value: _end,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: AppStrings.pointsPerActivity,
                icon: Icons.star_rounded,
                accent: AppColors.gold,
                child: Column(
                  children: [
                    _pointsField(AppStrings.sundaySchool, _sundaySchool),
                    const SizedBox(height: 12),
                    _pointsField(AppStrings.vespers, _vespers),
                    const SizedBox(height: 12),
                    _pointsField(AppStrings.mass, _mass),
                    const SizedBox(height: 12),
                    _pointsField(AppStrings.confession, _confession),
                  ],
                ),
              ),
              if (!isEditing) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _makeCurrent,
                  title: const Text(AppStrings.setAsCurrent),
                  onChanged: (value) => setState(() => _makeCurrent = value),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text(AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
        ),
        child: Text(
          AppDateUtils.formatDayDate(value),
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _pointsField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.star_outline),
        suffixText: AppStrings.points,
      ),
      validator: (value) {
        final points = int.tryParse(value?.trim() ?? '');
        return (points == null || points <= 0) ? AppStrings.noData : null;
      },
    );
  }
}
