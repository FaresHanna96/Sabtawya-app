import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';

/// The whole announcement, or any entry with no page of its own. The text can
/// be selected (to copy an address or a number out of it).
Future<void> showAnnouncementDialog(
  BuildContext context, {
  required String title,
  required String body,
  required DateTime sentAt,
  IconData icon = Icons.campaign_rounded,
  Color iconColor = AppColors.maroon,
  bool showLabel = true,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(icon, color: iconColor),
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                body,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 12),
              Text(
                showLabel
                    ? '${AppStrings.announcement} • '
                        '${AppDateUtils.sinceLabel(sentAt)}'
                    : AppDateUtils.sinceLabel(sentAt),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
