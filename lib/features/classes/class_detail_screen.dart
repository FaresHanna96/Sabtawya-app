import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_history_screen.dart';
import '../attendance/attendance_screen.dart';
import '../children/child_filters.dart';
import '../children/child_form_screen.dart';
import '../children/child_profile_screen.dart';
import '../children/child_tile.dart';
import 'class_form_screen.dart';
import 'patron_avatar.dart';

/// Everything about one class: its counters, its servants, and its children
/// with the same filtering as the main directory.
class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  static const _classes = ClassRepository();
  static const _children = ChildRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ClassDetail>>();
  final _searchController = TextEditingController();

  ChildFilter _filter = const ChildFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ClassDetail> _load() async {
    final overview = await _classes.overviewById(widget.classId);
    if (overview == null) {
      throw AppFailure(AppStrings.noPermission);
    }
    return _ClassDetail(
      overview: overview,
      servants: await _classes.servantsOfClass(widget.classId),
      children: await _children.byClass(widget.classId, includeInactive: true),
    );
  }

  Future<void> _reload() => _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _addChild() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ChildFormScreen(initialClassId: widget.classId),
      ),
    );
    if (added == true) await _reload();
  }

  Future<void> _openChild(Child child) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChildProfileScreen(childId: child.id),
      ),
    );
    await _reload();
  }

  Future<void> _takeAttendance() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(
          showAppBar: true,
          initialClassId: widget.classId,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceHistoryScreen(initialClassId: widget.classId),
      ),
    );
    await _reload();
  }

  Future<void> _edit(SchoolClass current) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClassFormScreen(existing: current),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _toggleArchive(ClassOverview overview) async {
    final archiving = overview.isActive;
    final confirmed = await Ui.confirm(
      context,
      title: archiving ? AppStrings.archiveClass : AppStrings.restoreClass,
      message: archiving ? AppStrings.confirmArchiveClass : null,
      destructive: archiving,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _classes.setActive(overview.classId, !archiving),
      successMessage: AppStrings.saved,
    );
    if (!ok || !mounted) return;

    await context.read<SessionController>().refreshClasses();
    await _reload();
  }

  Future<void> _delete(ClassOverview overview) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.deleteClass,
      message: AppStrings.confirmDeleteClass,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _classes.delete(overview.classId);
    } catch (e) {
      if (!mounted) return;
      // The restrict constraint is the expected outcome for a class that still
      // has children, so it gets an instruction rather than a raw error.
      final isInUse = e is AppFailure && e.code == '23503';
      Ui.info(
        context,
        isInUse ? AppStrings.classHasChildren : '$e',
      );
      return;
    }

    if (!mounted) return;
    await context.read<SessionController>().refreshClasses();
    if (!mounted) return;
    Ui.success(context, AppStrings.classDeleted);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final isGeneralServant = session.isGeneralServant;

    return Scaffold(
      body: AsyncSection<_ClassDetail>(
        key: _sectionKey,
        load: _load,
        builder: (context, data, reload) {
          final overview = data.overview;
          final visible = _filter.apply(data.children);
          final totalVisible = data.children
              .where((child) => _filter.includeInactive || child.isActive)
              .length;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(overview.className),
                pinned: true,
                actions: [
                  PopupMenuButton<_ClassAction>(
                    onSelected: (action) => switch (action) {
                      _ClassAction.edit => _edit(overview.asClass),
                      _ClassAction.archive => _toggleArchive(overview),
                      _ClassAction.delete => _delete(overview),
                    },
                    itemBuilder: (context) => [
                      if (isAdmin)
                        const PopupMenuItem<_ClassAction>(
                          value: _ClassAction.edit,
                          child: Text(AppStrings.editClass),
                        ),
                      if (isAdmin)
                        PopupMenuItem<_ClassAction>(
                          value: _ClassAction.archive,
                          child: Text(
                            overview.isActive
                                ? AppStrings.archiveClass
                                : AppStrings.restoreClass,
                          ),
                        ),
                      if (isAdmin)
                        const PopupMenuItem<_ClassAction>(
                          value: _ClassAction.delete,
                          child: Text(
                            AppStrings.deleteClass,
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList.list(
                  children: [
                    _stats(overview),
                    const SizedBox(height: 12),
                    _patron(overview),
                    const SizedBox(height: 12),
                    _actions(),
                    const SizedBox(height: 12),
                    _servants(data.servants),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            AppStrings.childrenTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addChild,
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text(AppStrings.addChild),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: ChildFilterBar(
                  filter: _filter,
                  searchController: _searchController,
                  resultCount: visible.length,
                  totalCount: totalVisible,
                  onChanged: (next) => setState(() => _filter = next),
                ),
              ),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: EmptyState(
                      icon: Icons.groups_outlined,
                      title: data.children.isEmpty
                          ? AppStrings.noChildren
                          : AppStrings.noData,
                      body: data.children.isEmpty
                          ? AppStrings.noChildrenBody
                          : AppStrings.clearFilters,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => ChildTile(
                      child: visible[index],
                      onTap: () => _openChild(visible[index]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _stats(ClassOverview overview) {
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              _Stat(
                label: AppStrings.childrenCount,
                value: '${overview.activeChildren}',
              ),
              _Stat(label: AppStrings.boys, value: '${overview.boysCount}'),
              _Stat(label: AppStrings.girls, value: '${overview.girlsCount}'),
              _Stat(
                label: AppStrings.servantsCount,
                value: '${overview.servantsCount}',
              ),
            ],
          ),
          if (overview.description != null) ...[
            const Divider(height: 20),
            Text(
              overview.description!,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
          const Divider(height: 20),
          InfoRow(
            label: AppStrings.lastAttendance,
            value: overview.lastSessionDate == null
                ? AppStrings.noUpcomingSession
                : AppDateUtils.formatDayDate(overview.lastSessionDate!),
            icon: Icons.event_available_outlined,
          ),
        ],
      ),
    );
  }

  Widget _patron(ClassOverview overview) {
    return SectionCard(
      title: AppStrings.patronSaint,
      child: Row(
        children: [
          PatronAvatar(photoPath: overview.patronPhotoPath, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              overview.patronName ?? AppStrings.noPatron,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: overview.patronName == null
                    ? AppColors.muted
                    : AppColors.maroon,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _takeAttendance,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text(AppStrings.attendanceTitle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _openHistory,
            icon: const Icon(Icons.history, size: 18),
            label: const Text(AppStrings.attendanceHistory),
          ),
        ),
      ],
    );
  }

  Widget _servants(List<ClassServant> servants) {
    return SectionCard(
      title: AppStrings.assignedServants,
      child: servants.isEmpty
          ? const Text(
              AppStrings.noServants,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: servants
                  .map(
                    (servant) => Chip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(servant.servantName),
                      backgroundColor: servant.servantIsActive
                          ? null
                          : AppColors.muted.withValues(alpha: 0.12),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

enum _ClassAction { edit, archive, delete }

class _ClassDetail {
  const _ClassDetail({
    required this.overview,
    required this.servants,
    required this.children,
  });

  final ClassOverview overview;
  final List<ClassServant> servants;
  final List<Child> children;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
