import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/unsaved_changes_guard.dart';
import '../../data/models/announcement.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/announcement_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import 'servant_picker_sheet.dart';

/// Writes and sends one announcement. Pops with true once it is sent.
///
/// Sending needs a connection: an announcement queued offline would reach
/// people hours later, after it may no longer be true, so it is refused with
/// a clear message instead.
class AnnouncementComposeScreen extends StatefulWidget {
  const AnnouncementComposeScreen({super.key});

  @override
  State<AnnouncementComposeScreen> createState() =>
      _AnnouncementComposeScreenState();
}

class _AnnouncementComposeScreenState extends State<AnnouncementComposeScreen> {
  static const _repository = AnnouncementRepository();
  static const _classesRepo = ClassRepository();

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _audience = AnnouncementAudience.all;
  final _classIds = <String>{};

  /// The servants chosen by name, and the list they come from (loaded the
  /// first time it is needed).
  Set<String> _servantIds = <String>{};
  List<Profile>? _servants;
  bool _dirty = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send(List<SchoolClass> classes) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_audience == AnnouncementAudience.classes && _classIds.isEmpty) {
      Ui.info(context, AppStrings.pickClassesFirst);
      return;
    }
    if (_audience == AnnouncementAudience.people && _servantIds.isEmpty) {
      Ui.info(context, AppStrings.pickPeopleFirst);
      return;
    }
    if (!ConnectivityService.instance.isOnline) {
      Ui.info(context, AppStrings.announcementNeedsConnection);
      return;
    }

    final audience = switch (_audience) {
      AnnouncementAudience.classes => [
          for (final c in classes)
            if (_classIds.contains(c.id)) c.name,
        ].join('، '),
      AnnouncementAudience.people => Announcement.namesSummary([
          for (final p in _servants ?? const <Profile>[])
            if (_servantIds.contains(p.id)) p.fullName,
        ]),
      _ => _audience.label,
    };
    final yes = await Ui.confirm(
      context,
      title: AppStrings.sendAnnouncement,
      message: AppStrings.confirmSendAnnouncement(audience),
      confirmLabel: AppStrings.sendAnnouncement,
    );
    if (!yes || !mounted) return;

    var count = 0;
    final ok = await Ui.runGuarded(context, () async {
      count = await _repository.send(
        title: _title.text,
        body: _body.text,
        audience: _audience,
        classIds: _classIds.toList(),
        servantIds: _servantIds.toList(),
      );
    });
    if (!ok || !mounted) return;
    Ui.success(context, AppStrings.announcementSent(count));
    // The guard reads [_dirty] when it rebuilds, so pop after that frame.
    setState(() => _dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  /// Loads the servants (active, not hidden, not me) and opens the picker.
  Future<void> _pickPeople() async {
    final me = context.read<SessionController>().profile?.id;
    if (_servants == null) {
      final ok = await Ui.runGuarded(context, () async {
        final all =
            await const ServantRepository().servants(includeInactive: false);
        _servants = [
          for (final p in all)
            if (p.id != me) p,
        ];
      });
      if (!ok || !mounted) return;
    }
    final picked = await showServantPicker(
      context,
      servants: _servants!,
      selected: _servantIds,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _servantIds = picked;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      dirty: _dirty,
      child: Scaffold(
        appBar: AppBar(title: const Text(AppStrings.newAnnouncement)),
        body: AsyncSection<List<SchoolClass>>(
          load: () => _classesRepo.list(),
          enableRefresh: false,
          builder: (context, classes, reload) => Form(
            key: _formKey,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: AppStrings.announcementTitleLabel,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppStrings.requiredField
                      : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  maxLength: 2000,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: AppStrings.announcementBodyLabel,
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? AppStrings.requiredField
                      : null,
                ),
                const SizedBox(height: 16),
                const Text(
                  AppStrings.announcementAudience,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in AnnouncementAudience.values)
                      ChoiceChip(
                        label: Text(a.label),
                        selected: _audience == a,
                        onSelected: (_) {
                          setState(() {
                            _audience = a;
                            _dirty = true;
                          });
                          // Nobody chosen yet: go straight to the list.
                          if (a == AnnouncementAudience.people &&
                              _servantIds.isEmpty) {
                            _pickPeople();
                          }
                        },
                      ),
                  ],
                ),
                if (_audience == AnnouncementAudience.classes) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in classes)
                        FilterChip(
                          label: Text(c.name),
                          selected: _classIds.contains(c.id),
                          selectedColor: AppColors.sky.withValues(alpha: 0.2),
                          onSelected: (on) => setState(() {
                            on ? _classIds.add(c.id) : _classIds.remove(c.id);
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                ],
                if (_audience == AnnouncementAudience.people) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _servants ?? const <Profile>[])
                        if (_servantIds.contains(p.id))
                          InputChip(
                            label: Text(p.fullName),
                            onDeleted: () => setState(() {
                              _servantIds = {..._servantIds}..remove(p.id);
                              _dirty = true;
                            }),
                          ),
                      ActionChip(
                        avatar: const Icon(Icons.person_search_rounded,
                            size: 18),
                        label: const Text(AppStrings.pickPeople),
                        onPressed: _pickPeople,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _send(classes),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(AppStrings.sendAnnouncement),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
