import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';
import '../excel/import_children_screen.dart';
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
  String? _classFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Inactive children are fetched whenever the toggle is on; the filter then
  // narrows in memory so chip taps stay instant.
  Future<List<Child>> _load() => _repository.all(
        includeInactive: true,
        classId: _classFilter,
      );

  Future<void> _reload() => _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _addChild() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChildFormScreen(initialClassId: _classFilter),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _importChildren() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ImportChildrenScreen(initialClassId: _classFilter),
      ),
    );
    if (imported == true) await _reload();
  }

  Future<void> _openProfile(Child child) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChildProfileScreen(childId: child.id),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final classes = context.watch<SessionController>().myClasses;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(AppStrings.childrenTitle),
              actions: [
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
                  onChanged: (next) => setState(() => _filter = next),
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
                                  : AppStrings.clearFilters,
                              action: null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => ChildTile(
                            child: visible[index],
                            className:
                                _classNameOf(classes, visible[index].classId),
                            onTap: () => _openProfile(visible[index]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: classes.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: _addChild,
              icon: const Icon(Icons.person_add_alt),
              label: const Text(AppStrings.addChild),
            ),
    );
  }

  Widget _classFilterRow(List<ClassOverview> classes) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _classChip(null, AppStrings.all),
            ...classes.map((item) => _classChip(item.classId, item.className)),
          ],
        ),
      ),
    );
  }

  Widget _classChip(String? classId, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _classFilter == classId,
        onSelected: (_) {
          setState(() => _classFilter = classId);
          _reload();
        },
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
