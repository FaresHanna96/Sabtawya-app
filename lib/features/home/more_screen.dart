import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_version.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';
import '../profile/my_profile_screen.dart';
import '../settings/settings_screen.dart';
import 'more_counts.dart';
import 'more_entries.dart';
import 'update_check.dart';
import 'whats_new_popup.dart';

/// The hub for everything that does not have its own tab: who you are at the
/// top, a search box, the six places your role uses most (with what is
/// waiting in each), then the rest by group.
///
/// Admin-only entries are hidden for a servant, but the policies are what
/// actually stop the writes: hiding the tile is a convenience, not the control.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key, this.showAppBar = false, this.onUpdateFound});

  final bool showAppBar;

  /// A newer build found by «التحقق من التحديثات», for the shell's banner.
  final ValueChanged<AppUpdate>? onUpdateFound;

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  late Future<Map<MoreCount, int>> _counts = _loadCounts();

  int? _version;
  bool _stale = false;

  Future<Map<MoreCount, int>> _loadCounts() {
    final session = context.read<SessionController>();
    return MoreCounts.load(
      yearId: session.currentYear?.id,
      isAdmin: session.isAdmin,
    );
  }

  static MoreRole _roleOf(SessionController s) => s.isAdmin
      ? MoreRole.admin
      : s.isGeneralServant
          ? MoreRole.generalServant
          : MoreRole.servant;

  bool _checking = false;

  Future<void> _open(MoreEntry entry) async {
    final screen = entry.open;
    if (screen != null) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => screen()),
      );
    }
    if (entry.id == MoreCatalog.updatesId && !_checking) {
      _checking = true; // a second tap waits for the first answer
      try {
        await checkForUpdatesNow(
          context,
          onFound: (u) => widget.onUpdateFound?.call(u),
        );
      } finally {
        _checking = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final failed = context.watch<SyncService>().failedCount;

    // Reload the counts after a change anywhere, but only while on screen:
    // a hidden tab waits until it is opened again.
    final version = session.dataVersion;
    if (_version != null && version != _version) _stale = true;
    _version = version;
    if (_stale && TickerMode.valuesOf(context).enabled) {
      _stale = false;
      _counts = _loadCounts();
    }

    final profile = session.profile;
    final role = _roleOf(session);
    final subtitle = role == MoreRole.servant
        ? session.myClasses.map((c) => c.className).join('، ')
        : session.currentYear?.name;
    final notesBuild = WhatsNewPopup.latestWithNotes();

    final body = FutureBuilder<Map<MoreCount, int>>(
      future: _counts,
      builder: (context, snapshot) => MoreView(
        role: role,
        name: profile?.fullName ?? session.displayName,
        roleLabel: profile?.roleLabel ?? '',
        subtitle: subtitle,
        counts: {
          ...?snapshot.data,
          MoreCount.failedSync: failed,
        },
        version: AppStrings.versionLabel(kAppVersion, kAppBuild),
        onOpen: _open,
        onProfile: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const MyProfileScreen()),
        ),
        onLogout: () => confirmLogout(context),
        onWhatsNew: notesBuild == null
            ? null
            : () => WhatsNewPopup.show(context, build: notesBuild),
      ),
    );

    return Scaffold(
      appBar:
          widget.showAppBar ? AppBar(title: const Text(AppStrings.more)) : null,
      body: SafeArea(
        // Pulling down counts the badges again (absences, preps, ...).
        child: RefreshIndicator(
          onRefresh: () {
            final next = _loadCounts();
            setState(() => _counts = next);
            return next.then<void>((_) {}, onError: (Object _) {});
          },
          child: body,
        ),
      ),
    );
  }
}

/// The page itself, from plain values, so tests need no session or network.
class MoreView extends StatefulWidget {
  const MoreView({
    super.key,
    required this.role,
    required this.name,
    required this.roleLabel,
    required this.counts,
    required this.version,
    required this.onOpen,
    this.subtitle,
    this.onProfile,
    this.onLogout,
    this.onWhatsNew,
  });

  final MoreRole role;
  final String name;
  final String roleLabel;

  /// The servant's classes, or the year for an admin.
  final String? subtitle;
  final Map<MoreCount, int> counts;
  final String version;
  final void Function(MoreEntry entry) onOpen;
  final VoidCallback? onProfile;
  final VoidCallback? onLogout;

  /// Null when no build has notes to show.
  final VoidCallback? onWhatsNew;

  @override
  State<MoreView> createState() => _MoreViewState();
}

