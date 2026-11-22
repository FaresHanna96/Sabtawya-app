import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';
import '../excel/import_children_screen.dart';
import 'child_contact_sheet.dart';
import 'child_filters.dart';
import 'child_form_screen.dart';
import 'child_profile_screen.dart';
import 'child_tile.dart';

/// The children directory. A servant sees the children of their assigned
/// classes only, enforced by the `children_select` policy rather than by the
/// class filter below.
class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  static const _repository = ChildRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<Child>>>();
  final _searchController = TextEditingController();

  ChildFilter _filter = const ChildFilter();

  /// The classes chosen; empty is all of them.
  Set<String> _classFilter = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Inactive children are fetched only while the toggle is on; the filter
  // then narrows in memory so the other chips stay instant.
  Future<List<Child>> _load() async {
    final all = await _repository.all(
      includeInactive: _filter.includeInactive,
      // One class: let the database narrow it. Several: narrow here.
      classId: _classFilter.length == 1 ? _classFilter.first : null,
    );
    if (_classFilter.length <= 1) return all;
    return all.where((c) => _classFilter.contains(c.classId)).toList();
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _addChild() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChildFormScreen(
            initialClassId:
                (_classFilter.length == 1 ? _classFilter.first : null)),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _importChildren() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ImportChildrenScreen(
          initialClassId:
              (_classFilter.length == 1 ? _classFilter.first : null),
        ),
      ),
    );
    if (imported == true) await _reload();
  }

  /// No reload on the way back: an edit made there goes through
  /// `Ui.runGuarded`, which marks the data changed, and the list reloads on
  /// that by itself. Just looking at a profile no longer refetches everyone.
  Future<void> _openProfile(Child child) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChildProfileScreen(childId: child.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final classes = session.myClasses;
    // خادم عام sees every child but does not add, edit or import them.
    final canEdit = !session.isGeneralServant;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(AppStrings.childrenTitle),
              actions: [
                if (canEdit)
                  IconButton(
                    tooltip: AppStrings.importChildren,
                    onPressed: _importChildren,
                    icon: const Icon(Icons.upload_file),
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: AsyncSection<List<Child>>(
          loading: const SkeletonList(),
          key: _sectionKey,
          load: _load,
          builder: (context, all, reload) {
            final visible = _filter.apply(all);
            final totalVisible = all
                .where((child) => _filter.includeInactive || child.isActive)
                .length;

            return Column(
              children: [
                if (classes.length > 1) _classFilterRow(classes),
                ChildFilterBar(
                  filter: _filter,
                  searchController: _searchController,
                  resultCount: visible.length,
                  totalCount: totalVisible,
                  // Only offer boys / girls when the list holds both.
                  showGender: all.any((c) => c.gender == Gender.boy) &&
                      all.any((c) => c.gender == Gender.girl),
                  onChanged: (next) {
                    final refetch =
                        next.includeInactive != _filter.includeInactive;
                    setState(() => _filter = next);
                    // Turning inactive children on needs them fetched.
                    if (refetch) _reload();
                  },
                ),
                Expanded(
                  child: visible.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.06,
                            ),
                            EmptyState(
                              icon: Icons.groups_outlined,
                              title: all.isEmpty
                                  ? AppStrings.noChildren
                                  : AppStrings.noData,
                              body: all.isEmpty
                                  ? AppStrings.noChildrenBody
                                  : null,
                              // Filters hid everyone: one tap shows them again.
                              action: all.isEmpty
                                  ? null
                                  : OutlinedButton.icon(
                                      onPressed: () {
                                        _searchController.clear();
                                        final refetch =
                                            _filter.includeInactive;
                                        setState(() =>
                                            _filter = const ChildFilter());
                                        if (refetch) _reload();
                                      },
                                      icon: const Icon(
                                          Icons.filter_alt_off_outlined),
                                      label:
                                          const Text(AppStrings.clearFilters),
                                    ),
                            ),
                          ],
                        )
                      : _list(visible, classes),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: (classes.isEmpty || !canEdit)
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: _addChild,
              icon: const Icon(Icons.person_add_alt),
              label: const Text(AppStrings.addChild),
            ),
    );
  }

  /// The one-line class picker every list uses ("كل الفصول ▾"), which opens
  /// the classes in a sheet.
  Widget _classFilterRow(List<ClassOverview> classes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClassFilterChips(
        classes: classes
            .map((c) => ClassFilterOption(id: c.classId, name: c.className))
            .toList(),
        selectedIds: _classFilter,
        onChanged: (ids) {
          setState(() => _classFilter = ids);
          _reload();
        },
      ),
    );
  }

  /// More than one class on screen: "كل الفصول" or several ticked.
  bool _severalClasses(List<ClassOverview> classes) =>
      _classFilter.length > 1 || (_classFilter.isEmpty && classes.length > 1);

  /// The children, under a header per class when several classes are shown
  /// (names A-Z inside each, as filtered); one plain list otherwise.
  Widget _list(List<Child> visible, List<ClassOverview> classes) {
    final grouped = _severalClasses(classes);
    return ClassGroupedList<Child>(
      items: visible,
      grouped: grouped,
      classOf: (c) => c.classId,
      classOrder: [for (final c in classes) c.classId],
      classNameOf: (id) => _classNameOf(classes, id) ?? '',
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      spacing: 10,
      itemBuilder: (context, child, _) => ChildTile(
        child: child,
        // The header already names the class.
        className: grouped ? null : _classNameOf(classes, child.classId),
        onTap: () => _openProfile(child),
        onContact: () => showChildContactSheet(context, child),
      ),
    );
  }

  static String? _classNameOf(List<ClassOverview> classes, String classId) {
    for (final item in classes) {
      if (item.classId == classId) return item.className;
    }
    return null;
  }
}
