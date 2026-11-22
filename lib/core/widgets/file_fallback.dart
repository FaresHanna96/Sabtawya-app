import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Shown where a stored picture cannot be drawn: most often a PDF that was
/// saved under a picture's name. A tap opens the file in the browser (or the
/// phone's PDF app), so it can still be read instead of showing an error.
class FileFallbackCard extends StatelessWidget {
  const FileFallbackCard({
    super.key,
    required this.url,
    this.width,
    this.height,
  });

  final String? url;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final link = url;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: link == null
              ? null
              : () => launchUrl(
                    Uri.parse(link),
                    mode: LaunchMode.externalApplication,
                  ),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insert_drive_file_outlined,
                    color: AppColors.danger, size: 28),
                SizedBox(height: 4),
                Text(
                  AppStrings.openFile,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
