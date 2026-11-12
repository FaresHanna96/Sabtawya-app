import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_profile_screen.dart';

/// Shows today's birthdays on the home screen, split into two cards:
/// one for children (المخدومين) and one for servants (الخدام).
class TodayBirthdaysSection extends StatefulWidget {
  const TodayBirthdaysSection({super.key});

  @override
  State<TodayBirthdaysSection> createState() => _TodayBirthdaysSectionState();
}

class _TodayBirthdaysSectionState extends State<TodayBirthdaysSection> {
  static const _childRepo = ChildRepository();
  static const _servantRepo = ServantRepository();

  late final Future<(List<Child>, List<Profile>)> _future = Future.wait([
    _childRepo.all(),
    _servantRepo.servantsWithBirthdayToday(),
  ]).then(
      (results) => (results[0] as List<Child>, results[1] as List<Profile>));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Child>, List<Profile>)>(
      future: _future,
      builder: (context, snapshot) {
        final today = DateTime.now();
        final childBirthdays = snapshot.hasData
            ? (snapshot.data!.$1
                .where((c) =>
                    c.birthDate != null &&
                    c.birthDate!.month == today.month &&
                    c.birthDate!.day == today.day)
                .toList()
              ..sort((a, b) => a.fullName.compareTo(b.fullName)))
            : <Child>[];
        final servantBirthdays =
            snapshot.hasData ? snapshot.data!.$2 : <Profile>[];

        final session = context.read<SessionController>();

        // Nothing until the first answer, so the cards do not flash empty.
        if (!snapshot.hasData) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _BirthdayTiles(
            childCount: childBirthdays.length,
            servantCount: servantBirthdays.length,
            childContent: session.isAdmin
                ? _GroupedBirthdays(
                    birthdays: childBirthdays,
                    classes: session.myClasses,
                  )
                : _FlatBirthdays(birthdays: childBirthdays),
            servantContent: _ServantBirthdays(servants: servantBirthdays),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- shared card

/// Today's birthdays as two tiles (children / servants) with their counts.
/// A day with none is a single slim line instead of two empty cards; on a day
/// with birthdays the first list with someone in it opens by itself.
class _BirthdayTiles extends StatefulWidget {
  const _BirthdayTiles({
    required this.childCount,
    required this.servantCount,
    required this.childContent,
    required this.servantContent,
  });

  final int childCount;
  final int servantCount;
  final Widget childContent;
  final Widget servantContent;

  @override
  State<_BirthdayTiles> createState() => _BirthdayTilesState();
}

class _BirthdayTilesState extends State<_BirthdayTiles> {
  /// 0 = children, 1 = servants, null = closed.
  late int? _open = widget.childCount > 0
      ? 0
      : widget.servantCount > 0
          ? 1
          : null;

  @override
  Widget build(BuildContext context) {
    if (widget.childCount == 0 && widget.servantCount == 0) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _EmptyBirthdays(),
        ),
      );
    }

    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  _tile(0, widget.childCount, AppStrings.childBirthdaysTitle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _tile(1, widget.servantCount, AppStrings.servantBirthdays),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: open == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: KeyedSubtree(
                          key: ValueKey(open),
                          child: (open == 0
                                      ? widget.childCount
                                      : widget.servantCount) ==
                                  0
                              ? const _EmptyBirthdays()
                              : (open == 0
                                  ? widget.childContent
                                  : widget.servantContent),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _tile(int which, int count, String label) {
    final selected = _open == which;
    const color = AppColors.warning;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.12)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.6) : Colors.transparent,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = selected ? null : which),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: count > 0 ? 0.18 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cake_rounded,
                    size: 18,
                    color: count > 0 ? color : AppColors.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: count),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          '$v',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: count > 0 ? color : AppColors.muted,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: selected ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- empty state

class _EmptyBirthdays extends StatelessWidget {
  const _EmptyBirthdays();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cake_outlined, size: 16, color: AppColors.muted),
          SizedBox(width: 8),
          Text(
            'لا توجد اعياد ميلاد اليوم',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- servant view

class _ServantBirthdays extends StatelessWidget {
  const _ServantBirthdays({required this.servants});

  final List<Profile> servants;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: servants.map((s) => _ServantBirthdayRow(servant: s)).toList(),
    );
  }
}

class _ServantBirthdayRow extends StatelessWidget {
  const _ServantBirthdayRow({required this.servant});

  final Profile servant;

  @override
  Widget build(BuildContext context) {
    final birth = servant.birthDate!;
    final age = DateTime.now().year - birth.year;
    final hasPhone = servant.mobile != null && servant.mobile!.isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cake_outlined,
          size: 16,
          color: AppColors.warning,
        ),
      ),
      title: Text(
        servant.fullName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${AppStrings.turningAge} $age ${AppStrings.years}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.call, size: 18),
        color: hasPhone ? AppColors.success : AppColors.muted,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        tooltip: hasPhone ? AppStrings.call : AppStrings.noPhoneNumber,
        onPressed: hasPhone
            ? () => launchUrl(Uri(scheme: 'tel', path: servant.mobile!))
            : null,
      ),
    );
  }
}

// --------------------------------------------------------------- grouped view

class _GroupedBirthdays extends StatelessWidget {
  const _GroupedBirthdays({
    required this.birthdays,
    required this.classes,
  });

  final List<Child> birthdays;
  final List<ClassOverview> classes;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Child>>{};
    for (final child in birthdays) {
      (grouped[child.classId] ??= []).add(child);
    }

    final widgets = <Widget>[];
    var first = true;
    for (final entry in grouped.entries) {
      final className = _classNameOf(entry.key) ?? entry.key;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 4),
          child: Text(
            className,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
      first = false;
      for (final child in entry.value) {
        widgets.add(_BirthdayRow(child: child));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  String? _classNameOf(String classId) {
    for (final item in classes) {
      if (item.classId == classId) return item.className;
    }
    return null;
  }
}

// --------------------------------------------------------------- flat view

class _FlatBirthdays extends StatelessWidget {
  const _FlatBirthdays({required this.birthdays});

  final List<Child> birthdays;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: birthdays.map((c) => _BirthdayRow(child: c)).toList(),
    );
  }
}

// --------------------------------------------------------------- single row

class _BirthdayRow extends StatelessWidget {
  const _BirthdayRow({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final birth = child.birthDate!;
    final age = DateTime.now().year - birth.year;
    final hasPhone = child.mobile != null && child.mobile!.isNotEmpty;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cake_outlined,
          size: 16,
          color: AppColors.warning,
        ),
      ),
      title: Text(
        child.fullName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${AppStrings.turningAge} $age ${AppStrings.years}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: hasPhone
          ? IconButton(
              icon: const Icon(Icons.call, size: 18),
              color: AppColors.success,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: AppStrings.call,
              onPressed: () =>
                  launchUrl(Uri(scheme: 'tel', path: child.mobile!)),
            )
          : null,
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChildProfileScreen(childId: child.id),
        ),
      ),
    );
  }
}
