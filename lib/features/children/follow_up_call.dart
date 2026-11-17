import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../data/models/child.dart';
import '../../data/repositories/child_repository.dart';

/// Asks how the child was followed up (phone or home) and writes it down the
/// same way the child's profile does: the last visit on the child, plus an
/// entry in the visit history. Returns true when something was saved.
///
/// [child] is loaded when not given. [absentStreak] only words the note.
Future<bool> logFollowUp(
  BuildContext context, {
  required String childId,
  required String childName,
  int? absentStreak,
  Child? child,
}) async {
  const children = ChildRepository();
  final type = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${AppStrings.followUpHow} $childName',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.call_rounded, color: AppColors.success),
            title: const Text(AppStrings.followUpPhone),
            onTap: () => Navigator.of(sheet).pop('phone'),
          ),
          ListTile(
            leading: const Icon(Icons.home_rounded, color: AppColors.navy),
            title: const Text(AppStrings.followUpHome),
            onTap: () => Navigator.of(sheet).pop('home'),
          ),
        ],
      ),
    ),
  );
  if (type == null || !context.mounted) return false;
  final today = AppDateUtils.dateOnly(DateTime.now());
  final note = absentStreak == null
      ? AppStrings.followUpNoteGeneric
      : AppStrings.followUpNote(absentStreak);
  return Ui.runGuarded(
    context,
    () async {
      final current = child ?? await children.byId(childId);
      if (current != null) {
        await children.update(current.withVisits(
          phoneVisitDate: type == 'phone' ? today : current.lastPhoneVisitDate,
          phoneVisitNotes: type == 'phone' ? note : current.lastPhoneVisitNotes,
          homeVisitDate: type == 'home' ? today : current.lastHomeVisitDate,
          homeVisitNotes: type == 'home' ? note : current.lastHomeVisitNotes,
        ));
      }
      await children.recordVisitLog(
        childId: childId,
        visitType: type,
        visitDate: today,
        notes: note,
      );
    },
    successMessage: AppStrings.saved,
  );
}
