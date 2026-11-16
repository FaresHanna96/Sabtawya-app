import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_entries.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/child.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/services/file_service.dart';

typedef _Data = ({List<Child> children, List<SchoolClass> classes});

/// Downloads the families' numbers as a contacts file (`.vcf`). Opened on a
/// phone it adds them to the contacts, so a call from a parent shows
/// "أم مينا جورج – فصل 5 بنات" even if the servant never saved the number.
/// Opened from a class page it holds that class's families; with no class it
/// covers everyone the signed-in servant may read (the database already limits
/// a servant to their own classes) and offers a class picker.
class ContactsExportScreen extends StatefulWidget {
  const ContactsExportScreen({super.key, this.classId});

  /// The class page it was opened from, or null for every class.
  final String? classId;

  @override
  State<ContactsExportScreen> createState() => _ContactsExportScreenState();
}

class _ContactsExportScreenState extends State<ContactsExportScreen> {
  static const _children = ChildRepository();
  static const _classes = ClassRepository();

  bool _mothers = true;
  bool _fathers = true;
  bool _kids = true;
  late String? _classId = widget.classId;

  Future<_Data> _load() async {
    final (children, classes) =
        await (_children.all(classId: widget.classId), _classes.list()).wait;
    return (children: children, classes: classes);
  }

  List<ContactCard> _entries(_Data data) => contactCardsFor(
        data.children
            .where((c) => _classId == null || c.classId == _classId)
            .toList(),
        {for (final c in data.classes) c.id: c.name},
        mother: _mothers,
        father: _fathers,
        child: _kids,
      );

  Future<void> _download(List<ContactCard> entries) async {
    await Ui.runGuarded(
      context,
      () => FileService.saveAndShareVCard(
        fileName: '${AppStrings.contactsFileName}.vcf',
        text: buildVCards(entries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.contactsExportTitle)),
      body: SafeArea(
        child: AsyncSection<_Data>(
          load: _load,
          builder: (context, data, reload) {
            final entries = _entries(data);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                const Text(
                  AppStrings.contactsExportBody,
                  style: TextStyle(height: 1.6, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: AppStrings.contactsExportWho,
                  icon: Icons.contact_phone_rounded,
                  accent: AppColors.olive,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text(AppStrings.contactsMothers),
                            selected: _mothers,
                            onSelected: (v) => setState(() => _mothers = v),
                          ),
                          FilterChip(
                            label: const Text(AppStrings.contactsFathers),
                            selected: _fathers,
                            onSelected: (v) => setState(() => _fathers = v),
                          ),
                          FilterChip(
                            label: const Text(AppStrings.contactsChildren),
                            selected: _kids,
                            onSelected: (v) => setState(() => _kids = v),
                          ),
                        ],
                      ),
                      if (widget.classId == null && data.classes.length > 1) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _classId,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: AppStrings.classLabel,
                            prefixIcon: Icon(Icons.class_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(AppStrings.allClasses),
                            ),
                            for (final c in data.classes)
                              DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: (v) => setState(() => _classId = v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  entries.isEmpty
                      ? AppStrings.contactsNone
                      : AppStrings.contactsCount(entries.length),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: entries.isEmpty ? null : () => _download(entries),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(AppStrings.contactsDownload),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppStrings.contactsPrivacy,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
