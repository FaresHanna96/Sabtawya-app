import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/round_action_button.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';
import 'ask_family.dart';
import 'asked_log.dart';
import 'missing_info.dart';

/// On a child's page: what their record is missing, with a button to ask the
/// family on WhatsApp and one to fill it in. Nothing when the record is
/// complete or the viewer may not edit.
class MissingInfoBanner extends StatefulWidget {
  const MissingInfoBanner({
    super.key,
    required this.child,
    required this.servantName,
    required this.canEdit,
    required this.onEdit,
    this.log,
  });

  final Child child;
  final String servantName;
  final bool canEdit;
  final VoidCallback onEdit;
  final AskedLog? log;

  @override
  State<MissingInfoBanner> createState() => _MissingInfoBannerState();
}

class _MissingInfoBannerState extends State<MissingInfoBanner> {
  DateTime? _asked;

  AskedLog get _log => widget.log ?? AskedLog.instance;

  @override
  void initState() {
    super.initState();
    _loadAsked();
  }

  Future<void> _loadAsked() async {
    final when = await _log.when(widget.child.id);
    if (mounted) setState(() => _asked = when);
  }

  @override
  Widget build(BuildContext context) {
    final missing = MissingInfo.of(widget.child);
    if (!widget.canEdit || missing.isEmpty) return const SizedBox.shrink();
    final canWrite = WhatsApp.numberFor(widget.child) != null;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.rule_rounded, color: AppColors.warning, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.missingOnChild(
                    missing.map((f) => f.label).join('، '),
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                    height: 1.4,
                  ),
                ),
                if (_asked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      AppStrings.askedAlready(
                        AskedLog.daysAgo(_asked, DateTime.now())!,
                      ),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (canWrite) ...[
            const SizedBox(width: 6),
            RoundActionButton(
              tooltip: AppStrings.missingAskFamily,
              color: WhatsAppIcon.green,
              onTap: () async {
                final opened = await askFamilyOnWhatsApp(
                  context,
                  widget.child,
                  servantName: widget.servantName,
                  log: widget.log,
                );
                if (opened) await _loadAsked();
              },
              child: const WhatsAppIcon(size: 26),
            ),
          ],
          const SizedBox(width: 8),
          RoundActionButton(
            tooltip: AppStrings.missingEditChild,
            color: AppColors.navy,
            onTap: widget.onEdit,
            child: const Icon(Icons.edit_outlined,
                size: 22, color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}
