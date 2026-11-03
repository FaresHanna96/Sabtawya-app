import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/sync_service.dart';
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
import '../servants/pending_requests_bell.dart';
import 'more_screen.dart';

/// The signed-in shell: five tabs, with the dashboard and the labels adapting
/// to the role. A servant sees "فصولي" where an admin sees "الفصول".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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
              ? const AdminServantActivitiesScreen()
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
          if (isAdmin) const PendingRequestsBell(),
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
              child: IndexedStack(
                index: _index,
                children: tabs.map((tab) => tab.child).toList(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
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
