import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/class_colors.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';

/// Admin-only screen for attaching servants to classes.
///
/// A servant belongs to one class. A class may still have several servants.
class ServantAssignmentsScreen extends StatefulWidget {
  const ServantAssignmentsScreen({super.key});

  @override
  State<ServantAssignmentsScreen> createState() =>
      _ServantAssignmentsScreenState();
}

class _ServantAssignmentsScreenState extends State<ServantAssignmentsScreen> {
  static const _classes = ClassRepository();
  static const _servants = ServantRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_AssignmentsData>>();

  // Three independent reads, side by side.
  Future<_AssignmentsData> _load() async {
    final (classes, assignments, servants) = await (
      _classes.list(),
      _classes.allAssignments(),
      _servants.servants(includeInactive: false),
    ).wait;
    return _AssignmentsData(
      classes: classes,
      assignments: assignments,
      servants: servants,
    );
  }

  Future<void> _reload() async {
    await _sectionKey.currentState?.reload();
    if (mounted) await context.read<SessionController>().refreshClasses();
  }

  Future<void> _assign(SchoolClass target, _AssignmentsData data) async {
    // Exclude servants already in this class — moving within the same class
    // makes no sense.
    final alreadyInTarget = data.assignments
        .where((a) => a.classId == target.id)
        .map((a) => a.servantId)
        .toSet();
    final available =
        data.servants.where((s) => !alreadyInTarget.contains(s.id)).toList();

    if (available.isEmpty) {
      Ui.info(context, AppStrings.noServantToAssign);
      return;
    }

    // Build a map from servantId → current class name (for servants already
    // assigned somewhere else, so the admin can see they'll be moved).
    final currentClass = <String, String>{
      for (final a in data.assignments) a.servantId: a.className,
    };

    final servantId = await pickServantForClass(
      context,
      className: target.name,
      available: available,
      currentClass: currentClass,
    );
    if (servantId == null || !mounted) return;

    final isMove = currentClass.containsKey(servantId);
    final ok = await Ui.runGuarded(
      context,
      () => _classes.assignServant(classId: target.id, servantId: servantId),
      successMessage:
          isMove ? AppStrings.servantMoved : AppStrings.servantAssigned,
    );
    if (ok) await _reload();
  }

  Future<void> _remove(ClassServant assignment) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.removeServant,
      message: '${assignment.servantName} — ${assignment.className}',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _classes.removeAssignment(assignment.assignmentId),
      successMessage: AppStrings.servantRemoved,
    );
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.assignmentsTitle)),
      body: SafeArea(
        child: AsyncSection<_AssignmentsData>(
          key: _sectionKey,
          load: _load,
          builder: (context, data, reload) {
            if (data.classes.isEmpty) {
              return const EmptyState(
                icon: Icons.class_outlined,
                title: AppStrings.noClasses,
              );
            }

            final assigned = {for (final x in data.assignments) x.servantId};
            // Class servants not yet given a class (a خادم عام or the
            // admin has none by design).
            final unassigned = [
              for (final sv in data.servants)
                if (sv.role == AppRole.servant && !assigned.contains(sv.id)) sv,
            ];
            final emptyClasses = [
              for (final c in data.classes)
                if (!data.assignments.any((x) => x.classId == c.id)) c,
            ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _AssignmentsSummary(
                  classes: data.classes.length,
                  servants: assigned.length,
                  withoutServant: emptyClasses.length,
                  withoutClass: unassigned.length,
                ),
                if (unassigned.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _UnassignedCard(servants: unassigned),
                ],
                const SizedBox(height: 12),
                for (final (index, schoolClass) in data.classes.indexed) ...[
                  if (index > 0) const SizedBox(height: 12),
                  staggered(
                    index,
                    _ClassAssignmentsCard(
                      schoolClass: schoolClass,
                      accent: classAccent(schoolClass.id),
                      servants: data.assignments
                          .where((item) => item.classId == schoolClass.id)
                          .toList(),
                      onAssign: () => _assign(schoolClass, data),
                      onRemove: _remove,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The picture at a glance: classes, servants placed, and what is missing.
class _AssignmentsSummary extends StatelessWidget {
  const _AssignmentsSummary({
    required this.classes,
    required this.servants,
    required this.withoutServant,
    required this.withoutClass,
  });

  final int classes;
  final int servants;
  final int withoutServant;
  final int withoutClass;

  @override
  Widget build(BuildContext context) {
    Widget cell(int n, String label, IconData icon, Color color) => Expanded(
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                '$n',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.readable(color),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ],
          ),
        );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              cell(classes, AppStrings.totalClasses, Icons.class_outlined,
                  AppColors.olive),
              cell(servants, 'خدام معيّنين',
                  Icons.volunteer_activism_outlined, AppColors.navyLight),
              cell(
                  withoutServant,
                  AppStrings.classesWithoutServant,
                  Icons.person_off_outlined,
                  withoutServant > 0 ? AppColors.warning : AppColors.success),
              cell(
                  withoutClass,
                  AppStrings.servantsWithoutClass,
                  Icons.link_off,
                  withoutClass > 0 ? AppColors.warning : AppColors.success),
            ],
          ),
        ),
      ),
    );
  }
}

