import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

/// One number in the card's bottom row, with a small line under its label
/// («40 أولاد · 40 بنات»).
class HomeTotal {
  const HomeTotal({
    this.value,
    this.text,
    required this.label,
    this.sub,
    this.icon,
  }) : assert(value != null || text != null);

  /// The number, or [text] when the cell says a word (a class name).
  final int? value;
  final String? text;
  final String label;
  final String? sub;

  /// Drawn on a small tinted disc beside the number; none draws just the text.
  final IconData? icon;
}

/// The top of a home page in one card: who is looking, a gold «سجّل الحضور»
/// button while a class still has to record, and the totals as one row of up
/// to three small tiles. How the last Saturday went is not here: the weekly
/// chart below says it, once.
class HomeStatusCard extends StatelessWidget {
  const HomeStatusCard({
    super.key,
    required this.name,
    this.yearName,
    this.totals = const [],
    this.onRecord,
  });

  final String name;
  final String? yearName;
  final List<HomeTotal> totals;

  /// Set while a class still has to record: shows «سجّل الحضور».
  final VoidCallback? onRecord;

  static const _soft = Color(0xFFDCE4F2);

  static (String, String) _greetingFor(int hour) {
    if (hour < 12) return ('صباح الخير', '☀️');
    if (hour < 18) return ('مساء النور', '🌤️');
    return ('مساء الخير', '🌙');
  }

  @override
  Widget build(BuildContext context) {
    final (greeting, emoji) = _greetingFor(DateTime.now().hour);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: AppGradients.navyHeader,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _who(greeting, emoji),
          if (onRecord != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.edit_calendar_rounded, size: 18),
              label: const Text(AppStrings.homeRecordNow),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.navyDark,
                minimumSize: const Size.fromHeight(40),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ],
          if (totals.isNotEmpty) ...[
            const SizedBox(height: 10),
            _totalsRow(),
          ],
        ],
      ),
    );
  }

  /// Logo, the greeting over the name (both big enough to read at a glance:
  /// the name is the first thing the card says), then the year as a pill.
  Widget _who(String greeting, String emoji) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: const AppLogo(size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting $emoji',
                  style: const TextStyle(
                    color: _soft,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (yearName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                yearName!,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: _soft,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      );

  Widget _totalsRow() {
    final cells = totals.take(3).toList();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(child: _cell(cells[i])),
          ],
        ],
      ),
    );
  }

  /// One total as a small soft tile: a tiny icon disc and the number on one
  /// line, the label under it, and the small line («40 أولاد • 40 بنات»).
  Widget _cell(HomeTotal t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.icon != null) ...[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(t.icon, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    t.text ?? '${t.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (t.sub != null)
              Text(
                t.sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _soft,
                  fontSize: 10.5,
                  height: 1.25,
                ),
              ),
          ],
        ),
      );
}
