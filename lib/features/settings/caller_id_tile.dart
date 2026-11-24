import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../data/services/caller_id_service.dart';
import 'settings_screen.dart';

/// The "show caller name" switch row. Hidden on the website, where it cannot
/// work.
class CallerIdTile extends StatefulWidget {
  const CallerIdTile({super.key});

  @override
  State<CallerIdTile> createState() => _CallerIdTileState();
}

class _CallerIdTileState extends State<CallerIdTile> {
  bool _on = false;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    CallerIdService.isEnabled().then((v) {
      if (!mounted) return;
      setState(() {
        _on = v;
        _busy = false;
      });
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    var now = false;
    if (value) {
      now = await CallerIdService.enable();
      if (!now && mounted) Ui.info(context, AppStrings.callerIdDenied);
    } else {
      await CallerIdService.disable(byUser: true);
    }
    if (mounted) {
      setState(() {
        _on = now;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Where it cannot work (the website) the row stays, switched off, with
    // the reason, so the setting is always findable.
    final supported = CallerIdService.supported;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SettingsIcon(Icons.phone_callback_rounded, AppColors.coral),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  AppStrings.callerIdSwitch,
                  style: TextStyle(fontSize: 14.5),
                ),
              ),
              Switch(
                value: supported && _on,
                onChanged: supported && !_busy ? _toggle : null,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 46, bottom: 4),
            child: Text(
              supported
                  ? AppStrings.callerIdBody
                  : 'متاح في تطبيق الأندرويد بس، مش في الموقع.',
              style: const TextStyle(
                  fontSize: 12, height: 1.6, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
