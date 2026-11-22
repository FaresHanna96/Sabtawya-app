import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/class_colors.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import 'class_detail_screen.dart';
import 'class_health_tab.dart';
import 'class_form_screen.dart';
import 'patron_avatar.dart';

export '../../core/theme/class_colors.dart' show classColourIndex;

/// The class list. An admin sees every class including archived ones; a servant
/// sees only the classes assigned to them, which the policies enforce. A
/// servant with a single class sees that class's page here instead of a list.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  /// The class to show directly: a servant's one and only class. Null for
  /// an admin or general servant (every class) and for two or more classes.
  static ClassOverview? onlyClass({
    required bool everyClass,
    required List<ClassOverview> mine,
  }) =>
      !everyClass && mine.length == 1 ? mine.single : null;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen>
    with SingleTickerProviderStateMixin {
  static const _repository = ClassRepository();

  static const _reports = ReportRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ClassesData>>();

  /// The list, and متابعة الفصول (moved here from the home page).
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() {
      // The add button belongs to the list only.
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });

  bool _includeArchived = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The classes, and whether each took this week's attendance (that part
  /// is best effort: without it the cards just do not say).
  Future<_ClassesData> _load() async {
    final yearId = context.read<SessionController>().currentYear?.id;
    final saturday = AppDateUtils.lastSaturday(DateTime.now());
    final (classes, recorded) = await (
      _repository.overview(includeInactive: _includeArchived),
      yearId == null
          ? Future.value(const <String, bool>{})
          : _reports
              .recordedOn(yearId: yearId, date: saturday)
              .catchError((Object _) => const <String, bool>{}),
    ).wait;
    return _ClassesData(classes, recorded, saturday);
  }

  /// This class's attendance for [date], then back to the list.
  Future<void> _record(String classId, DateTime date) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceScreen(
          showAppBar: true,
          initialClassId: classId,
          initialDate: date,
        ),
      ),
    );
  }

  Future<void> _reload() async {
    await _sectionKey.currentState?.reload();
    if (mounted) await context.read<SessionController>().refreshClasses();
  }

  /// Reloads on the way back only when something was saved meanwhile (every
  /// save marks the data changed), so just looking at a class costs nothing.
  Future<void> _open(ClassOverview overview) async {
    final session = context.read<SessionController>();
    final before = session.dataVersion;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClassDetailScreen(classId: overview.classId),
      ),
    );
    if (mounted && session.dataVersion != before) await _reload();
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ClassFormScreen()),
    );
    if (added == true) await _reload();
  }

  void _toggleArchived(bool value) {
    setState(() => _includeArchived = value);
    _sectionKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final isGeneralServant = session.isGeneralServant;
    final everyClass = isAdmin || isGeneralServant;

    final tabBar = TabBar(
      controller: _tabs,
      indicatorColor: Colors.white,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      tabs: [
        Tab(
          text: everyClass ? AppStrings.classesTitle : AppStrings.myClasses,
        ),
        Tab(
          text: everyClass
              ? AppStrings.classHealthTitle
              : AppStrings.myClassHealthTitle,
        ),
      ],
    );

    // A servant with one class gets that class itself: a list holding one
    // card would only be a tap in the way.
    final onlyClass = ClassesScreen.onlyClass(
      everyClass: everyClass,
      mine: session.myClasses,
    );

    final list = _buildList(isAdmin, isGeneralServant);

    // Archived classes: an icon on the tab strip, not a row of its own.
    final archiveToggle = IconButton(
      tooltip: AppStrings.showInactive,
      isSelected: _includeArchived,
      icon: const Icon(Icons.inventory_2_outlined),
      selectedIcon: const Icon(Icons.inventory_2),
      onPressed: () => _toggleArchived(!_includeArchived),
    );

    // Each page keeps its state (and its loaded data) while the other shows.
    final pages = TabBarView(
      controller: _tabs,
      children: [
        _KeepAlive(
          child: onlyClass == null
              ? list
              : ClassDetailScreen(
                  key: ValueKey(onlyClass.classId),
                  classId: onlyClass.classId,
                  embedded: true,
                ),
        ),
        const _KeepAlive(child: ClassHealthTab()),
      ],
    );

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(
                  everyClass ? AppStrings.classesTitle : AppStrings.myClasses),
              actions: [
                if (isAdmin && _tabs.index == 0) archiveToggle,
              ],
              bottom: tabBar,
            )
          : null,
      body: SafeArea(
        child: widget.showAppBar
            ? pages
            : Column(
                children: [
                  Material(
                    color: Theme.of(context).appBarTheme.backgroundColor ??
                        Theme.of(context).colorScheme.primary,
                    child: Row(
                      children: [
                        Expanded(child: tabBar),
                        if (isAdmin && _tabs.index == 0)
                          IconTheme(
                            data: const IconThemeData(color: Colors.white),
                            child: archiveToggle,
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: pages),
                ],
              ),
      ),
      floatingActionButton: isAdmin && _tabs.index == 0
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.addClass),
            )
          : null,
    );
  }

  Widget _buildList(bool isAdmin, bool isGeneralServant) {
    return AsyncSection<_ClassesData>(
      loading: const SkeletonList(),
      key: _sectionKey,
      load: _load,
      builder: (context, data, reload) {
        final classes = data.classes;
        if (classes.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.class_outlined,
                title: (isAdmin || isGeneralServant)
                    ? AppStrings.noClasses
                    : AppStrings.noClassesAssigned,
                body: (isAdmin || isGeneralServant)
                    ? null
                    : AppStrings.noClassesAssignedBody,
                action: isAdmin
                    ? FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: const Text(AppStrings.addClass),
                      )
                    : null,
              ),
            ],
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 12, 16, isAdmin ? 96 : 24),
          itemCount: classes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: _ClassCard(
              overview: classes[index],
              accent: classAccent(classes[index].classId),
              saturday: data.saturday,
              recorded: data.recorded[classes[index].classId],
              onRecord: () => _record(classes[index].classId, data.saturday),
              onTap: () => _open(classes[index]),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps a sub-tab's page alive while the other one is on screen.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The list and this week's attendance status per class.
class _ClassesData {
  const _ClassesData(this.classes, this.recorded, this.saturday);

  final List<ClassOverview> classes;

  /// Class id -> attendance taken for [saturday]; absent when the class has
  /// no session that day.
  final Map<String, bool> recorded;
  final DateTime saturday;
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.overview,
    required this.accent,
    required this.saturday,
    required this.recorded,
    required this.onRecord,
    required this.onTap,
  });

  final Color accent;
  final ClassOverview overview;
  final DateTime saturday;

  /// Attendance taken for [saturday]; null when the class did not meet then.
  final bool? recorded;
  final VoidCallback onRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      PatronAvatar(
                          photoPath: overview.patronPhotoPath, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              overview.className,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (overview.patronName != null)
                              Text(
                                overview.patronName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.maroon,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!overview.isActive)
                        const StatusBadge(isActive: false),
                      const Icon(AppIcons.forward, color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Pill(
                        icon: Icons.groups_outlined,
                        value: '${overview.activeChildren}',
                        label: AppStrings.pillChildren,
                      ),
                      _Pill(
                        icon: Icons.boy,
                        value: '${overview.boysCount}',
                        label: AppStrings.boys,
                        color: AppColors.navyLight,
                      ),
                      _Pill(
                        icon: Icons.girl,
                        value: '${overview.girlsCount}',
                        label: AppStrings.girls,
                        color: AppColors.olive,
                      ),
                      _Pill(
                        icon: Icons.volunteer_activism_outlined,
                        value: '${overview.servantsCount}',
                        label: AppStrings.pillServants,
                      ),
                    ],
                  ),
                  if (recorded != null && overview.isActive) ...[
                    const SizedBox(height: 10),
                    ClassSaturdayStatus(
                      recorded: recorded!,
                      day: '${saturday.day} '
                          '${AppDateUtils.monthName(saturday.month)}',
                      onRecord: onRecord,
                    ),
                  ] else if (overview.lastSessionDate != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_available_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${AppStrings.lastAttendance}: '
                          '${AppDateUtils.formatDate(overview.lastSessionDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "اتسجّل حضور 21 نوفمبر", or "لم يُسجَّل بعد" with a button to do it.
@visibleForTesting
class ClassSaturdayStatus extends StatelessWidget {
  const ClassSaturdayStatus({
    super.key,
    required this.recorded,
    required this.day,
    required this.onRecord,
  });

  final bool recorded;
  final String day;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final color = recorded ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            recorded
                ? Icons.check_circle_rounded
                : Icons.pending_actions_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recorded
                  ? AppStrings.classRecordedOn(day)
                  : AppStrings.classNotRecordedOn(day),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          if (!recorded)
            TextButton(
              onPressed: onRecord,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.navy,
                minimumSize: const Size(0, 40),
              ),
              child: const Text(AppStrings.recordNow),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final String value;

  /// Says what the number counts; an icon alone was not enough to tell.
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
