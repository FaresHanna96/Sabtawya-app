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
  /// The offered numbers of Saturdays in a row; a stored level outside this
  /// range is offered as well, so nothing set before is lost.
  static const _offered = [1, 2, 3, 4, 5, 6, 7, 8];
  static const _maxLevels = 4;

  Set<int> _levels = {2, 3};
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

  Future<void> _fetch() async {
    try {
      final v = await _read();
      if (!mounted) return;
      setState(() {
        _levels = (AbsenceAlertTile.parseLevels(v ?? '2,3') ?? const [2, 3]).toSet();
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

  void _toggle(int n) {
    setState(() {
      if (_levels.contains(n)) {
        _levels = {..._levels}..remove(n);
        _error = null;
      } else if (_levels.length >= _maxLevels) {
        _error = 'اختر حتى $_maxLevels أعداد فقط';
      } else {
        _levels = {..._levels, n};
        _error = null;
      }
    });
  }

  /// "2 و3 سبوت متتالية" for the sentence under the chips.
  String get _summary {
    final sorted = _levels.toList()..sort();
    return sorted.join(' و');
  }

  Future<void> _submit() async {
    if (_levels.isEmpty) {
      setState(() => _error = 'اختر عددًا واحدًا على الأقل');
      return;
    }
    final text = (_levels.toList()..sort()).join(',');
    await Ui.runGuarded(
      context,
      () => _write(text),
      successMessage: AppStrings.saved,
    );
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
                      'اختر بعد كام سبت غياب متتالي يوصل تنبيه لخدام الفصل',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final n in ({..._offered, ..._levels}.toList()..sort()))
                          FilterChip(
                            label: Text(n == 1 ? 'سبت واحد' : '$n سبوت'),
                            selected: _levels.contains(n),
                            onSelected: (_) => _toggle(n),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(_error!,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.danger))
                    else if (_levels.isNotEmpty)
                      Text(
                        'هيوصل تنبيه لما المخدوم يغيب $_summary '
                        '${_levels.length == 1 && _levels.first == 1 ? 'سبت' : 'سبوت'} متتالية.',
                        style: const TextStyle(fontSize: 12.5),
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
