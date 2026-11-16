import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/map_location.dart';
import '../../core/utils/ui.dart';
import '../../data/repositories/child_repository.dart';
import 'location_editor.dart';

/// Sets a child's location from their page in one step: the sheet holds the
/// editor and a save button, so there is no need to open the whole form.
/// Returns true when a change was saved.
Future<bool> showLocationSheet(
  BuildContext context, {
  required String childId,
  required MapLocation? current,
  ChildRepository? repository,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LocationSheet(
      childId: childId,
      current: current,
      repository: repository ?? const ChildRepository(),
    ),
  );
  return saved ?? false;
}

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({
    required this.childId,
    required this.current,
    required this.repository,
  });

  final String childId;
  final MapLocation? current;
  final ChildRepository repository;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late MapLocation? _value = widget.current;

  Future<void> _save() async {
    final ok = await Ui.runGuarded(
      context,
      () => widget.repository.setLocation(
        childId: widget.childId,
        latitude: _value?.latitude,
        longitude: _value?.longitude,
      ),
      successMessage: AppStrings.locationSaved,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final changed = _value != widget.current;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocationEditor(
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: changed ? _save : null,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48)),
              child: const Text(AppStrings.locationSave),
            ),
          ],
        ),
      ),
    );
  }
}
