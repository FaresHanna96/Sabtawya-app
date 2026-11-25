import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_date_utils.dart';

/// The day on a tinted square: its number over the month's name. One look for
/// every list that shows a date (competitions, activities). Tint it by kind:
/// gold for a birthday, olive for an activity, sky for a trip.
class DateCube extends StatelessWidget {
  const DateCube({super.key, required this.date, required this.color});

  final DateTime date;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.readable(color),
            ),
          ),
          Text(
            AppDateUtils.monthName(date.month),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: AppColors.readable(color)),
          ),
        ],
      ),
    );
  }
}
