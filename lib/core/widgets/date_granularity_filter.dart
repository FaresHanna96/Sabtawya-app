import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_utils.dart';

// Kept for callers that reference it; the widget no longer exposes it in the UI.
enum DateGranularity { day, month, year }

/// A simple from / to date-range filter using Flutter's native date picker.
///
/// [availableDates] constrains the selectable range.
/// [onChanged] fires with `(DateGranularity.day, from, to)` when a date is
///   picked, or `(null, null, null)` when cleared.
/// [matchesFilter] is a static helper callers use to test a date against the
///   active range; it always compares at day granularity.
class DateGranularityFilter extends StatefulWidget {
  const DateGranularityFilter({
    super.key,
    required this.availableDates,
    required this.onChanged,
    // modes / initialGranularity kept for API compatibility; not used by UI.
    this.modes,
    this.initialGranularity,
    this.firstDate,
    this.lastDate,
  });

  final List<DateTime> availableDates;

  /// Bounds of the calendar. When given (the attendance year's start and end)
  /// they win over the dates found in the data, so the calendar always spans
  /// the whole year.
  final DateTime? firstDate;
  final DateTime? lastDate;
  final List<DateGranularity>? modes;
  final DateGranularity? initialGranularity;

  final void Function(
    DateGranularity? granularity,
    DateTime? from,
    DateTime? to,
  ) onChanged;

  /// Returns true when [date] falls within [from]..[to] (day precision).
  /// Returns true when both bounds are null (no filter active).
  static bool matchesFilter({
    required DateTime date,
    required DateGranularity? granularity,
    required DateTime? from,
    required DateTime? to,
  }) {
    if (from == null && to == null) return true;
    final d = DateTime(date.year, date.month, date.day);
    if (from != null) {
      if (d.isBefore(DateTime(from.year, from.month, from.day))) return false;
    }
    if (to != null) {
      if (d.isAfter(DateTime(to.year, to.month, to.day))) return false;
    }
    return true;
  }

  @override
  State<DateGranularityFilter> createState() => DateGranularityFilterState();
}

class DateGranularityFilterState extends State<DateGranularityFilter> {
  DateTime? _from;
  DateTime? _to;

  DateTime? get from => _from;
  DateTime? get to => _to;
  DateGranularity? get granularity =>
      (_from != null || _to != null) ? DateGranularity.day : null;

  void _clear() {
    setState(() {
      _from = null;
      _to = null;
    });
    widget.onChanged(null, null, null);
  }

  void _setFrom(DateTime v) {
    setState(() {
      _from = v;
      if (_to != null && _to!.isBefore(v)) _to = v;
    });
    widget.onChanged(DateGranularity.day, _from, _to);
  }

  void _setTo(DateTime v) {
    setState(() => _to = v);
    widget.onChanged(DateGranularity.day, _from, _to);
  }

  DateTime get _firstDate {
    if (widget.firstDate != null) return widget.firstDate!;
    if (widget.availableDates.isEmpty) return DateTime(2020);
    return widget.availableDates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime get _lastDate {
    if (widget.lastDate != null) return widget.lastDate!;
    if (widget.availableDates.isEmpty) return DateTime.now();
    return widget.availableDates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// [value] limited to [low]..[high], so the picker never opens outside its
  /// own range.
  DateTime _clamp(DateTime value, DateTime low, DateTime high) {
    if (value.isBefore(low)) return low;
    if (value.isAfter(high)) return high;
    return value;
  }

  Future<void> _pickFrom() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _from ?? _firstDate,
      firstDate: _firstDate,
      lastDate: _lastDate,
    );
    if (day != null) _setFrom(day);
  }

  Future<void> _pickTo() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _to ?? _clamp(DateTime.now(), _from ?? _firstDate, _lastDate),
      firstDate: _from ?? _firstDate,
      lastDate: _lastDate,
    );
    if (day != null) _setTo(day);
  }

  @override
  Widget build(BuildContext context) {
    final isFiltered = _from != null || _to != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Text(
            AppStrings.periodFilter,
            style: TextStyle(
              fontSize: 12,
              color: isFiltered ? AppColors.navy : AppColors.muted,
              fontWeight: isFiltered ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DateRangeBar(
              from: _from,
              to: _to,
              onTapFrom: _pickFrom,
              onTapTo: _pickTo,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: isFiltered
                ? GestureDetector(
                    onTap: _clear,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- range bar

class _DateRangeBar extends StatelessWidget {
  const _DateRangeBar({
    required this.from,
    required this.to,
    required this.onTapFrom,
    required this.onTapTo,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onTapFrom;
  final VoidCallback onTapTo;

  @override
  Widget build(BuildContext context) {
    final isActive = from != null || to != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.navy.withValues(alpha: 0.7)
              : AppColors.muted.withValues(alpha: 0.2),
          width: isActive ? 1.5 : 1,
        ),
        color: isActive
            ? AppColors.navy.withValues(alpha: 0.03)
            : Colors.transparent,
      ),
      child: Row(
        children: [
          Expanded(
            child: _RangePart(
              label: AppStrings.periodFrom,
              value: from,
              onTap: onTapFrom,
              isLeading: true,
            ),
          ),
          _Separator(hasValue: from != null && to != null),
          Expanded(
            child: _RangePart(
              label: AppStrings.periodTo,
              value: to,
              onTap: onTapTo,
              isLeading: false,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- half picker

class _RangePart extends StatelessWidget {
  const _RangePart({
    required this.label,
    required this.value,
    required this.onTap,
    required this.isLeading,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool isLeading;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: isLeading ? 10 : 6,
          end: isLeading ? 6 : 10,
          top: 7,
          bottom: 7,
        ),
        child: Row(
          children: [
            Icon(
              hasValue
                  ? Icons.calendar_month_rounded
                  : Icons.calendar_today_outlined,
              size: 14,
              color: hasValue ? AppColors.navy : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      height: 1,
                      color: hasValue
                          ? AppColors.navy.withValues(alpha: 0.6)
                          : AppColors.muted.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? AppDateUtils.formatDate(value!) : 'اختر تاريخ',
                    style: TextStyle(
                      fontSize: hasValue ? 11 : 12,
                      height: 1,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
                      color: hasValue
                          ? AppColors.navy
                          : AppColors.muted.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- divider

class _Separator extends StatelessWidget {
  const _Separator({required this.hasValue});

  final bool hasValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 1,
            height: 24,
            color: AppColors.muted.withValues(alpha: 0.15),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_back_ios_rounded,
            size: 10,
            color: hasValue
                ? AppColors.navy.withValues(alpha: 0.4)
                : AppColors.muted.withValues(alpha: 0.25),
          ),
        ],
      ),
    );
  }
}
