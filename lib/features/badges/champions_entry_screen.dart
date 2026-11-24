import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../data/models/child.dart';
import '../../data/models/reports.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import 'class_champions.dart';

/// What the list needs: the classes (for the filter), the children on a run
/// and their photos.
class ChampionsData {
  const ChampionsData({
    required this.classes,
    required this.streaks,
    this.children = const {},
    this.points = const {},
  });

  /// childId -> game points.
  final Map<String, int> points;

  final List<ClassOverview> classes;
  final List<ChildStreak> streaks;
  final Map<String, Child> children;
}

/// المزيد → «أبطال الالتزام»: every child on a run of Saturdays in a row,
/// longest first, over all the classes the caller can see, with a class
/// filter. A class page shows the same for its own class
/// ([ClassChampionsScreen]).
class ChampionsEntryScreen extends StatefulWidget {
  const ChampionsEntryScreen({super.key, this.load});

  /// Replaces the real read; tests give their own.
  final Future<ChampionsData> Function()? load;

  @override
  State<ChampionsEntryScreen> createState() => _ChampionsEntryScreenState();
}

class _ChampionsEntryScreenState extends State<ChampionsEntryScreen> {
  Set<String> _classIds = <String>{};

  Future<ChampionsData> _load() async {
    final custom = widget.load;
    if (custom != null) return custom();
    final yearId = context.read<SessionController>().currentYear?.id;
    final all = await const ClassRepository().overview();
    final classes = [
      for (final c in all)
        if (c.isActive) c,
    ];
    if (yearId == null) return ChampionsData(classes: classes, streaks: const []);
    final (streaks, children, boards) = await (
      const ReportRepository()
          .streaks(yearId: yearId, minAbsent: 999, minPresent: 3),
      const ChildRepository()
          .all()
          .then((list) => {for (final c in list) c.id: c})
          .catchError((Object _) => const <String, Child>{}),
      Future.wait([
        for (final c in classes) pointsOfClass(yearId, c.classId),
      ]),
    ).wait;
    return ChampionsData(
      classes: classes,
      streaks: streaks,
      children: children,
      points: {for (final m in boards) ...m},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.championsTitle)),
      body: SafeArea(
        child: AsyncSection<ChampionsData>(
          load: _load,
          builder: (context, data, reload) {
            final options = [
              for (final c in data.classes)
                ClassFilterOption(id: c.classId, name: c.className),
            ];
            final shown = [
              for (final s in data.streaks)
                if (_classIds.isEmpty || _classIds.contains(s.classId)) s,
            ];
            return Column(
              children: [
                if (options.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: ClassFilterChips(
                      classes: options,
                      selectedIds: _classIds,
                      onChanged: (ids) => setState(() => _classIds = ids),
                    ),
                  ),
                Expanded(
                  child: ChampionsView(
                    streaks: shown,
                    children: data.children,
                    points: data.points,
                    showClass: options.length > 1,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
