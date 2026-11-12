import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../state/session_controller.dart';
import 'class_detail_screen.dart';
import 'class_form_screen.dart';
import 'patron_avatar.dart';

/// The class list. An admin sees every class including archived ones; a servant
/// sees only the classes assigned to them, which the policies enforce.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  static const _repository = ClassRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<ClassOverview>>>();

  bool _includeArchived = false;

  Future<List<ClassOverview>> _load() =>
      _repository.overview(includeInactive: _includeArchived);

  Future<void> _reload() async {
    await _sectionKey.currentState?.reload();
    if (mounted) await context.read<SessionController>().refreshClasses();
  }

  Future<void> _open(ClassOverview overview) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ClassDetailScreen(classId: overview.classId),
      ),
    );
    await _reload();
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ClassFormScreen()),
    );
    if (added == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final isAdmin = session.isAdmin;
    final isGeneralServant = session.isGeneralServant;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text((isAdmin || isGeneralServant)
                  ? AppStrings.classesTitle
                  : AppStrings.myClasses),
              actions: [
                if (isAdmin)
                  IconButton(
                    tooltip: AppStrings.showInactive,
                    isSelected: _includeArchived,
                    icon: const Icon(Icons.inventory_2_outlined),
                    selectedIcon: const Icon(Icons.inventory_2),
                    onPressed: () {
                      setState(() => _includeArchived = !_includeArchived);
                      _sectionKey.currentState?.reload();
                    },
                  ),
              ],
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // When embedded as a tab there is no AppBar to hold the toggle.
            if (isAdmin && !widget.showAppBar)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: FilterChip(
                    label: const Text(AppStrings.showInactive),
                    avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                    selected: _includeArchived,
                    onSelected: (value) {
                      setState(() => _includeArchived = value);
                      _sectionKey.currentState?.reload();
                    },
                  ),
                ),
              ),
            Expanded(child: _buildList(isAdmin, isGeneralServant)),
          ],
        ),
      ),
      floatingActionButton: isAdmin
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
    return AsyncSection<List<ClassOverview>>(
      loading: const SkeletonList(),
      key: _sectionKey,
      load: _load,
      builder: (context, classes, reload) {
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
              accent: _palette[index % _palette.length],
              onTap: () => _open(classes[index]),
            ),
          ),
        );
      },
    );
  }
}

const _palette = <Color>[
  AppColors.navyLight,
  AppColors.olive,
  AppColors.coral,
  AppColors.gold,
  AppColors.sky,
  AppColors.maroon,
];

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.overview,
    required this.accent,
    required this.onTap,
  });

  final Color accent;
  final ClassOverview overview;
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
                  if (overview.lastSessionDate != null) ...[
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
