import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';
import '../children/child_profile_screen.dart';

/// Shows today's birthdays on the home screen.
///
/// Always visible: shows an empty message when no one has a birthday today.
/// Admins see all children grouped by class; servants see only their own class
/// (RLS already restricts [ChildRepository.all] to the servant's classes).
class TodayBirthdaysSection extends StatefulWidget {
  const TodayBirthdaysSection({super.key});

  @override
  State<TodayBirthdaysSection> createState() => _TodayBirthdaysSectionState();
}

class _TodayBirthdaysSectionState extends State<TodayBirthdaysSection> {
  static const _repo = ChildRepository();

  late final Future<List<Child>> _future = _repo.all();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Child>>(
      future: _future,
      builder: (context, snapshot) {
        final today = DateTime.now();
        // Treat loading and error the same as "no birthdays" so the card is
        // always visible regardless of network state.
        final birthdays = snapshot.hasData
            ? (snapshot.data!
                .where(
                  (c) =>
                      c.birthDate != null &&
                      c.birthDate!.month == today.month &&
                      c.birthDate!.day == today.day,
                )
                .toList()
              ..sort((a, b) => a.fullName.compareTo(b.fullName)))
            : <Child>[];

        final session = context.read<SessionController>();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                title: Row(
                  children: [
                    Text(
                      AppStrings.todayBirthdays,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (birthdays.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${birthdays.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                children: [
                  birthdays.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.cake_outlined, size: 16, color: AppColors.muted),
                              SizedBox(width: 8),
                              Text(
                                'لا توجد اعياد ميلاد اليوم',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        )
                      : session.isAdmin
                          ? _GroupedBirthdays(
                              birthdays: birthdays,
                              classes: session.myClasses,
                            )
                          : _FlatBirthdays(birthdays: birthdays),
                ],
              ),
            ),
          ),
        );
      },
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
              fontSize: 11,
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
        style: const TextStyle(fontSize: 11),
      ),
      trailing: hasPhone
          ? IconButton(
              icon: const Icon(Icons.call, size: 18),
              color: AppColors.success,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'اتصال',
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
