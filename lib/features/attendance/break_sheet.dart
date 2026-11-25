import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/repositories/lesson_repository.dart';

/// What the admin chose for a Saturday: [kind] null is a normal lesson day.
class BreakChoice {
  const BreakChoice({
    required this.kind,
    required this.shift,
    this.attendanceTaken = false,
  });

  final LessonBreakKind? kind;
  final bool shift;

  /// A نشاط ترفيهي whose children's attendance is taken and counted.
  final bool attendanceTaken;
}

/// "فيه درس السبت ده؟": a normal day, إجازة or نشاط ترفيهي, and what happens
/// to the lesson (postponed a week, or cancelled). The one place both the
/// attendance screen and the lessons tab use. Null when closed without saving.
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
  late bool _taken = widget.current?.attendanceTaken ?? false;

  /// A tinted, rounded choice: [selected] shows the check and the border.
  Widget _choice({
    required IconData icon,
    required Color color,
    required String title,
    required String hint,
    required bool selected,
    required VoidCallback onTap,
    Key? key,
  }) =>
      Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? color.withValues(alpha: 0.7)
                  : AppColors.muted.withValues(alpha: 0.25),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: AppColors.readable(color)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: AppColors.success),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              AppStrings.breakSheetTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              AppDateUtils.formatDayDate(widget.date),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (widget.current != null)
              _choice(
                icon: Icons.menu_book_rounded,
                color: AppColors.olive,
                title: AppStrings.breakNone,
                hint: AppStrings.breakNoneHint,
                selected: _kind == null,
                onTap: () => setState(() => _kind = null),
              ),
            _choice(
              icon: Icons.celebration_rounded,
              color: AppColors.gold,
              title: AppStrings.breakActivity,
              hint: AppStrings.breakActivityHint,
              selected: _kind == LessonBreakKind.activity,
              onTap: () => setState(() => _kind = LessonBreakKind.activity),
            ),
            _choice(
              icon: Icons.beach_access_rounded,
              color: AppColors.sky,
              title: AppStrings.breakHoliday,
              hint: AppStrings.breakHolidayHint,
              selected: _kind == LessonBreakKind.holiday,
              onTap: () => setState(() => _kind = LessonBreakKind.holiday),
            ),
            // A holiday is simply no lesson that day: nothing to ask. Only an
            // activity asks what becomes of the lesson (and about attendance).
            if (_kind == LessonBreakKind.activity) ...[
              const SizedBox(height: 6),
              const Text(
                AppStrings.breakWhatNext,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              _choice(
                key: const ValueKey('breakPostpone'),
                icon: Icons.east_rounded,
                color: AppColors.navy,
                title: AppStrings.breakPostponeTitle,
                hint: AppStrings.breakPostponeHint,
                selected: _shift,
                onTap: () => setState(() => _shift = true),
              ),
              _choice(
                key: const ValueKey('breakCancel'),
                icon: Icons.block_rounded,
                color: AppColors.coral,
                title: AppStrings.breakCancelTitle,
                hint: AppStrings.breakCancelHint,
                selected: !_shift,
                onTap: () => setState(() => _shift = false),
              ),
              if (_kind == LessonBreakKind.activity) ...[
                const SizedBox(height: 6),
                const Text(
                  AppStrings.breakAttendanceQuestion,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _choice(
                  key: const ValueKey('breakAttendanceTaken'),
                  icon: Icons.how_to_reg_rounded,
                  color: AppColors.success,
                  title: AppStrings.breakAttendanceTakenTitle,
                  hint: AppStrings.breakAttendanceTakenHint,
                  selected: _taken,
                  onTap: () => setState(() => _taken = true),
                ),
                _choice(
                  key: const ValueKey('breakAttendanceNotTaken'),
                  icon: Icons.person_off_rounded,
                  color: AppColors.muted,
                  title: AppStrings.breakAttendanceNotTakenTitle,
                  hint: AppStrings.breakAttendanceNotTakenHint,
                  selected: !_taken,
                  onTap: () => setState(() => _taken = false),
                ),
              ],
            ],
            if (_kind != null &&
                widget.hasRecords &&
                !(_kind == LessonBreakKind.activity && _taken))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AppStrings.breakHasRecords,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pop(BreakChoice(
                kind: _kind,
                // A holiday asks nothing: its lesson is just not given.
                shift: _kind == LessonBreakKind.holiday ? false : _shift,
                attendanceTaken: _kind == LessonBreakKind.activity && _taken,
              )),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
