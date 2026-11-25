import 'package:flutter/material.dart';
import '../../core/utils/phone.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import '../children/birthday_whatsapp_button.dart';
import '../children/child_profile_screen.dart';

/// Shows today's birthdays on the home screen, split into two cards:
/// one for children (المخدومين) and one for servants (الخدام).
class TodayBirthdaysSection extends StatefulWidget {
  const TodayBirthdaysSection({
    super.key,
    this.reloadToken = 0,
    this.hideWhenEmpty = false,
    this.compact = false,
  });

  /// One line («🎂 أعياد ميلاد النهارده · 2 مخدوم») that opens the lists on a
  /// tap, instead of the tiles and the open list.
  final bool compact;

  /// No line at all on a day without birthdays (the admin home).
  final bool hideWhenEmpty;

  /// Changes when the home reloads (pull-to-refresh, or data changed
  /// elsewhere); the card then fetches again, keeping what it shows meanwhile.
  final int reloadToken;

  @override
  State<TodayBirthdaysSection> createState() => _TodayBirthdaysSectionState();
}

class _TodayBirthdaysSectionState extends State<TodayBirthdaysSection> {
  static const _childRepo = ChildRepository();
  static const _servantRepo = ServantRepository();

  late Future<(List<Child>, List<Profile>)> _future = _fetch();

  static Future<(List<Child>, List<Profile>)> _fetch() =>
      (_childRepo.all(), _servantRepo.servantsWithBirthdayToday()).wait;

  /// The two-tile card, or (compact) the one folded line whose lists show
  /// directly when it opens: no second fold inside the first.
  Widget _body({
    required int kids,
    required int servants,
    required Widget childContent,
    required Widget servantContent,
  }) {
    if (!widget.compact) {
      return _BirthdayTiles(
        childCount: kids,
        servantCount: servants,
        childContent: childContent,
        servantContent: servantContent,
      );
    }
    return CompactBirthdays(
      childCount: kids,
      servantCount: servants,
      details: BirthdaySections(
        children: [
          if (kids > 0)
            (
              title: AppStrings.childBirthdaysTitle,
              count: kids,
              content: childContent,
            ),
          if (servants > 0)
            (
              title: AppStrings.servantBirthdays,
              count: servants,
              content: servantContent,
            ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(TodayBirthdaysSection old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) _future = _fetch();
  }

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
                    AppDateUtils.isBirthdayOn(c.birthDate!, today))
                .toList()
              ..sort((a, b) => a.fullName.compareTo(b.fullName)))
            : <Child>[];
        final servantBirthdays =
            snapshot.hasData ? snapshot.data!.$2 : <Profile>[];

        final session = context.read<SessionController>();

        // Nothing until the first answer, so the cards do not flash empty.
        if (!snapshot.hasData) return const SizedBox.shrink();
        if (widget.hideWhenEmpty &&
            childBirthdays.isEmpty &&
            servantBirthdays.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _body(
            kids: childBirthdays.length,
            servants: servantBirthdays.length,
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

// --------------------------------------------------------------- sections

/// One group of today's birthdays: its title, how many, and its list.
typedef BirthdayGroup = ({String title, int count, Widget content});

/// The groups one under another, each with a small heading: what shows when
/// the compact line opens (nothing to tap open inside).
class BirthdaySections extends StatelessWidget {
  const BirthdaySections({super.key, required this.children});

  final List<BirthdayGroup> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 20,
                color: AppColors.navy.withValues(alpha: 0.08),
              ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    children[i].title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${children[i].count}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.goldText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            children[i].content,
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- compact line

/// The birthdays folded to one tappable line; the tiles open under it.
class CompactBirthdays extends StatefulWidget {
  const CompactBirthdays({
    super.key,
    required this.childCount,
    required this.servantCount,
    required this.details,
  });

  final int childCount;
  final int servantCount;
  final Widget details;

  @override
  State<CompactBirthdays> createState() => _CompactBirthdaysState();
}

class _CompactBirthdaysState extends State<CompactBirthdays> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cake_rounded,
                      size: 20, color: AppColors.goldText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(
                          text: AppStrings.birthdaysToday,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: '  •  ${AppStrings.birthdaysSummary(widget.childCount, widget.servantCount)}',
                          style: const TextStyle(
                            color: AppColors.goldText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: widget.details,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
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
            AppStrings.noBirthdaysToday,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BirthdayWhatsAppButton(
            name: servant.fullName,
            servantName: context.read<SessionController>().displayName,
            ownMobile: servant.mobile,
            girl: servant.gender == Gender.girl,
            compact: true,
          ),
          IconButton(
            icon: const Icon(Icons.call, size: 18),
            color: hasPhone ? AppColors.success : AppColors.muted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: hasPhone ? AppStrings.call : AppStrings.noPhoneNumber,
            onPressed: hasPhone
                ? () => callNumber(servant.mobile!)
                : null,
          ),
        ],
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
      final className = classes.nameOf(entry.key) ?? entry.key;
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
    final callTo = callNumberFor(child);
    final hasPhone = callTo != null;

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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BirthdayWhatsAppButton(
            name: child.fullName,
            servantName: context.read<SessionController>().displayName,
            ownMobile: child.mobile,
            child: child,
            girl: child.gender == Gender.girl,
            compact: true,
          ),
          if (hasPhone)
            IconButton(
              icon: const Icon(Icons.call, size: 18),
              color: AppColors.success,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: AppStrings.call,
              onPressed: () => callNumber(callTo),
            ),
        ],
      ),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChildProfileScreen(childId: child.id),
        ),
      ),
    );
  }
}
