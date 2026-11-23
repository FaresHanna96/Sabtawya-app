import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/message_template.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';
import '../../data/repositories/message_template_repository.dart';
import '../../state/session_controller.dart';

/// Messages the families of [children] on WhatsApp, one chat at a time:
/// pick a template (built in, or one أمين الخدمة saved), adjust the text, then
/// open each family's chat with the message ready. Brothers and sisters who
/// share a number get one message naming both. Nothing is sent by the app
/// itself; WhatsApp opens and the servant presses send there.
class ParentMessagesScreen extends StatefulWidget {
  const ParentMessagesScreen({
    super.key,
    required this.children,
    this.classNames = const <String, String>{},
    this.eventTitle,
    this.remainingByChild = const <String, double>{},
    this.preferredTemplate,
    this.launch,
  });

  final List<Child> children;
  final Map<String, String> classNames;

  /// Set when messaging an event's children: offers the event templates.
  final String? eventTitle;
  final Map<String, double> remainingByChild;

  /// The built-in template to start with, by title.
  final String? preferredTemplate;

  /// For tests; opens WhatsApp by default.
  final Future<bool> Function(Uri uri)? launch;

  @override
  State<ParentMessagesScreen> createState() => _ParentMessagesScreenState();
}

class _ParentMessagesScreenState extends State<ParentMessagesScreen> {
  static const _repository = MessageTemplateRepository();

  final _text = TextEditingController();
  List<MessageTemplate> _saved = const <MessageTemplate>[];

  /// The template chip chosen; null for "رسالة جديدة" (or edited text).
  String? _chosen;

  /// Families whose chat was opened (by number).
  final _sent = <String>{};

  bool get _isEvent => widget.eventTitle != null;

  List<MessageTemplate> get _templates => [
        for (final t in kBuiltInTemplates)
          if (_isEvent || !t.eventOnly) t,
        ..._saved,
      ];

  @override
  void initState() {
    super.initState();
    final start = kBuiltInTemplates.firstWhere(
      (t) => t.title == widget.preferredTemplate && (_isEvent || !t.eventOnly),
      orElse: () => kBuiltInTemplates.first,
    );
    _text.text = start.body;
    _chosen = start.title;
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await _repository.list();
      if (mounted) setState(() => _saved = saved);
    } catch (_) {
      // Offline with nothing kept: the built-in templates still work.
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pick(MessageTemplate? t) => setState(() {
        _chosen = t?.title;
        _text.text = t?.body ?? '';
      });

  void _insertTag(String tag) {
    final sel = _text.selection;
    final text = _text.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(at, end, tag);
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: at + tag.length),
    );
    setState(() => _chosen = null);
  }

  ({List<FamilyMessage> families, List<Child> noNumber}) _build(
    String servantName,
  ) =>
      ParentMessages.build(
        widget.children,
        body: _text.text,
        servantName: servantName,
        classNames: widget.classNames,
        eventTitle: widget.eventTitle ?? '',
        remainingByChild: widget.remainingByChild,
      );

  Future<void> _open(FamilyMessage f) async {
    if (_text.text.trim().isEmpty) {
      Ui.info(context, AppStrings.writeMessageFirst);
      return;
    }
    final opened = await (widget.launch ??
        (u) => launchUrl(u, mode: LaunchMode.externalApplication))(f.link);
    if (opened && mounted) setState(() => _sent.add(f.key));
  }

  @override
  Widget build(BuildContext context) {
    final servantName = context.watch<SessionController>().displayName;
    final built = _build(servantName);
    final families = built.families;
    final sentCount = families.where((f) => _sent.contains(f.key)).length;
    final next = families.where((f) => !_sent.contains(f.key)).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.parentMessages)),
      body: widget.children.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: AppStrings.noChildrenToMessage,
              body: '',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Templates.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _templates)
                      ChoiceChip(
                        label: Text(t.title),
                        avatar: t.isBuiltIn
                            ? null
                            : const Icon(Icons.bookmark_rounded, size: 16),
                        selected: _chosen == t.title,
                        onSelected: (_) => _pick(t),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text(AppStrings.newMessage),
                      onPressed: () => _pick(null),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _text,
                  minLines: 4,
                  maxLines: 10,
                  onChanged: (_) => setState(() => _chosen = null),
                  decoration: const InputDecoration(
                    labelText: AppStrings.messageText,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 6),
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
                      if (_isEvent ||
                          (tag != kEventTag && tag != kRemainingTag))
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(tag, style: const TextStyle(fontSize: 12)),
                          onPressed: () => _insertTag(tag),
                        ),
                  ],
                ),
                if (families.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SectionCard(
                    title: AppStrings.messagePreview,
                    icon: Icons.chat_outlined,
                    accent: WhatsAppIcon.green,
                    child: Text(
                      families.first.text,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppStrings.messageFamilies(families.length)} • '
                        '${AppStrings.messagesSent(sentCount, families.length)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (next != null)
                      FilledButton.icon(
                        onPressed: () => _open(next),
                        icon: const WhatsAppIcon(size: 18),
                        label: const Text(AppStrings.openNext),
                      )
                    else if (families.isNotEmpty)
                      const Text(
                        AppStrings.allMessagesSent,
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final f in families)
                  _FamilyTile(
                    family: f,
                    sent: _sent.contains(f.key),
                    onOpen: () => _open(f),
                  ),
                if (built.noNumber.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${AppStrings.familiesNoNumber} (${built.noNumber.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final c in built.noNumber)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        c.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _FamilyTile extends StatelessWidget {
  const _FamilyTile({
    required this.family,
    required this.sent,
    required this.onOpen,
  });

  final FamilyMessage family;
  final bool sent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: sent ? AppColors.success.withValues(alpha: 0.06) : null,
      child: ListTile(
        title: Text(
          family.children.map((c) => c.fullName).join('، '),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '+${family.number}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: sent
            ? IconButton(
                tooltip: AppStrings.messageSentAgain,
                onPressed: onOpen,
                icon: const Icon(Icons.check_circle_rounded,
                    color: AppColors.success),
              )
            : IconButton(
                tooltip: AppStrings.whatsapp,
                onPressed: onOpen,
                icon: const WhatsAppIcon(size: 26),
              ),
      ),
    );
  }
}
