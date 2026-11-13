import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/arabic_sort.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/child.dart';
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
  final _search = TextEditingController();

  /// The tile tapped above the list; null shows everyone.
  _Group? _group;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Profile> _visible(List<Profile> all) {
    final q = ArabicSort.key(_search.text);
    return all.where((p) {
      if (_group != null && !_group!.matches(p)) return false;
      if (q.isEmpty) return true;
      return ArabicSort.key(p.fullName).contains(q) ||
          (p.email ?? '').toLowerCase().contains(q) ||
          (p.mobile ?? '').contains(q);
    }).toList();
  }

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

  List<Widget> _servantCards(_ServantsData data, String? myId) {
    final visible = _visible(data.servants);
    if (visible.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 24),
          child: EmptyState(
            icon: Icons.person_search_outlined,
            title: AppStrings.noData,
          ),
        ),
      ];
    }
    return [
      for (final servant in visible)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ServantCard(
            servant: servant,
            classNames: data.classesOf(servant.id),
            isMe: servant.id == myId,
            details: data.details[servant.id],
            onOpen: () => _openData(data, servant),
            onToggleActive: () => _toggleActive(servant),
            onDelete: () => _deleteServant(servant),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<SessionController>().profile?.id;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.servantsTitle)),
      body: SafeArea(
        child: AsyncSection<_ServantsData>(
          loading: const SkeletonList(),
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
                _Counts(
                  servants: data.servants,
                  selected: _group,
                  onSelected: (g) => setState(() => _group = g),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchServantHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: AppStrings.clearSearch,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._servantCards(data, myId),
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

/// The tiles above the list: how many of each, tappable to show only them.
enum _Group {
  servants,
  general,
  admins,
  inactive;

  bool matches(Profile p) => switch (this) {
        _Group.servants => p.isActive && p.role == AppRole.servant,
        _Group.general => p.isActive && p.role == AppRole.generalServant,
        _Group.admins => p.isActive && p.role == AppRole.admin,
        _Group.inactive => !p.isActive,
      };
}

class _Counts extends StatelessWidget {
  const _Counts({
    required this.servants,
    required this.selected,
    required this.onSelected,
  });

  final List<Profile> servants;
  final _Group? selected;
  final ValueChanged<_Group?> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(_Group g) => servants.where(g.matches).length;
    final tiles = <(_Group?, String, int, Color, IconData)>[
      (
        null,
        AppStrings.allServants,
        servants.length,
        AppColors.navy,
        Icons.groups_rounded
      ),
      (
        _Group.servants,
        AppStrings.servantsShort,
        count(_Group.servants),
        AppColors.olive,
        Icons.volunteer_activism_rounded
      ),
      (
        _Group.general,
        AppStrings.roleGeneralServant,
        count(_Group.general),
        AppColors.sky,
        Icons.diversity_3_rounded
      ),
      (
        _Group.admins,
        AppStrings.adminsShort,
        count(_Group.admins),
        AppColors.maroon,
        Icons.shield_rounded
      ),
      if (count(_Group.inactive) > 0)
        (
          _Group.inactive,
          AppStrings.inactive,
          count(_Group.inactive),
          AppColors.muted,
          Icons.block_rounded
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _CountTile(
              label: tiles[i].$2,
              value: tiles[i].$3,
              color: tiles[i].$4,
              icon: tiles[i].$5,
              selected: selected == tiles[i].$1,
              onTap: () => onSelected(tiles[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $value',
      excludeSemantics: true,
      child: Material(
        color: selected ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : color),
                const SizedBox(height: 2),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Text(
                    '$v',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One servant: initial, name and role, their classes as chips, mobile with
/// a call button. Deactivate and delete sit in a menu, so the list is not a
/// column of red icons.
class _ServantCard extends StatelessWidget {
  const _ServantCard({
    required this.servant,
    required this.classNames,
    required this.isMe,
    required this.details,
    required this.onOpen,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Profile servant;
  final List<String> classNames;
  final bool isMe;
  final ServantDetails? details;
  final VoidCallback onOpen;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  Color get _roleColor => switch (servant.role) {
        AppRole.admin => AppColors.maroon,
        AppRole.generalServant => AppColors.sky,
        AppRole.servant => AppColors.olive,
      };

  @override
  Widget build(BuildContext context) {
    final tint =
        servant.gender == Gender.girl ? AppColors.coral : AppColors.navyLight;
    final mobile = (servant.mobile ?? '').trim();
    final extra = [
      if ((details?.occupation ?? '').trim().isNotEmpty) details!.occupation!,
      if ((details?.confessor ?? '').trim().isNotEmpty) details!.confessor!,
    ];

    return Opacity(
      opacity: servant.isActive ? 1 : 0.65,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: tint.withValues(alpha: 0.14),
                  child: Text(
                    servant.fullName.trim().isEmpty
                        ? '?'
                        : servant.fullName.trim().characters.first,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              servant.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _Pill(text: servant.roleLabel, color: _roleColor),
                          if (!servant.isActive) ...[
                            const SizedBox(width: 4),
                            const StatusBadge(isActive: false),
                          ],
                        ],
                      ),
                      if (classNames.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final c in classNames)
                              _Pill(text: c, color: AppColors.navy),
                          ],
                        ),
                      ],
                      if (servant.email != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          servant.email!,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                      if (mobile.isNotEmpty || extra.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          [if (mobile.isNotEmpty) mobile, ...extra].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (mobile.isNotEmpty)
                  IconButton(
                    tooltip: AppStrings.call,
                    icon: const Icon(Icons.call_rounded, size: 20),
                    color: AppColors.success,
                    onPressed: () =>
                        launchUrl(Uri(scheme: 'tel', path: mobile)),
                  ),
                // Locking yourself out of the app is not a useful option.
                if (!isMe)
                  PopupMenuButton<String>(
                    tooltip: AppStrings.moreActions,
                    icon: const Icon(Icons.more_vert, color: AppColors.muted),
                    onSelected: (v) =>
                        v == 'active' ? onToggleActive() : onDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'active',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            servant.isActive
                                ? Icons.block
                                : Icons.check_circle_outline,
                            color: servant.isActive
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          title: Text(
                            servant.isActive
                                ? AppStrings.deactivateServant
                                : AppStrings.activateServant,
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: AppColors.danger,
                          ),
                          title: Text(
                            AppStrings.deleteServant,
                            style: TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
