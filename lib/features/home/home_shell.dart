import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../state/session_controller.dart';
import '../attendance/attendance_screen.dart';
import '../children/children_screen.dart';
import '../sync/sync_screen.dart';
import '../classes/classes_screen.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/servant_dashboard_screen.dart';
import '../excel/import_children_screen.dart';
import '../servant_activities/admin_servant_activities_screen.dart';
import '../servant_activities/my_activities_screen.dart';
import '../notifications/notifications_bell.dart';
import 'more_screen.dart';

/// The signed-in shell: five tabs, with the dashboard and the labels adapting
/// to the role. A servant sees "فصولي" where an admin sees "الفصول".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  /// Replayed on every tab change: the new tab fades and settles in instead
  /// of cutting. It starts finished so the first frame is fully visible.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  /// A newer APK on the site (Android), shown as a banner until dismissed.
  AppUpdate? _update;

  @override
  void initState() {
    super.initState();
    UpdateService.check().then((u) {
      if (mounted && u != null) setState(() => _update = u);
    });
  }

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!still) _tabFade.forward(from: 0);
  }

  @override
  void dispose() {
    _tabFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final connectivity = context.watch<ConnectivityService>();
    final sync = context.watch<SyncService>();
    final isAdmin = session.isAdmin;
    final isGeneralServant = session.isGeneralServant;
    final isOnline = connectivity.isOnline;
    final pendingCount = sync.pendingCount;

    final tabs = <_Tab>[
      _Tab(
        label: AppStrings.dashboard,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        child: isAdmin || isGeneralServant
            ? const AdminDashboardScreen()
            : const ServantDashboardScreen(),
      ),
      _Tab(
        label: (isAdmin || isGeneralServant)
            ? AppStrings.classesNav
            : AppStrings.myClasses,
        icon: Icons.class_outlined,
        selectedIcon: Icons.class_,
        child: const ClassesScreen(),
      ),
      const _Tab(
        label: AppStrings.childrenNav,
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups,
        child: ChildrenScreen(),
      ),
      const _Tab(
        label: AppStrings.attendanceNav,
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
        child: AttendanceScreen(),
      ),
      if (!isGeneralServant)
        _Tab(
          label: isAdmin ? AppStrings.activitiesNav : AppStrings.myActivities,
          icon: Icons.volunteer_activism_outlined,
          selectedIcon: Icons.volunteer_activism,
          child: isAdmin
              ? const AdminServantActivitiesScreen(showAppBar: false)
              : const MyActivitiesScreen(),
        ),
      const _Tab(
        label: AppStrings.more,
        icon: Icons.more_horiz_outlined,
        selectedIcon: Icons.more_horiz,
        child: MoreScreen(),
      ),
    ];

    final current = tabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(current.label == AppStrings.dashboard
            ? AppStrings.appTitle
            : current.label),
        actions: [
          const NotificationsBell(),
          if (_index == 2 && isAdmin)
            IconButton(
              tooltip: AppStrings.importChildren,
              icon: const Icon(Icons.upload_file),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const ImportChildrenScreen(),
                ),
              ),
            ),
          IconButton(
            tooltip: AppStrings.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => session.refreshAll(),
          ),
        ],
      ),
      // IndexedStack keeps each tab's scroll position and loaded data, so
      // moving between attendance and the roster does not re-query every time.
      body: Column(
        children: [
          if (_update != null)
            _UpdateBanner(
              update: _update!,
              onDismiss: () => setState(() => _update = null),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            child: (isOnline && pendingCount == 0 && sync.failedCount == 0)
                ? const SizedBox(width: double.infinity)
                : _OfflineBanner(
                    isOnline: isOnline,
                    pendingCount: pendingCount,
                    failedCount: sync.failedCount,
                    syncing: sync.syncing,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncScreen(),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Container(
              decoration:
                  const BoxDecoration(gradient: AppGradients.warmSurface),
              // IndexedStack keeps each tab's state, so it must not be re-keyed.
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _tabFade,
                  curve: Curves.easeOut,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.985, end: 1).animate(
                    CurvedAnimation(
                      parent: _tabFade,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: IndexedStack(
                    index: _index,
                    // Only the tab on screen ticks: a hidden tab's data waits
                    // to reload until it is opened (see AsyncSection).
                    children: [
                      for (final (i, tab) in tabs.indexed)
                        TickerMode(enabled: i == _index, child: tab.child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: [
          for (var i = 0; i < tabs.length; i++)
            NavigationDestination(
              icon: (i == 3 && pendingCount > 0)
                  ? Badge(
                      label: Text('$pendingCount'),
                      child: Icon(tabs[i].icon),
                    )
                  : Icon(tabs[i].icon),
              selectedIcon: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Icon(tabs[i].selectedIcon, color: AppColors.navy),
              ),
              label: tabs[i].label,
            ),
        ],
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({
    required this.isOnline,
    required this.pendingCount,
    required this.failedCount,
    required this.syncing,
    required this.onTap,
  });

  final bool isOnline;
  final int pendingCount;
  final int failedCount;
  final bool syncing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = !isOnline
        ? (pendingCount > 0
            ? '${AppStrings.offlineMode} • ${AppStrings.pendingSyncCount(pendingCount)}'
            : AppStrings.offlineMode)
        : [
            if (pendingCount > 0)
              syncing
                  ? AppStrings.syncingNow
                  : AppStrings.pendingSyncCount(pendingCount),
            if (failedCount > 0) AppStrings.failedSyncCount(failedCount),
          ].join(' • ');
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color:
            (isOnline && failedCount == 0 ? AppColors.sky : AppColors.warning)
                .withValues(alpha: 0.92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(isOnline ? Icons.sync : Icons.cloud_off,
                size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the shell has nothing to display, e.g. a servant with no class.
class HomePlaceholder extends StatelessWidget {
  const HomePlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.class_outlined,
        title: AppStrings.noClassesAssigned,
        body: AppStrings.noClassesAssignedBody,
      );
}

/// "إصدار جديد متاح": "تحديث الآن" downloads this phone's APK inside the app,
/// checks its SHA-256, and opens Android's install screen (the user taps
/// Install once). Anything that goes wrong falls back to the download page.
class _UpdateBanner extends StatefulWidget {
  const _UpdateBanner({required this.update, required this.onDismiss});

  final AppUpdate update;
  final VoidCallback onDismiss;

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  static final _page = Uri.parse('https://sabtawya.vercel.app/apk.html');

  /// Null: waiting for a tap. 0-100: downloading. 101: installer opened.
  int? _progress;
  String? _problem;

  void _openPage() => launchUrl(_page, mode: LaunchMode.externalApplication);

  void _start() {
    final u = widget.update;
    if (!u.canInstallInApp) {
      _openPage();
      return;
    }
    setState(() {
      _progress = 0;
      _problem = null;
    });
    try {
      OtaUpdate()
          .execute(
            u.apkUrl!,
            destinationFilename: 'sabtawya-update.apk',
            sha256checksum: u.sha256,
          )
          .listen(
            _onEvent,
            onError: (Object _) => _fail(AppStrings.updateFailed),
          );
    } catch (_) {
      _fail(AppStrings.updateFailed);
    }
  }

  void _onEvent(OtaEvent e) {
    if (!mounted) return;
    switch (e.status) {
      case OtaStatus.DOWNLOADING:
        setState(() => _progress = int.tryParse(e.value ?? '') ?? _progress);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _progress = 101);
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail(AppStrings.updateNeedsPermission);
      case OtaStatus.CHECKSUM_ERROR:
        _fail(AppStrings.updateBadFile);
      default:
        _fail(AppStrings.updateFailed);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _progress = null;
      _problem = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final String text;
    if (_problem != null) {
      text = _problem!;
    } else if (p == null) {
      text = AppStrings.updateAvailable(widget.update.version);
    } else if (p > 100) {
      text = AppStrings.updateInstalling;
    } else {
      text = AppStrings.updateDownloading(p);
    }

    return Material(
      color: _problem != null ? AppColors.warning : AppColors.olive,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_rounded,
                    size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (p == null)
                  TextButton(
                    onPressed: _problem != null ? _openPage : _start,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.olive,
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      _problem != null
                          ? AppStrings.updateOpenPage
                          : AppStrings.updateNow,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (p == null)
                  IconButton(
                    tooltip: AppStrings.close,
                    icon:
                        const Icon(Icons.close, size: 18, color: Colors.white),
                    onPressed: widget.onDismiss,
                  ),
              ],
            ),
            if (p != null && p <= 100)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 12, 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: p / 100,
                    minHeight: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
