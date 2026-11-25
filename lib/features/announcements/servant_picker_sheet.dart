import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_sort.dart';
import '../../data/models/profile.dart';

/// Picks servants by name: a search box over a ticked list. Returns the chosen
/// ids, or null when closed without «تمام».
Future<Set<String>?> showServantPicker(
  BuildContext context, {
  required List<Profile> servants,
  Set<String> selected = const <String>{},
}) =>
    showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ServantPickerSheet(servants: servants, selected: selected),
    );

class ServantPickerSheet extends StatefulWidget {
  const ServantPickerSheet({
    super.key,
    required this.servants,
    this.selected = const <String>{},
  });

  final List<Profile> servants;
  final Set<String> selected;

  @override
  State<ServantPickerSheet> createState() => _ServantPickerSheetState();
}

class _ServantPickerSheetState extends State<ServantPickerSheet> {
  late final Set<String> _picked = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Letter variants match each other, as in the children's search.
    final q = ArabicSort.key(_query);
    final shown = [
      for (final p in widget.servants)
        if (q.isEmpty || ArabicSort.key(p.fullName).contains(q)) p,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: AppStrings.searchServants,
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text(
                          AppStrings.noServantMatch,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final p = shown[i];
                          return CheckboxListTile(
                            value: _picked.contains(p.id),
                            title: Text(p.fullName),
                            subtitle: Text(p.roleLabel),
                            onChanged: (on) => setState(() {
                              on == true
                                  ? _picked.add(p.id)
                                  : _picked.remove(p.id);
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_picked),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    '${AppStrings.peopleDone} • '
                    '${AppStrings.peopleChosen(_picked.length)}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
