import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/arabic_sort.dart';
import '../../core/utils/calendar_grid.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/child.dart';
import '../../data/models/event.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_profile_screen.dart';
import '../events/event_detail_screen.dart';

enum _Kind { child, servant, event }

/// One thing on a day: a birthday or an event.
class _Item {
  const _Item({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final _Kind kind;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _CalendarData {
  const _CalendarData({
    required this.children,
    required this.servants,
    required this.events,
  });

  final List<Child> children;
  final List<Profile> servants;
  final List<Event> events;
}

/// A month calendar of birthdays (المخدومين and الخدام) and events (الفعاليات).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _children = ChildRepository();
  static const _servants = ServantRepository();
  static const _events = EventRepository();

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = CalendarGrid.dayOf(DateTime.now());
  final _shown = <_Kind>{..._Kind.values};

  Future<_CalendarData> _load() async => _CalendarData(
        children: await _children.all(includeInactive: false),
        servants: await _servants.birthdays(),
        events: await _events.listEvents(),
      );

  /// +1 / -1: which way the month grid slides in (RTL: next comes from left).
  double _slideDir = -1;

  void _go(int months) => setState(() {
        HapticFeedback.selectionClick();
        _slideDir = months > 0 ? -1 : 1;
        _month = DateTime(_month.year, _month.month + months);
        // Keep the selection in the visible month.
        _selected = DateTime(_month.year, _month.month, 1);
      });

  void _today() => setState(() {
        final now = DateTime.now();
        _month = DateTime(now.year, now.month);
        _selected = CalendarGrid.dayOf(now);
      });

  /// Everything that happens on [day], for the kinds currently shown.
  List<_Item> _itemsOn(
    DateTime day,
    _CalendarData data,
    Map<String, String> classNames,
  ) {
    final items = <_Item>[];

    if (_shown.contains(_Kind.child)) {
      final born = data.children.where((c) =>
          c.birthDate != null &&
          CalendarGrid.sameDay(
              CalendarGrid.birthdayIn(c.birthDate!, day.year), day));
      for (final c in born) {
        items.add(_Item(
          kind: _Kind.child,
          title: c.fullName,
          subtitle: [
            if (classNames[c.classId] != null) classNames[c.classId]!,
            '${AppStrings.turningAge} ${day.year - c.birthDate!.year} '
                '${AppStrings.years}',
          ].join(' • '),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => ChildProfileScreen(childId: c.id),
            ),
          ),
        ));
      }
    }

    if (_shown.contains(_Kind.servant)) {
      final born = data.servants.where((p) =>
          p.birthDate != null &&
          CalendarGrid.sameDay(
              CalendarGrid.birthdayIn(p.birthDate!, day.year), day));
      for (final p in born) {
        items.add(_Item(
          kind: _Kind.servant,
          title: p.fullName,
          subtitle: [
            p.roleLabel,
            '${AppStrings.turningAge} ${day.year - p.birthDate!.year} '
                '${AppStrings.years}',
          ].join(' • '),
        ));
      }
    }

    // A day's birthdays read A to Z; events follow them.
    items.sort((a, b) => ArabicSort.compare(a.title, b.title));

    if (_shown.contains(_Kind.event)) {
      for (final e in data.events) {
        if (CalendarGrid.sameDay(e.eventDate, day)) {
          items.add(_Item(
            kind: _Kind.event,
            title: e.title,
            subtitle: '${e.cost.toStringAsFixed(0)} ج.م',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => EventDetailScreen(event: e),
              ),
            ),
          ));
        }
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final classNames = {
      for (final c in context.watch<SessionController>().myClasses)
        c.classId: c.className,
    };

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.calendarTitle)),
      body: SafeArea(
        child: AsyncSection<_CalendarData>(
          load: _load,
          builder: (context, data, _) {
            final selectedItems = _itemsOn(_selected, data, classNames);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _filters(),
                const SizedBox(height: 12),
                SectionCard(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  // Swipe the grid to change month (RTL: right = next).
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      if (v > 250) _go(1);
                      if (v < -250) _go(-1);
                    },
                    child: Column(
                    children: [
                      _monthHeader(),
                      _monthSummary(data),
                      const SizedBox(height: 6),
                      _weekdayRow(),
                      // The month's days slide in from the side it came
                      // from when the arrows change the month.
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: Offset(0.15 * _slideDir, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey(_month),
                          children: [
                            for (final week in CalendarGrid.weeks(
                              _month.year,
                              _month.month,
                            ))
                              Row(
                                children: [
                                  for (final day in week)
                                    Expanded(
                                      child: day == null
                                          ? const SizedBox(height: 46)
                                          : _dayCell(
                                              day,
                                              _itemsOn(day, data, classNames),
                                            ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _legend(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Align(
                            key: ValueKey(_selected),
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              AppDateUtils.formatDayDate(_selected),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedScale(
                        scale: selectedItems.isEmpty ? 0 : 1,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${selectedItems.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: selectedItems.isEmpty
                      ? Padding(
                          key: ValueKey('empty-$_selected'),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: const Center(
                            child: Column(
                              children: [
                                Float(
                                  distance: 5,
                                  child: Icon(
                                    Icons.event_available_outlined,
                                    size: 40,
                                    color: AppColors.muted,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  AppStrings.calendarNothing,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          key: ValueKey(_selected),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, item) in selectedItems.indexed)
                              staggered(i, _tile(item)),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filters() {
    Widget chip(_Kind kind, String label, Color color) => FilterChip(
          label: Text(label),
          avatar: CircleAvatar(radius: 5, backgroundColor: color),
          showCheckmark: false,
          selected: _shown.contains(kind),
          onSelected: (on) => setState(() {
            on ? _shown.add(kind) : _shown.remove(kind);
          }),
        );

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        chip(_Kind.child, AppStrings.childBirthdaysShort, AppColors.coral),
        chip(_Kind.servant, AppStrings.servantBirthdaysShort, AppColors.sky),
        chip(_Kind.event, AppStrings.events, AppColors.gold),
      ],
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        IconButton(
          tooltip: AppStrings.previousMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _go(-1),
        ),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(0.25 * _slideDir, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                '${AppDateUtils.monthName(_month.month)} ${_month.year}',
                key: ValueKey(_month),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        // "Today" only shows when you are away from today.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _onToday()
              ? const SizedBox.shrink()
              : TextButton.icon(
                  onPressed: _today,
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text(AppStrings.today),
                ),
        ),
        IconButton(
          tooltip: AppStrings.nextMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _go(1),
        ),
      ],
    );
  }

  bool _onToday() {
    final now = DateTime.now();
    return _month.year == now.year &&
        _month.month == now.month &&
        CalendarGrid.sameDay(_selected, now);
  }

  /// "5 أعياد ميلاد • 1 فعالية" for the visible month, counting up smoothly.
  Widget _monthSummary(_CalendarData data) {
    final classNames = const <String, String>{};
    var birthdays = 0;
    var events = 0;
    final last = DateTime(_month.year, _month.month + 1, 0).day;
    for (var d = 1; d <= last; d++) {
      for (final i in _itemsOn(
        DateTime(_month.year, _month.month, d),
        data,
        classNames,
      )) {
        i.kind == _Kind.event ? events++ : birthdays++;
      }
    }

    Widget stat(int n, String label, Color color) => TweenAnimationBuilder<
            double>(
          tween: Tween(end: n.toDouble()),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            '${v.round()} $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Row(
          key: ValueKey('$_month-$birthdays-$events'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (birthdays == 0 && events == 0)
              const Text(
                AppStrings.calendarMonthEmpty,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            if (birthdays > 0)
              stat(birthdays, AppStrings.calendarMonthBirthdays,
                  AppColors.coral),
            if (birthdays > 0 && events > 0)
              const Text('  •  ', style: TextStyle(color: AppColors.muted)),
            if (events > 0)
              stat(events, AppStrings.calendarMonthEvents, AppColors.gold),
          ],
        ),
      ),
    );
  }

  Widget _weekdayRow() {
    return Row(
      children: [
        for (final d in CalendarGrid.weekdayInitials)
          Expanded(
            child: Center(
              child: Text(
                d,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _dayCell(DateTime day, List<_Item> items) {
    final isSelected = CalendarGrid.sameDay(day, _selected);
    final isToday = CalendarGrid.sameDay(day, DateTime.now());
    final isSaturday = day.weekday == DateTime.saturday;
    final kinds = items.map((i) => i.kind).toSet();

    Color dot(_Kind k) => switch (k) {
          _Kind.child => AppColors.coral,
          _Kind.servant => AppColors.sky,
          _Kind.event => AppColors.gold,
        };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        if (!CalendarGrid.sameDay(day, _selected)) {
          HapticFeedback.selectionClick();
        }
        _selected = day;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 46,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.navy
              : isSaturday
                  ? AppColors.navy.withValues(alpha: 0.05)
                  : null,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.navy, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.navy,
              ),
              child: Text('${day.day}', textDirection: TextDirection.ltr),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final k in _Kind.values)
                    if (kinds.contains(k))
                      // Dots pop in when they appear (month change, filters).
                      TweenAnimationBuilder<double>(
                        key: ValueKey(k),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.elasticOut,
                        builder: (_, t, child) =>
                            Transform.scale(scale: t, child: child),
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : dot(k),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 4, backgroundColor: c),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        );
    return Wrap(
      spacing: 14,
      children: [
        item(AppColors.coral, AppStrings.childBirthdaysShort),
        item(AppColors.sky, AppStrings.servantBirthdaysShort),
        item(AppColors.gold, AppStrings.events),
      ],
    );
  }

  Widget _tile(_Item item) {
    final (color, icon) = switch (item.kind) {
      _Kind.child => (AppColors.coral, Icons.cake_outlined),
      _Kind.servant => (AppColors.sky, Icons.cake_outlined),
      _Kind.event => (AppColors.gold, Icons.event_outlined),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        onTap: item.onTap,
        trailing: item.onTap == null
            ? null
            : const Icon(Icons.chevron_left, color: AppColors.muted),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
