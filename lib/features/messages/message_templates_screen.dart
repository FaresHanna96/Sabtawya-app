import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/message_template.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/repositories/message_template_repository.dart';

/// أمين الخدمة's message templates: written once, offered to every servant
/// next to the built-in ones when they message the families.
class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  static const _repository = MessageTemplateRepository();
  final _sectionKey = GlobalKey<AsyncSectionState<List<MessageTemplate>>>();

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _edit([MessageTemplate? t]) async {
    final result = await showModalBottomSheet<({String title, String body})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TemplateEditor(template: t),
    );
    if (result == null || !mounted) return;
    final ok = await Ui.runGuarded(
      context,
      () => _repository.save(id: t?.id, title: result.title, body: result.body),
    );
    if (ok) await _reload();
  }

  Future<void> _delete(MessageTemplate t) async {
    final yes = await Ui.confirm(
      context,
      title: AppStrings.deleteTemplate,
      message: AppStrings.confirmDeleteTemplate,
      destructive: true,
    );
    if (!yes || !mounted) return;
    final ok = await Ui.runGuarded(context, () => _repository.delete(t.id!));
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.messageTemplates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.addTemplate),
      ),
      body: AsyncSection<List<MessageTemplate>>(
        key: _sectionKey,
        loading: const SkeletonList(),
        load: _repository.list,
        builder: (context, saved, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            if (saved.isEmpty)
              const EmptyState(
                icon: Icons.chat_outlined,
                title: AppStrings.noTemplates,
                body: AppStrings.noTemplatesBody,
              ),
            for (final t in saved)
              _TemplateCard(
                template: t,
                onEdit: () => _edit(t),
                onDelete: () => _delete(t),
              ),
            const SizedBox(height: 16),
            for (final t in kBuiltInTemplates) _TemplateCard(template: t),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, this.onEdit, this.onDelete});

  final MessageTemplate template;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (template.isBuiltIn)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      AppStrings.builtInTemplate,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                if (onEdit != null)
                  IconButton(
                    tooltip: AppStrings.editTemplate,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: AppStrings.deleteTemplate,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.danger),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                template.body,
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title and text of one template, with taps that insert the placeholders.
class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({this.template});

  final MessageTemplate? template;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.template?.title);
  late final _body = TextEditingController(text: widget.template?.body);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _insert(String tag) {
    final sel = _body.selection;
    final text = _body.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(at, end, tag),
      selection: TextSelection.collapsed(offset: at + tag.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.template == null
                  ? AppStrings.addTemplate
                  : AppStrings.editTemplate,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              maxLength: 80,
              decoration:
                  const InputDecoration(labelText: AppStrings.messageTemplateTitle),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
            ),
            TextFormField(
              controller: _body,
              maxLength: 1000,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: AppStrings.messageText,
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? AppStrings.requiredField : null,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  AppStrings.messageTagsHint,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                for (final tag in kMessageTags)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _insert(tag),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                Navigator.of(context)
                    .pop((title: _title.text, body: _body.text));
              },
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