/// Class servants who are in no class yet, so the admin sees who is left.
class _UnassignedCard extends StatelessWidget {
  const _UnassignedCard({required this.servants});

  final List<Profile> servants;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.servantsWithoutClassTitle,
      icon: Icons.person_search_outlined,
      accent: AppColors.warning,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final sv in servants)
            Chip(
              avatar: const Icon(Icons.person_outline, size: 16),
              label: Text(sv.fullName),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// One class: its colour, who serves in it, and a clear button to add one.
class _ClassAssignmentsCard extends StatelessWidget {
  const _ClassAssignmentsCard({
    required this.schoolClass,
    required this.accent,
    required this.servants,
    required this.onAssign,
    required this.onRemove,
  });

  final SchoolClass schoolClass;
  final Color accent;
  final List<ClassServant> servants;
  final VoidCallback onAssign;
  final void Function(ClassServant) onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            schoolClass.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (servants.isNotEmpty)
                          Container(
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              AppStrings.servantsCountOf(servants.length),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.readable(accent),
                              ),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: onAssign,
                          icon: const Icon(Icons.person_add_alt, size: 18),
                          label: const Text(AppStrings.assignServant),
                        ),
                      ],
                    ),
                    if (servants.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4, left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                AppStrings.classHasNoServant,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.readable(AppColors.warning),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final a in servants)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: accent.withValues(alpha: 0.16),
                                child: Text(
                                  a.servantName.trim().isEmpty
                                      ? '؟'
                                      : a.servantName.trim().characters.first,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.readable(accent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.servantName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (a.servantEmail != null)
                                      Text(
                                        a.servantEmail!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: AppStrings.removeServant,
                                icon: const Icon(
                                  Icons.link_off,
                                  color: AppColors.danger,
                                  size: 20,
                                ),
                                onPressed: () => onRemove(a),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentsData {
  const _AssignmentsData({
    required this.classes,
    required this.assignments,
    required this.servants,
  });

  final List<SchoolClass> classes;
  final List<ClassServant> assignments;
  final List<Profile> servants;
}

/// The servants who can be given to [className], one tap each. A servant
/// already in another class says so ([currentClass]: id -> class name), as
/// choosing them moves them. Returns the chosen servant's id.
Future<String?> pickServantForClass(
  BuildContext context, {
  required String className,
  required List<Profile> available,
  required Map<String, String> currentClass,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${AppStrings.assignServant} — $className',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          ...available.map(
            (servant) {
              final fromClass = currentClass[servant.id];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(servant.fullName),
                subtitle: fromClass != null
                    ? Text(
                        '${AppStrings.currentClass}: $fromClass',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warningText,
                        ),
                      )
                    : servant.email == null
                        ? null
                        : Text(servant.email!),
                trailing: fromClass != null
                    ? const Icon(Icons.swap_horiz,
                        size: 18, color: AppColors.muted)
                    : null,
                onTap: () => Navigator.of(context).pop(servant.id),
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// The admin adds a servant to one class (the class page's «إضافة خادم»):
/// loads who can be added, asks, assigns. True when one was assigned.
Future<bool> addServantToClass(
  BuildContext context, {
  required String classId,
  required String className,
}) async {
  const classes = ClassRepository();
  const servants = ServantRepository();
  final List<Profile> all;
  final List<ClassServant> assignments;
  try {
    (all, assignments) = await (
      servants.servants(includeInactive: false),
      classes.allAssignments(),
    ).wait;
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
    return false;
  }
  if (!context.mounted) return false;
  final inClass = {
    for (final a in assignments)
      if (a.classId == classId) a.servantId,
  };
  final available = all.where((s) => !inClass.contains(s.id)).toList();
  if (available.isEmpty) {
    Ui.info(context, AppStrings.noServantToAssign);
    return false;
  }
  final currentClass = {
    for (final a in assignments) a.servantId: a.className,
  };
  final servantId = await pickServantForClass(
    context,
    className: className,
    available: available,
    currentClass: currentClass,
  );
  if (servantId == null || !context.mounted) return false;
  return Ui.runGuarded(
    context,
    () => classes.assignServant(classId: classId, servantId: servantId),
    successMessage: currentClass.containsKey(servantId)
        ? AppStrings.servantMoved
        : AppStrings.servantAssigned,
  );
}
