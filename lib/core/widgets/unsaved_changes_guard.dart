import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../utils/ui.dart';

/// Asks "تجاهل التعديلات؟" before leaving a form with unsaved changes (back
/// button, back gesture, app-bar arrow). Saving pops the screen itself with
/// Navigator.pop, which this guard does not block.
///
/// [dirty] is true once the user changed something; forms set it from
/// Form.onChanged (and from any picker that is not a form field).
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });

  final bool dirty;
  final Widget child;

  /// Counts the times someone chose to keep editing, so a tab asked for from
  /// the bottom bar is forgotten.
  static final ValueNotifier<int> kept = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await Ui.confirm(
          context,
          title: AppStrings.unsavedChanges,
          message: AppStrings.unsavedChangesBody,
          confirmLabel: AppStrings.discard,
          destructive: true,
        );
        if (!discard) {
          kept.value++;
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
