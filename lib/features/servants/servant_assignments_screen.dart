import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
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

    final servantId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${AppStrings.assignServant} — ${target.name}',
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
                            color: AppColors.warning,
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

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: data.classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  staggered(index, Builder(builder: (context) {
                final schoolClass = data.classes[index];
                final servants = data.assignments
                    .where((item) => item.classId == schoolClass.id)
                    .toList();

                return SectionCard(
                  title: schoolClass.name,
                  trailing: IconButton(
                    tooltip: AppStrings.assignServant,
                    icon: const Icon(Icons.person_add_alt, size: 20),
                    onPressed: () => _assign(schoolClass, data),
                  ),
                  child: servants.isEmpty
                      ? const Text(
                          AppStrings.noServants,
                          style:
                              TextStyle(fontSize: 13, color: AppColors.muted),
                        )
                      : Column(
                          children: servants
                              .map(
                                (assignment) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: const Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                  title: Text(
                                    assignment.servantName,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: assignment.servantEmail == null
                                      ? null
                                      : Text(
                                          assignment.servantEmail!,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                  trailing: IconButton(
                                    tooltip: AppStrings.removeServant,
                                    icon: const Icon(
                                      Icons.link_off,
                                      color: AppColors.danger,
                                      size: 20,
                                    ),
                                    onPressed: () => _remove(assignment),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                );
              })),
            );
          },
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
