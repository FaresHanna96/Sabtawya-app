import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../../state/session_controller.dart';
import '../theme/app_theme.dart';
import 'app_failure.dart';

/// Snackbars, confirmations, and the "run this and report the outcome" helper
/// that every mutating action in the app funnels through.
class Ui {
  const Ui._();

  static void success(BuildContext context, String message) =>
      _show(context, message, AppColors.success, Icons.check_circle_outline);

  static void error(BuildContext context, Object error) => _show(
        context,
        AppFailure.from(error).message,
        AppColors.danger,
        Icons.error_outline,
      );

  static void info(BuildContext context, String message) =>
      _show(context, message, AppColors.navy, Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = AppStrings.confirm,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: message == null ? null : Text(message, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Runs [action] behind a modal barrier, then reports success or failure.
  /// Returns true only when [action] completed without throwing.
  static Future<bool> runGuarded(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await action();
      navigator.pop();
      if (context.mounted) {
        try {
          context.read<SessionController>().markChanged();
        } catch (_) {}
      }
      if (successMessage != null && context.mounted) {
        success(context, successMessage);
      }
      return true;
    } catch (e) {
      navigator.pop();
      if (context.mounted) error(context, e);
      return false;
    }
  }
}
