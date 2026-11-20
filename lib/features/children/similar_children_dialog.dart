import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';

/// What the person chose in [showSimilarChildrenDialog].
sealed class SimilarChoice {
  const SimilarChoice();
}

/// Add the child anyway: it is a different child.
class SaveAnyway extends SimilarChoice {
  const SaveAnyway();
}

/// Go back to the form (also when the dialog is dismissed).
class GoBack extends SimilarChoice {
  const GoBack();
}

/// Open the existing child's profile instead.
class OpenExisting extends SimilarChoice {
  const OpenExisting(this.childId);
  final String childId;
}

/// Lists the registered children that look like the one being added and asks
/// what to do. "فتح الملف" shows only for a child whose class the person can
/// see ([canOpen]); for the others the name and class are all there is.
Future<SimilarChoice> showSimilarChildrenDialog(
  BuildContext context,
  List<SimilarChild> matches, {
  required bool Function(String classId) canOpen,
}) async {
  final choice = await showDialog<SimilarChoice>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.content_copy_rounded, color: AppColors.gold),
      title: const Text(AppStrings.similarTitle, style: TextStyle(fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(AppStrings.similarBody, style: TextStyle(height: 1.5)),
            const SizedBox(height: 12),
            for (final m in matches)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(
                    m.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      m.className,
                      AppStrings.similarReason(m.reason),
                      if (!m.isActive) AppStrings.similarInactive,
                    ].join(' • '),
                  ),
                  trailing: canOpen(m.classId)
                      ? TextButton(
                          onPressed: () => Navigator.of(context)
                              .pop(OpenExisting(m.childId)),
                          child: const Text(AppStrings.similarOpen),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const GoBack()),
          child: const Text(AppStrings.similarBack),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(const SaveAnyway()),
          child: const Text(AppStrings.similarSaveAnyway),
        ),
      ],
    ),
  );
  return choice ?? const GoBack();
}
