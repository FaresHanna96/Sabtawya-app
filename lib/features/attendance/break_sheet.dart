import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/repositories/lesson_repository.dart';

/// What the admin chose for a Saturday: [kind] null is a normal lesson day.
class BreakChoice {
  const BreakChoice({required this.kind, required this.shift});

  final LessonBreakKind? kind;
  final bool shift;
}

/// "هل يوجد درس هذا السبت؟": إجازة, نشاط ترفيهي, or a normal day, and
/// whether the later lessons move a week. Null when closed without saving.
Future<BreakChoice?> showBreakSheet(
  BuildContext context, {
  required DateTime date,
  LessonBreak? current,
  bool hasRecords = false,
}) =>
    showModalBottomSheet<BreakChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BreakSheet(
        date: date,
        current: current,
        hasRecords: hasRecords,
      ),
    );

@visibleForTesting
class BreakSheet extends StatefulWidget {
  const BreakSheet({
    super.key,
    required this.date,
    this.current,
    this.hasRecords = false,
  });

  final DateTime date;
  final LessonBreak? current;

  /// Attendance was already taken that day (it will stop counting).
  final bool hasRecords;

  @override
  State<BreakSheet> createState() => _BreakSheetState();
}

class _BreakSheetState extends State<BreakSheet> {
  late LessonBreakKind? _kind =
      widget.current?.kind ?? LessonBreakKind.activity;
  late bool _shift = widget.current?.shift ?? true;

  @override
  Widget build(BuildContext context) {
    Widget option(LessonBreakKind? kind, IconData icon, String label) {
      final selected = _kind == kind;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected
              ? AppColors.navy.withValues(alpha: 0.08)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected
                  ? AppColors.navy.withValues(alpha: 0.4)
                  : AppColors.muted.withValues(alpha: 0.25),
            ),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: Icon(icon, color: AppColors.navy),
            title: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: selected
                ? const Icon(Icons.check_circle, color: AppColors.success)
                : null,
            onTap: () => setState(() => _kind = kind),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.breakSheetTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              AppDateUtils.formatDayDate(widget.date),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            option(LessonBreakKind.activity, Icons.celebration_rounded,
                AppStrings.breakActivity),
            option(LessonBreakKind.holiday, Icons.beach_access_rounded,
                AppStrings.breakHoliday),
            if (widget.current != null)
              option(null, Icons.menu_book_rounded, AppStrings.breakNone),
            if (_kind != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _shift,
                onChanged: (v) => setState(() => _shift = v),
                title: const Text(AppStrings.breakShift),
                subtitle: const Text(
                  AppStrings.breakShiftHint,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (widget.hasRecords)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    AppStrings.breakHasRecords,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 4),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pop(BreakChoice(kind: _kind, shift: _shift)),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
