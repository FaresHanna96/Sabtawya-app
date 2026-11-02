import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../data/models/lesson.dart';
import '../../data/repositories/lesson_repository.dart';

/// أمين الخدمة's editor for one week: the title and page of each grade's
/// lesson, and the pulpit and hymns. Returns true when something was saved.
Future<bool?> showLessonEditor(
  BuildContext context, {
  required DateTime date,
  required LessonSlot slot,
  required List<Lesson> lessons,
  required LessonExtras? extras,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LessonEditor(
      date: date,
      slot: slot,
      lessons: lessons,
      extras: extras,
    ),
  );
}

class _LessonEditor extends StatefulWidget {
  const _LessonEditor({
    required this.date,
    required this.slot,
    required this.lessons,
    required this.extras,
  });

  final DateTime date;
  final LessonSlot slot;
  final List<Lesson> lessons;
  final LessonExtras? extras;

  @override
  State<_LessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<_LessonEditor> {
  static const _repository = LessonRepository();

  final _formKey = GlobalKey<FormState>();
  late final Map<int, TextEditingController> _titles = {
    for (final l in widget.lessons)
      l.grade: TextEditingController(text: l.title),
  };
  late final Map<int, TextEditingController> _pages = {
    for (final l in widget.lessons)
      l.grade: TextEditingController(text: l.page?.toString() ?? ''),
  };
  late final _pulpit = TextEditingController(text: widget.extras?.pulpit);
  late final _hymns = TextEditingController(text: widget.extras?.hymns);

  @override
  void dispose() {
    for (final c in [..._titles.values, ..._pages.values, _pulpit, _hymns]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final ok = await Ui.runGuarded(
      context,
      () async {
        for (final l in widget.lessons) {
          final title = _titles[l.grade]!.text;
          final page = int.tryParse(_pages[l.grade]!.text.trim());
          if (title.trim() == l.title && page == l.page) continue;
          await _repository.updateLesson(
            slot: widget.slot,
            grade: l.grade,
            title: title,
            page: page,
          );
        }
        await _repository.saveExtras(
          slot: widget.slot,
          pulpit: _pulpit.text,
          hymns: _hymns.text,
        );
      },
      successMessage: AppStrings.saved,
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              '${AppStrings.editLesson} • ${widget.slot.label}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              AppDateUtils.formatDayDate(widget.date),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (final l in widget.lessons) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _titles[l.grade],
                      decoration: InputDecoration(
                        labelText:
                            '${AppStrings.lessonTitleLabel} — ${l.grade}',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.classNameRequired
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _pages[l.grade],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: AppStrings.lessonPageLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _pulpit,
              decoration: const InputDecoration(labelText: AppStrings.pulpit),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hymns,
              decoration: const InputDecoration(labelText: AppStrings.hymns),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
