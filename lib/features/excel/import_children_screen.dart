import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/celebration.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/school_class.dart';
import '../../data/services/child_import_service.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';

/// Imports a class roster from an `.xlsx` file.
///
/// Nothing is written until the preview is confirmed: the file is parsed, every
/// row is matched against the database, and the verdict per row is shown first.
class ImportChildrenScreen extends StatefulWidget {
  const ImportChildrenScreen({super.key, this.initialClassId});

  final String? initialClassId;

  @override
  State<ImportChildrenScreen> createState() => _ImportChildrenScreenState();
}

class _ImportChildrenScreenState extends State<ImportChildrenScreen> {
  static const _service = ChildImportService();

  String? _classId;
  ImportMode _mode = ImportMode.addAndUpdate;
  PickedWorkbook? _file;
  List<ImportRow>? _rows;
  ImportPlan? _plan;
  String? _parseError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
  }

  List<ClassOverview> get _classes =>
      context.read<SessionController>().myClasses;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // With a single class there is nothing to choose.
    if (_classId == null && _classes.length == 1) {
      _classId = _classes.first.classId;
    }
  }

  Future<void> _downloadTemplate() async {
    await Ui.runGuarded(
      context,
      () async {
        await FileService.saveAndShare(
          fileName: FileService.timestampedName(AppStrings.childrenTitle),
          bytes: ExcelService.childrenTemplate(),
          shareText: AppStrings.downloadTemplate,
        );
      },
      successMessage: AppStrings.templateSaved,
    );
  }

  Future<void> _pickFile() async {
    if (!Ui.requireOnline(context)) return;
    if (_classId == null) {
      Ui.info(context, AppStrings.selectClass);
      return;
    }

    setState(() => _busy = true);
    try {
      final picked = await FileService.pickWorkbook();
      if (picked == null) {
        setState(() => _busy = false);
        return;
      }

      final result = ExcelService.parseChildren(picked.bytes);
      if (!mounted) return;
      setState(() {
        _file = picked;
        _rows = result.isFailure ? null : result.rows;
        _plan = null;
        _parseError = result.error;
      });
      await _resolve();
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Re-decides every row. Called after picking a file and whenever the class
  /// or the mode changes, so the preview always matches the current choices.
  Future<void> _resolve() async {
    final rows = _rows;
    final classId = _classId;
    if (rows == null || classId == null) return;

    setState(() => _busy = true);
    try {
      final plan = await _service.resolve(
        rows: rows,
        classId: classId,
        mode: _mode,
      );
      if (mounted) setState(() => _plan = plan);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final plan = _plan;
    if (plan == null || !plan.hasWork) return;

    final parts = <String>[
      if (plan.insertCount > 0)
        '${AppStrings.importInserted} ${plan.insertCount}',
      if (plan.updateCount > 0) '${AppStrings.importUpdated} ${plan.updateCount}',
      if (plan.movesCount > 0)
        '${AppStrings.moveChild}: ${plan.movesCount}',
    ];

    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.importConfirm,
      message: parts.join('\n'),
      confirmLabel: AppStrings.importConfirm,
    );
    if (!confirmed || !mounted) return;

    ImportResult? result;
    final ok = await Ui.runGuarded(context, () async {
      result = await _service.apply(plan);
    });
    if (!ok || !mounted) return;

    await context.read<SessionController>().refreshClasses();
    if (!mounted) return;

    final applied = result!;
    Celebration.show(context);
    Ui.success(
      context,
      '${AppStrings.importDone}: '
      '${AppStrings.importInserted} ${applied.inserted}، '
      '${AppStrings.importUpdated} ${applied.updated}',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final rows = plan?.rows ?? const <ImportRow>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.importTitle),
        actions: [
          IconButton(
            tooltip: AppStrings.downloadTemplate,
            onPressed: _busy ? null : _downloadTemplate,
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              // Setup card, then the summary, then one card per row.
              itemCount: 2 + rows.length,
              itemBuilder: (context, index) {
                if (index == 0) return _setupCard();
                if (index == 1) {
                  return plan == null
                      ? _hintCard()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: _summaryCard(plan),
                        );
                }
                return _RowCard(row: rows[index - 2]);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: plan == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: (_busy || !plan.hasWork) ? null : _apply,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    plan.hasWork
                        ? '${AppStrings.importConfirm} '
                            '(${plan.insertCount + plan.updateCount})'
                        : AppStrings.importNoValidRows,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _setupCard() {
    return SectionCard(
      title: AppStrings.importMode,
      icon: Icons.tune_rounded,
      accent: AppColors.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _classId,
            decoration: const InputDecoration(labelText: AppStrings.classLabel),
            items: _classes
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.classId,
                    child: Text(item.className),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) {
                    setState(() => _classId = value);
                    _resolve();
                  },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ImportMode.values
                .map(
                  (mode) => ChoiceChip(
                    label: Text(mode.label),
                    selected: _mode == mode,
                    onSelected: _busy
                        ? null
                        : (_) {
                            if (_mode == mode) return;
                            setState(() => _mode = mode);
                            _resolve();
                          },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: Text(_file?.name ?? AppStrings.pickFile),
          ),
          if (_file == null) ...[
            const SizedBox(height: 8),
            const Text(
              AppStrings.pickFileHint,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          if (_parseError != null) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.error_outline,
              color: AppColors.danger,
              message: _parseError!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _hintCard() {
    return const Padding(
      padding: EdgeInsets.only(top: 24),
      child: EmptyState(
        icon: Icons.table_chart_outlined,
        title: AppStrings.importPreview,
        body: AppStrings.pickFileHint,
      ),
    );
  }

  Widget _summaryCard(ImportPlan plan) {
    return SectionCard(
      title: AppStrings.importPreview,
      icon: Icons.table_chart_rounded,
      accent: AppColors.navyLight,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Tally(
            label: AppStrings.importRowsNew,
            value: plan.insertCount,
            color: AppColors.success,
          ),
          _Tally(
            label: AppStrings.importRowsExisting,
            value: plan.updateCount,
            color: AppColors.navy,
          ),
          _Tally(
            label: AppStrings.importRowsSkipped,
            value: plan.skipCount,
            color: AppColors.muted,
          ),
          _Tally(
            label: AppStrings.importRowsInvalid,
            value: plan.errorCount,
            color: AppColors.danger,
          ),
          if (plan.movesCount > 0)
            _Tally(
              label: AppStrings.moveChild,
              value: plan.movesCount,
              color: AppColors.warning,
            ),
        ],
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

/// One preview row. Errors are tinted red so a bad cell is obvious before
/// anything reaches the database.
class _RowCard extends StatelessWidget {
  const _RowCard({required this.row});

  final ImportRow row;

  Color get _accent {
    if (row.hasErrors) return AppColors.danger;
    return switch (row.action) {
      ImportAction.insert => AppColors.success,
      ImportAction.update => AppColors.navy,
      ImportAction.skip => AppColors.muted,
    };
  }

  String get _actionLabel {
    if (row.hasErrors) return AppStrings.importRowsInvalid;
    return switch (row.action) {
      ImportAction.insert => AppStrings.importRowsNew,
      ImportAction.update => AppStrings.importRowsExisting,
      ImportAction.skip => AppStrings.importRowsSkipped,
    };
  }

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (row.gender != null) row.gender!.label,
      if (row.birthDate != null) AppDateUtils.toIsoDate(row.birthDate!),
      if (row.code != null) row.code!,
      if (row.mobile != null) row.mobile!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: row.hasErrors ? AppColors.danger.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${row.rowNumber}',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name.isEmpty ? AppStrings.unknown : row.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      details.join(' • '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  for (final error in row.errors) ...[
                    const SizedBox(height: 4),
                    _Banner(
                      icon: Icons.error_outline,
                      color: AppColors.danger,
                      message: error,
                      compact: true,
                    ),
                  ],
                  if (row.note != null) ...[
                    const SizedBox(height: 4),
                    _Banner(
                      icon: Icons.info_outline,
                      color: AppColors.muted,
                      message: row.note!,
                      compact: true,
                    ),
                  ],
                  if (row.movesClass && !row.hasErrors) ...[
                    const SizedBox(height: 4),
                    _Banner(
                      icon: Icons.swap_horiz,
                      color: AppColors.warning,
                      message: AppStrings.importWillMoveClass,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _actionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final Color color;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: compact ? 14 : 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: color,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
