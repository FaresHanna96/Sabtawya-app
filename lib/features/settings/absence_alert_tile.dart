import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_failure.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/supabase/db.dart';

/// Admin only: the numbers of Saturdays in a row at which the servants of a
/// class are alerted that a child is absent ("2,3"). Stored on the server
/// (`absence_alert_levels`); the database checks the format as well.
class AbsenceAlertTile extends StatefulWidget {
  const AbsenceAlertTile({super.key, this.load, this.save});

  /// Replaceable in tests.
  final Future<String?> Function()? load;
  final Future<void> Function(String levels)? save;

  /// Parses "2, 3" or "2،3" into sorted distinct numbers, or null when it is
  /// not one to four whole numbers between 1 and 20.
  static List<int>? parseLevels(String text) {
    final cleaned = text.replaceAll('،', ',').replaceAll(RegExp(r'\s'), '');
    if (cleaned.isEmpty) return null;
    final out = <int>{};
    for (final part in cleaned.split(',')) {
      final n = int.tryParse(part);
      if (n == null || n < 1 || n > 20) return null;
      out.add(n);
    }
    if (out.isEmpty || out.length > 4) return null;
    return out.toList()..sort();
  }

  @override
  State<AbsenceAlertTile> createState() => _AbsenceAlertTileState();
}

class _AbsenceAlertTileState extends State<AbsenceAlertTile> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _failed = false;
  String? _error;

  Future<String?> _read() async {
    if (widget.load != null) return widget.load!();
    try {
      final v = await Db.client
          .rpc('get_app_setting', params: {'p_key': 'absence_alert_levels'});
      return v?.toString();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> _write(String levels) async {
    if (widget.save != null) return widget.save!(levels);
    try {
      await Db.client.rpc('set_app_setting',
          params: {'p_key': 'absence_alert_levels', 'p_value': levels});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final v = await _read();
      if (!mounted) return;
      setState(() {
        _controller.text = v ?? '2,3';
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _submit() async {
    final levels = AbsenceAlertTile.parseLevels(_controller.text);
    if (levels == null) {
      setState(() => _error = AppStrings.absenceAlertLevelsInvalid);
      return;
    }
    setState(() => _error = null);
    final text = levels.join(',');
    final ok = await Ui.runGuarded(
      context,
      () => _write(text),
      successMessage: AppStrings.saved,
    );
    if (ok && mounted) _controller.text = text;
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.absenceAlertSettings,
      icon: Icons.notifications_active_outlined,
      accent: AppColors.coral,
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _failed
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => _loading = true);
                      _fetch();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(AppStrings.retry),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      AppStrings.absenceAlertLevelsHelp,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: AppStrings.absenceAlertLevelsLabel,
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text(AppStrings.save),
                      ),
                    ),
                  ],
                ),
    );
  }
}
