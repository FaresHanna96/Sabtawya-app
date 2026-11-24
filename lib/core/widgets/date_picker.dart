import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// The app's date picker: tap a day and it is chosen, with no OK / Cancel to
/// press afterwards (outside the dialog or the X closes it without a pick).
///
/// The same named parameters as [showDatePicker], so it is a drop-in.
Future<DateTime?> pickDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _PickDateDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      title: helpText ?? AppStrings.pickDateTitle,
      mode: initialDatePickerMode,
    ),
  );
}

class _PickDateDialog extends StatefulWidget {
  const _PickDateDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    required this.mode,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final DatePickerMode mode;

  @override
  State<_PickDateDialog> createState() => _PickDateDialogState();
}

class _PickDateDialogState extends State<_PickDateDialog> {
  /// Picking a year in the calendar also reports a date, but that is a step
  /// on the way to a day, not the answer: ignore it.
  bool _monthJustChanged = false;
  late bool _awaitingYear = widget.mode == DatePickerMode.year;

  void _onDate(DateTime day) {
    if (_monthJustChanged || _awaitingYear) {
      _awaitingYear = false;
      return;
    }
    Navigator.of(context).pop(DateUtils.dateOnly(day));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded,
                      color: Colors.white70, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: CalendarDatePicker(
                  initialDate: widget.initialDate,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  initialCalendarMode: widget.mode,
                  onDisplayedMonthChanged: (_) {
                    _monthJustChanged = true;
                    Future.microtask(() => _monthJustChanged = false);
                  },
                  onDateChanged: _onDate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