class _MoreViewState extends State<MoreView> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _countOf(MoreEntry e) =>
      e.count == null ? 0 : widget.counts[e.count] ?? 0;

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final header = _ProfileHeader(
      name: widget.name,
      roleLabel: widget.roleLabel,
      subtitle: widget.subtitle,
      onTap: widget.onProfile,
      onLogout: widget.onLogout,
    );
    final search = TextField(
      controller: _search,
      onChanged: (v) => setState(() => _query = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: AppStrings.moreSearchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searching
            ? IconButton(
                tooltip: AppStrings.close,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _search.clear();
                  _query = '';
                }),
              )
            : null,
      ),
    );

    return ListView(
      // Pull to refresh the badges, even when the page fits the screen.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        header,
        const SizedBox(height: 12),
        search,
        const SizedBox(height: 16),
        if (searching)
          ..._results()
        else ...[
          ...staggerAll([
            _Grid(
              entries: MoreCatalog.topFor(widget.role),
              countOf: _countOf,
              onOpen: widget.onOpen,
            ),
            for (final (group, rows) in MoreCatalog.groupsFor(widget.role)) ...[
              const SizedBox(height: 16),
              _GroupCard(
                group: group,
                rows: rows,
                countOf: _countOf,
                onOpen: widget.onOpen,
              ),
            ],
          ]),
          const SizedBox(height: 24),
          _Footer(version: widget.version, onWhatsNew: widget.onWhatsNew),
        ],
      ],
    );
  }

  List<Widget> _results() {
    final found = MoreCatalog.search(
      MoreCatalog.entriesFor(widget.role),
      _query,
    );
    if (found.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              AppStrings.moreNoMatches,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      ];
    }
    return [
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Column(
            children: [
              for (final e in found)
                _Row(entry: e, count: _countOf(e), onOpen: widget.onOpen),
            ],
          ),
        ),
      ),
    ];
  }
}

// --------------------------------------------------------------- header

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.roleLabel,
    this.subtitle,
    this.onTap,
    this.onLogout,
  });

  final String name;
  final String roleLabel;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLogout;

  /// The first letter of the first two names: "مينا فايز" -> "م ف".
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p.characters.first).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.navyHeader,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: Text(
                    initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (roleLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              color: AppColors.navyDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      if (sub != null && sub.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
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

// --------------------------------------------------------------- grid

class _Grid extends StatelessWidget {
  const _Grid({
    required this.entries,
    required this.countOf,
    required this.onOpen,
  });

  final List<MoreEntry> entries;
  final int Function(MoreEntry) countOf;
  final void Function(MoreEntry) onOpen;

  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < entries.length; r += _perRow) ...[
          if (r > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = r; i < r + _perRow; i++) ...[
                  if (i > r) const SizedBox(width: 10),
                  Expanded(
                    child: i < entries.length
                        ? _Tile(
                            entry: entries[i],
                            count: countOf(entries[i]),
                            onOpen: onOpen,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.entry, required this.count, required this.onOpen});

  final MoreEntry entry;
  final int count;
  final void Function(MoreEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final color = entry.color;
    return Bounce(
      onTap: () => onOpen(entry),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onOpen(entry),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.18)),
              color: color.withValues(alpha: 0.05),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CountBadge(
                  count: count,
                  color: color,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.4, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Icon(entry.icon, size: 22, color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
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

// --------------------------------------------------------------- groups

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.rows,
    required this.countOf,
    required this.onOpen,
  });

  final MoreGroup group;
  final List<MoreEntry> rows;
  final int Function(MoreEntry) countOf;
  final void Function(MoreEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = MoreCatalog.groupLook(group);
    return SectionCard(
      title: MoreCatalog.groupTitle(group),
      icon: icon,
      accent: accent,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        children: [
          for (final e in rows)
            _Row(entry: e, count: countOf(e), onOpen: onOpen),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.count, required this.onOpen});

  final MoreEntry entry;
  final int count;
  final void Function(MoreEntry) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: entry.color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(entry.icon, color: entry.color, size: 20),
      ),
      title: Text(
        entry.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0) _Pill(count: count, color: entry.color),
          const Icon(AppIcons.forward, color: AppColors.muted),
        ],
      ),
      onTap: () => onOpen(entry),
    );
  }
}

// --------------------------------------------------------------- badges

/// A number on the corner of a tile's icon; nothing at zero.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.color,
    required this.child,
  });

  final int count;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: color,
      textColor: Colors.white,
      offset: const Offset(6, -4),
      child: child,
    );
  }
}

/// The count at the end of a row.
class _Pill extends StatelessWidget {
  const _Pill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: AppColors.readable(color),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- footer

class _Footer extends StatelessWidget {
  const _Footer({required this.version, this.onWhatsNew});

  final String version;
  final VoidCallback? onWhatsNew;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          version,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        if (onWhatsNew != null)
          TextButton.icon(
            onPressed: onWhatsNew,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text(AppStrings.whatsNewTitle),
          ),
      ],
    );
  }
}
