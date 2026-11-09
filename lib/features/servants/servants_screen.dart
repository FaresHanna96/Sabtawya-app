import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/models/school_class.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';
import 'servant_data_screen.dart';
import 'servant_invite_screen.dart';

/// Admin-only servant management: registered accounts and pending invites.
class ServantsScreen extends StatefulWidget {
  const ServantsScreen({super.key});

  @override
  State<ServantsScreen> createState() => _ServantsScreenState();
}

class _ServantsScreenState extends State<ServantsScreen> {
  static const _repository = ServantRepository();
  static const _classes = ClassRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<_ServantsData>>();

  Future<_ServantsData> _load() async => _ServantsData(
        servants: await _repository.servants(),
        invites: await _repository.pendingInvites(),
        assignments: await _classes.allAssignments(),
        details: await _repository.details(),
        classes: await _classes.list(),
      );

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _invite() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const ServantInviteScreen()),
    );
    if (created == true) await _reload();
  }

  Future<void> _openData(_ServantsData data, Profile servant) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ServantDataScreen(
          servant: servant,
          details: data.details[servant.id],
          classes: data.classes,
          assignment: data.assignments
              .where((a) => a.servantId == servant.id)
              .firstOrNull,
        ),
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _toggleActive(Profile servant) async {
    final activating = !servant.isActive;
    final confirmed = await Ui.confirm(
      context,
      title: activating
          ? AppStrings.activateServant
          : AppStrings.deactivateServant,
      message: servant.fullName,
      destructive: !activating,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _repository.setActive(servant.id, activating),
      successMessage: AppStrings.saved,
    );
    if (ok) await _reload();
  }

  Future<void> _deleteServant(Profile servant) async {
    final confirmed = await Ui.confirm(
      context,
      title: '${AppStrings.deleteServant}: ${servant.fullName}',
      message: AppStrings.confirmDeleteServant,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _repository.deleteServant(servant.id),
      successMessage: AppStrings.saved,
    );
    if (ok) await _reload();
  }

  Future<void> _deleteInvite(ServantInvite invite) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.deleteInvite,
      message: invite.email,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final ok = await Ui.runGuarded(
      context,
      () => _repository.deleteInvite(invite.id),
      successMessage: AppStrings.saved,
    );
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<SessionController>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.servantsTitle)),
      body: SafeArea(
        child: AsyncSection<_ServantsData>(
          key: _sectionKey,
          load: _load,
          builder: (context, data, reload) {
            if (data.servants.isEmpty && data.invites.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.volunteer_activism_outlined,
                    title: AppStrings.noServants,
                    body: AppStrings.inviteHint,
                    action: FilledButton.icon(
                      onPressed: _invite,
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text(AppStrings.addServant),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: staggerAll([
                if (data.invites.isNotEmpty) ...[
                  SectionCard(
                    title: AppStrings.pendingInvites,
                    icon: Icons.mail_rounded,
                    accent: AppColors.gold,
                    child: Column(
                      children: data.invites
                          .map(
                            (invite) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: const Icon(
                                Icons.mark_email_unread_outlined,
                                color: AppColors.warning,
                              ),
                              title: Text(
                                invite.fullName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${invite.email}'
                                '${invite.createdAt == null ? '' : ' • ${AppDateUtils.formatDate(invite.createdAt!)}'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                tooltip: AppStrings.deleteInvite,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => _deleteInvite(invite),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SectionCard(
                  title: AppStrings.registeredServants,
                  icon: Icons.groups_rounded,
                  accent: AppColors.olive,
                  child: Column(
                    children: data.servants
                        .map(
                          (servant) => _ServantRow(
                            servant: servant,
                            classNames: data.classesOf(servant.id),
                            isMe: servant.id == myId,
                            details: data.details[servant.id],
                            onOpen: () => _openData(data, servant),
                            onToggleActive: () => _toggleActive(servant),
                            onDelete: () => _deleteServant(servant),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_alt),
        label: const Text(AppStrings.addServant),
      ),
    );
  }
}

class _ServantRow extends StatelessWidget {
  const _ServantRow({
    required this.servant,
    required this.classNames,
    required this.isMe,
    required this.details,
    required this.onOpen,
    required this.onToggleActive,
    required this.onDelete,
  });

  final VoidCallback onDelete;
  final ServantDetails? details;
  final VoidCallback onOpen;
  final Profile servant;
  final List<String> classNames;
  final bool isMe;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      servant.roleLabel,
      if (servant.email != null) servant.email!,
      if (classNames.isNotEmpty) classNames.join('، '),
    ].join(' • ');

    final extra = <String>[
      if (servant.mobile != null) servant.mobile!,
      if (details?.occupation != null) details!.occupation!,
      if (details?.confessor != null) details!.confessor!,
    ].join(' • ');

    return ListTile(
      onTap: onOpen,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (servant.isAdmin ? AppColors.navy : AppColors.olive)
            .withValues(alpha: 0.12),
        child: Icon(
          servant.isAdmin ? Icons.shield_outlined : Icons.person_outline,
          size: 20,
          color: servant.isAdmin ? AppColors.navy : AppColors.olive,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              servant.fullName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          if (!servant.isActive) const StatusBadge(isActive: false),
        ],
      ),
      subtitle: Text(
        extra.isEmpty ? subtitle : '$subtitle\n$extra',
        style: const TextStyle(fontSize: 12),
      ),
      // Locking yourself out of the app is not a useful option.
      trailing: isMe
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: servant.isActive
                      ? AppStrings.deactivateServant
                      : AppStrings.activateServant,
                  icon: Icon(
                    servant.isActive ? Icons.block : Icons.check_circle_outline,
                    color:
                        servant.isActive ? AppColors.danger : AppColors.success,
                  ),
                  onPressed: onToggleActive,
                ),
                IconButton(
                  tooltip: AppStrings.deleteServant,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
    );
  }
}

class _ServantsData {
  const _ServantsData({
    required this.servants,
    required this.invites,
    required this.assignments,
    required this.details,
    required this.classes,
  });

  final List<SchoolClass> classes;
  final Map<String, ServantDetails> details;
  final List<Profile> servants;
  final List<ServantInvite> invites;
  final List<ClassServant> assignments;

  List<String> classesOf(String servantId) => assignments
      .where((item) => item.servantId == servantId)
      .map((item) => item.className)
      .toList();
}
