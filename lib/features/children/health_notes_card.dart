import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';

/// Whether the signed-in person may see and edit a child's private health
/// notes: an admin, or a servant of the child's class. The general servant
/// reads every child but never these. The database enforces the same rule;
/// this only decides whether to show the card.
bool canSeeHealthNotes(SessionController session, String classId) =>
    healthNotesVisible(
      isAdmin: session.isAdmin,
      isGeneralServant: session.isGeneralServant,
      myClassIds: session.myClasses.map((c) => c.classId),
      classId: classId,
    );

/// The rule itself, on plain values so it can be tested without a session.
bool healthNotesVisible({
  required bool isAdmin,
  required bool isGeneralServant,
  required Iterable<String> myClassIds,
  required String classId,
}) {
  if (isGeneralServant) return false;
  return isAdmin || myClassIds.contains(classId);
}

/// The private health / special-needs note of one child. Loads and saves on its
/// own (the note is not part of the child row, so it never travels with the
/// general servant's reads).
class HealthNotesCard extends StatefulWidget {
  const HealthNotesCard({
    super.key,
    required this.childId,
    this.load,
    this.save,
  });

  final String childId;

  /// Replaceable in tests; default to the repository.
  final Future<String?> Function(String childId)? load;
  final Future<void> Function(String childId, String? text)? save;

  @override
  State<HealthNotesCard> createState() => _HealthNotesCardState();
}

class _HealthNotesCardState extends State<HealthNotesCard> {
  static const _repository = ChildRepository();

  final _controller = TextEditingController();
  bool _loading = true;
  bool _failed = false;
  bool _editing = false;
  String? _saved;

  Future<String?> _read() =>
      (widget.load ?? _repository.healthNote)(widget.childId);

  Future<void> _write(String? text) =>
      (widget.save ?? _repository.saveHealthNote)(widget.childId, text);

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
      final text = await _read();
      if (!mounted) return;
      setState(() {
        _saved = text;
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

  void _startEditing() {
    _controller.text = _saved ?? '';
    setState(() => _editing = true);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    final ok = await Ui.runGuarded(
      context,
      () => _write(text),
      successMessage: AppStrings.healthNotesSaved,
    );
    if (!ok || !mounted) return;
    setState(() {
      _saved = text.isEmpty ? null : text;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AppStrings.healthNotesTitle,
      icon: Icons.health_and_safety_outlined,
      accent: AppColors.danger,
      trailing: _loading || _failed || _editing
          ? null
          : IconButton(
              tooltip: AppStrings.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _startEditing,
            ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_failed) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () {
            setState(() => _loading = true);
            _fetch();
          },
          icon: const Icon(Icons.refresh),
          label: const Text(AppStrings.retry),
        ),
      );
    }
    if (_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 8,
            autofocus: true,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: AppStrings.healthNotesHint,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text(AppStrings.cancel),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: const Text(AppStrings.save),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _saved ?? AppStrings.healthNotesEmpty,
          style: TextStyle(
            color: _saved == null ? AppColors.muted : null,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.healthNotesPrivate,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
