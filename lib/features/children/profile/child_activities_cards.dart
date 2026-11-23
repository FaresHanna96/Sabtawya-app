import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/utils/message_template.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/competition.dart';
import '../../../data/models/event.dart';

/// Where a child stands in one trip or activity.
enum TripState { paid, partly, reserved, open }

/// One trip on ملف المخدوم: the event and the child's line in it.
class ChildTrip {
  const ChildTrip(this.event, this.balance);

  final Event event;
  final ChildEventBalance balance;

  TripState get state {
    if (balance.isPaid) {
      return balance.remaining <= 0 ? TripState.paid : TripState.partly;
    }
    return balance.reserved ? TripState.reserved : TripState.open;
  }

  /// The trips worth showing for this year: every one the child booked, and
  /// the ones still to come they could book. Past trips they skipped are
  /// left out. Coming ones first (nearest first), then the past (newest
  /// first).
  static List<ChildTrip> of({
    required List<Event> events,
    required List<ChildEventBalance> balances,
    required DateTime today,
    AttendanceYear? year,
  }) {
    final byEvent = {for (final b in balances) b.eventId: b};
    final day = DateTime(today.year, today.month, today.day);
    bool inYear(Event e) {
      if (year == null) return true;
      if (e.yearId != null) return e.yearId == year.id;
      return !e.eventDate.isBefore(year.startDate) &&
          !e.eventDate.isAfter(year.endDate);
    }

    final coming = <ChildTrip>[];
    final past = <ChildTrip>[];
    for (final e in events) {
      final b = byEvent[e.id];
      if (b == null || !inYear(e)) continue;
      final isComing = !e.eventDate.isBefore(day);
      if (!b.isBooked && !isComing) continue;
      (isComing ? coming : past).add(ChildTrip(e, b));
    }
    coming.sort((a, b) => a.event.eventDate.compareTo(b.event.eventDate));
    past.sort((a, b) => b.event.eventDate.compareTo(a.event.eventDate));
    return [...coming, ...past];
  }

  /// What is still owed over the booked trips.
  static double owed(List<ChildTrip> trips) => trips
      .where((t) => t.balance.isBooked && t.balance.remaining > 0)
      .fold(0, (sum, t) => sum + t.balance.remaining);
}

/// «نشاطات ترفيهية» on نظرة عامة: each trip with paid / owed / booked.
class ChildTripsCard extends StatelessWidget {
  const ChildTripsCard({super.key, required this.trips, this.onOpen});

  final List<ChildTrip> trips;

  /// Opens the trip's own screen (payments, bookings).
  final ValueChanged<Event>? onOpen;

  /// How many trips the card lists before «عرض الكل».
  static const shown = 3;

  @override
  Widget build(BuildContext context) {
    final owed = ChildTrip.owed(trips);
    return SectionCard(
      title: AppStrings.events,
      icon: Icons.directions_bus_rounded,
      accent: AppColors.olive,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (owed > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                AppStrings.tripsOwed(ParentMessages.money(owed)),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.readable(AppColors.coral),
                ),
              ),
            ),
          for (final t in trips.take(shown)) _TripLine(trip: t, onOpen: onOpen),
          if (trips.length > shown)
            _MoreLine(
              label: AppStrings.moreTrips(trips.length - shown),
              onTap: () => _showAll(context),
            ),
        ],
      ),
    );
  }

  void _showAll(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (final t in trips)
                  _TripLine(
                    trip: t,
                    onOpen: onOpen == null
                        ? null
                        : (e) {
                            Navigator.of(sheet).pop();
                            onOpen!(e);
                          },
                  ),
              ],
            ),
          ),
        ),
      );
}

class _TripLine extends StatelessWidget {
  const _TripLine({required this.trip, this.onOpen});

  final ChildTrip trip;
  final ValueChanged<Event>? onOpen;

  @override
  Widget build(BuildContext context) {
    final b = trip.balance;
    final (label, color) = switch (trip.state) {
      TripState.paid => (AppStrings.paidInFull, AppColors.success),
      TripState.partly => (
          AppStrings.tripPaidOf(
            ParentMessages.money(b.totalPaid),
            ParentMessages.money(b.cost),
          ),
          AppColors.gold,
        ),
      TripState.reserved => (AppStrings.reservedUnpaidStatus, AppColors.coral),
      TripState.open => (AppStrings.tripNotBooked, AppColors.muted),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onOpen == null ? null : () => onOpen!(trip.event),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    AppDateUtils.formatDate(trip.event.eventDate),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _Pill(label: label, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// «المسابقات» on نظرة عامة: the year's total and the last few weeks.
class ChildCompetitionsCard extends StatelessWidget {
  const ChildCompetitionsCard({super.key, required this.marks, this.onOpen});

  /// Each competition with the child's mark, newest week first.
  final List<(Competition, int)> marks;
  final ValueChanged<Competition>? onOpen;

  static const shown = 3;

  /// This year's marks only (a competition without a year counts by date).
  static List<(Competition, int)> forYear(
    List<(Competition, int)> marks,
    AttendanceYear? year,
  ) {
    if (year == null) return marks;
    return [
      for (final m in marks)
        if (m.$1.yearId != null
            ? m.$1.yearId == year.id
            : !m.$1.weekDate.isBefore(year.startDate) &&
                !m.$1.weekDate.isAfter(year.endDate))
          m,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final total = marks.fold<int>(0, (s, m) => s + m.$2);
    final max = marks.fold<int>(0, (s, m) => s + m.$1.maxMark);
    final share = max == 0 ? 0.0 : (total / max).clamp(0, 1).toDouble();
    return SectionCard(
      title: AppStrings.competitions,
      icon: Icons.emoji_events_outlined,
      accent: AppColors.gold,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(
                AppStrings.marksOf(total, max),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  AppStrings.inCompetitions(marks.length),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 6,
              backgroundColor: AppColors.navy.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 6),
          for (final (c, mark) in marks.take(shown))
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onOpen == null ? null : () => onOpen!(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${c.title} • ${AppDateUtils.formatDate(c.weekDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.marksOf(mark, c.maxMark),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoreLine extends StatelessWidget {
  const _MoreLine({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(onPressed: onTap, child: Text(label)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.readable(color),
        ),
      ),
    );
  }
}
