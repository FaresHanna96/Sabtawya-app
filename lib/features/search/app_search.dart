import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_sort.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../children/child_profile_screen.dart';
import '../classes/class_detail_screen.dart';

/// Search from the top bar: children (name, mobile, code), classes and, for
/// an admin, servants. Spelling variants are ignored (أ/ا, ى/ي, ة/ه).
class AppSearchDelegate extends SearchDelegate<void> {
  AppSearchDelegate({required this.classes, required this.isAdmin})
      : super(searchFieldLabel: AppStrings.searchEverything);

  final List<ClassOverview> classes;
  final bool isAdmin;

  // Loaded once per search, then filtered as the user types.
  late final Future<(List<Child>, List<Profile>)> _data = (
    const ChildRepository().all(includeInactive: false),
    isAdmin
        ? const ServantRepository().servants(includeInactive: false)
        : Future.value(const <Profile>[]),
  ).wait;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            tooltip: AppStrings.clearSearch,
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        tooltip: AppStrings.close,
        icon: const BackButtonIcon(),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  String? _className(String id) {
    for (final c in classes) {
      if (c.classId == id) return c.className;
    }
    return null;
  }

  Widget _results(BuildContext context) {
    final q = ArabicSort.key(query);
    if (q.length < 2) {
      return const _Hint(text: AppStrings.searchHint);
    }
    bool hit(String? s) => s != null && ArabicSort.key(s).contains(q);

    return FutureBuilder<(List<Child>, List<Profile>)>(
      future: _data,
      builder: (context, snap) {
        if (!snap.hasData) {
          return snap.hasError
              ? const _Hint(text: AppStrings.somethingWentWrong)
              : const Center(child: CircularProgressIndicator());
        }
        final (children, servants) = snap.data!;
        final kids = children
            .where((c) =>
                hit(c.fullName) ||
                (c.code ?? '').toLowerCase().contains(q) ||
                [c.mobile, c.motherMobile, c.fatherMobile]
                    .any((m) => (m ?? '').contains(q)))
            .take(30)
            .toList();
        final cls = classes
            .where((c) => hit(c.className) || hit(c.patronName))
            .toList();
        final serv = servants
            .where((s) => hit(s.fullName) || (s.mobile ?? '').contains(q))
            .take(15)
            .toList();

        if (kids.isEmpty && cls.isEmpty && serv.isEmpty) {
          return const _Hint(text: AppStrings.noResults);
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (cls.isNotEmpty) ...[
              const _Section(title: AppStrings.classesNav),
              for (final c in cls)
                ListTile(
                  leading:
                      const Icon(Icons.class_outlined, color: AppColors.navy),
                  title: Text(c.className),
                  subtitle: c.patronName == null ? null : Text(c.patronName!),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ClassDetailScreen(classId: c.classId),
                    ),
                  ),
                ),
            ],
            if (kids.isNotEmpty) ...[
              _Section(title: '${AppStrings.childrenNav} (${kids.length})'),
              for (final c in kids)
                ListTile(
                  leading: Icon(
                    c.gender == Gender.boy ? Icons.boy : Icons.girl,
                    color: c.gender == Gender.boy
                        ? AppColors.sky
                        : AppColors.coral,
                  ),
                  title: Text(c.fullName),
                  subtitle: Text(
                    [
                      _className(c.classId),
                      if ((c.code ?? '').isNotEmpty) c.code,
                    ].whereType<String>().join(' • '),
                  ),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ChildProfileScreen(childId: c.id),
                    ),
                  ),
                ),
            ],
            if (serv.isNotEmpty) ...[
              const _Section(title: AppStrings.servantsTitle),
              for (final s in serv)
                ListTile(
                  leading: const Icon(Icons.volunteer_activism_outlined,
                      color: AppColors.olive),
                  title: Text(s.fullName),
                  subtitle: Text(s.roleLabel),
                  trailing: (s.mobile ?? '').isEmpty
                      ? null
                      : IconButton(
                          tooltip: AppStrings.call,
                          icon: const Icon(Icons.call_rounded),
                          color: AppColors.success,
                          onPressed: () => launchUrl(
                              Uri(scheme: 'tel', path: s.mobile!.trim())),
                        ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
          ),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      );
}
