import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/access_log.dart';
import '../../core/config/app_version.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/push_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/responsive.dart';
import '../../data/models/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/services/caller_id_service.dart';
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
import '../notifications/notification_router.dart';
import '../notifications/notifications_bell.dart';
import '../notifications/notifications_screen.dart';
import '../search/app_search.dart';
import 'app_nav_bar.dart';
import 'more_screen.dart';
import 'shell_frame.dart';
import 'welcome_tour.dart';
import 'whats_new_popup.dart';

/// The signed-in shell: five tabs, with the dashboard and the labels adapting
/// to the role. A servant sees "فصولي" where an admin sees "الفصول".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;

  /// The navigator every page opens in, above the bottom bar.
  final _pages = GlobalKey<NavigatorState>();

  /// On the tabs' page: what opens a page from the shell starts from here.
  final _homeKey = GlobalKey();

  /// Tabs opened so far. The others are not built yet, so opening the app
  /// loads the home only, not every tab's data at once.
  final Set<int> _opened = {0};

  /// Replayed on every tab change: the new tab fades and settles in instead
  /// of cutting. It starts finished so the first frame is fully visible.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  /// A newer APK on the site (Android), shown as a banner until dismissed.
  AppUpdate? _update;

  /// The saves waiting to be sent at the last look, and a moment of
  /// «اتزامن كل حاجة» once they have all gone.
  SyncService? _sync;
  int _lastPending = 0;
  bool _justSynced = false;
  Timer? _syncedTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = context.read<SyncService>();
    if (!identical(sync, _sync)) {
      _sync?.removeListener(_onSync);
      _sync = sync..addListener(_onSync);
      _lastPending = sync.pendingCount;
    }
  }

  void _onSync() {
    final sync = _sync;
    if (sync == null || !mounted) return;
    final now = sync.pendingCount;
    if (syncJustFinished(
      before: _lastPending,
      after: now,
      failed: sync.failedCount,
      online: ConnectivityService.instance.isOnline,
    )) {
      setState(() => _justSynced = true);
      _syncedTimer?.cancel();
      _syncedTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _justSynced = false);
      });
    } else if (now > 0 && _justSynced) {
      // New saves queued meanwhile: the usual banner takes over.
      _syncedTimer?.cancel();
      setState(() => _justSynced = false);
    }
    _lastPending = now;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
    PushService.instance.tapped.addListener(_openTapped);
    UpdateService.found.addListener(_onUpdateFound);
    // The tap that started the app is already waiting.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTapped());
  }

  void _onUpdateFound() {
    final update = UpdateService.found.value;
    if (mounted && update != null) setState(() => _update = update);
  }

  /// Opens what a tapped notification is about. When its entry cannot be read
  /// (offline, deleted), the bell's list opens instead.
  Future<void> _openTapped() async {
    final tap = PushService.instance.tapped.value;
    if (tap == null || !mounted || (_update?.forced ?? false)) return;
    PushService.instance.tapped.value = null;

    AppNotification? entry;
    final id = tap.notificationId;
    if (id != null) {
      const repository = NotificationRepository();
      try {
        entry = await repository.byId(id);
        if (entry != null && !entry.isRead) await repository.markRead(id);
      } catch (_) {}
    } else if (tap.kind != null) {
      entry = AppNotification(
        id: '',
        kind: tap.kind!,
        title: tap.title,
        body: tap.body,
        refId: tap.refId,
        createdAt: DateTime.now(),
      );
    }
    final home = _homeKey.currentContext;
    if (home == null || !home.mounted) return;
    if (entry == null) {
      await Navigator.of(home).push<void>(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      );
    } else {
      await openNotification(home, entry);
    }
    // The bell's count, after one more entry was read.
    PushService.instance.received.value++;
  }

  /// One thing at a time on opening: the welcome tour once on this phone
  /// (it then stands in for this update's "what's new"), otherwise the
  /// release notes; then the caller-name question.
  Future<void> _welcome() async {
    if (!mounted) return;
    final toured = await WelcomeTour.maybeShow(context);
    if (toured) {
      await WhatsNewStore.instance.markSeen(kAppBuild);
    } else if (mounted) {
      await WhatsNewPopup.maybeShow(context);
    }
    if (mounted) await _callerName();
  }

  /// "Caller name" is on by default on Android: keeps its list current, and
  /// the first time explains it and asks the phone's permission. Never again
  /// once answered, and never after the servant switched it off in Settings.
  Future<void> _callerName() async {
    await CallerIdService.start();
    if (!await CallerIdService.needsPrompt()) return;
    await CallerIdService.markPrompted();
    if (!mounted) return;
    final yes = await Ui.confirm(
      context,
      title: AppStrings.callerIdTitle,
      message: AppStrings.callerIdAsk,
      confirmLabel: AppStrings.callerIdAllow,
    );
    if (yes) await CallerIdService.enable();
  }

  void _checkUpdate() {
    UpdateService.check().then((u) {
      if (mounted && u != null) setState(() => _update = u);
    });
  }

  /// A phone that stays open in the background still gets the forced screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkUpdate();
  }

  /// The attendance tab's place in the bottom bar (the same for every role).
  static const _attendanceTab = 3;

  void _selectTab(int index) {
    if (index == _index) return;
    Haptics.select();
    // A snack bar belongs to the tab that showed it, not the next one.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (_index == _attendanceTab && AttendanceScreen.unsavedInTab.value) {
      messenger.showSnackBar(
        unsavedAttendanceSnackBar(onBack: () => _selectTab(_attendanceTab)),
      );
    }
    setState(() {
      _index = index;
      _opened.add(index);
    });
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!still) _tabFade.forward(from: 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushService.instance.tapped.removeListener(_openTapped);
    UpdateService.found.removeListener(_onUpdateFound);
    _sync?.removeListener(_onSync);
    _syncedTimer?.cancel();
    _tabFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_update?.forced ?? false) return ForcedUpdateScreen(update: _update!);
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
        selectedIcon: Icons.home_rounded,
        color: AppColors.navy,
        motion: _TabMotion.bounce,
        child: isAdmin || isGeneralServant
            ? const AdminDashboardScreen()
            : const ServantDashboardScreen(),
      ),
      _Tab(
        label: (isAdmin || isGeneralServant)
            ? AppStrings.classesNav
            : AppStrings.myClasses,
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        color: AppColors.gold,
        motion: _TabMotion.swing,
        child: const ClassesScreen(),
      ),
      const _Tab(
        label: AppStrings.childrenNav,
        icon: Icons.diversity_3_outlined,
        selectedIcon: Icons.diversity_3,
        color: AppColors.sky,
        motion: _TabMotion.pop,
        child: ChildrenScreen(),
      ),
      const _Tab(
        label: AppStrings.attendanceNav,
        icon: Icons.how_to_reg_outlined,
        selectedIcon: Icons.how_to_reg,
        color: AppColors.success,
        motion: _TabMotion.tick,
        child: AttendanceScreen(),
      ),
      if (!isGeneralServant)
        _Tab(
          label: isAdmin ? AppStrings.activitiesNav : AppStrings.myActivities,
          icon: Icons.supervisor_account_outlined,
          selectedIcon: Icons.supervisor_account,
          color: AppColors.coral,
          motion: _TabMotion.pulse,
          child: isAdmin
              ? const AdminServantActivitiesScreen(showAppBar: false)
              : const MyActivitiesScreen(),
        ),
      _Tab(
        label: AppStrings.more,
        icon: Icons.apps_outlined,
        selectedIcon: Icons.apps,
        color: AppColors.olive,
        motion: _TabMotion.spin,
        // Brings the banner back even if it was closed (or the forced screen).
        child: MoreScreen(onUpdateFound: (u) => setState(() => _update = u)),
      ),
    ];

    final current = tabs[_index];
    // A laptop or desktop browser: a side menu instead of the bottom bar, and
    // each tab centred at a readable width (the home lays out two columns).
    final wide = isWideLayout(context);

    Widget tabIcon(int i) => i != _attendanceTab
        ? Icon(tabs[i].icon, color: tabs[i].color.withValues(alpha: 0.8))
        : ValueListenableBuilder<bool>(
            valueListenable: AttendanceScreen.unsavedInTab,
            builder: (_, unsaved, __) => AttendanceTabIcon(
              icon: tabs[i].icon,
              color: tabs[i].color.withValues(alpha: 0.8),
              pendingCount: pendingCount,
              unsaved: unsaved,
            ),
          );

    Widget selectedTabIcon(int i) => _AnimatedTabIcon(
          icon: tabs[i].selectedIcon,
          color: tabs[i].color,
          motion: tabs[i].motion,
        );

    Widget tabBody(int i, Widget child) => wide
        ? MaxWidthBox(
            maxWidth: i == 0 ? kHomeMaxWidth : kTabMaxWidth,
            child: child,
          )
        : child;

    // The side menu sits at the start (the right, in Arabic), where the eye
    // starts reading.
    Widget sideMenu(ValueChanged<int> select) => NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: select,
          extended: MediaQuery.sizeOf(context).width >= kExtendedRailBreakpoint,
          minExtendedWidth: 200,
          labelType: MediaQuery.sizeOf(context).width >= kExtendedRailBreakpoint
              ? NavigationRailLabelType.none
              : NavigationRailLabelType.all,
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.oliveLight.withValues(alpha: 0.35),
          destinations: [
            for (var i = 0; i < tabs.length; i++)
              NavigationRailDestination(
                icon: tabIcon(i),
                selectedIcon: selectedTabIcon(i),
                label: Text(tabs[i].label),
              ),
          ],
        );

    Widget bottomBar(ValueChanged<int> select) => AppNavBar(
          selectedIndex: _index,
          onSelected: select,
          items: [
            for (var i = 0; i < tabs.length; i++)
              AppNavItem(
                label: tabs[i].label,
                color: tabs[i].color,
                icon: tabIcon(i),
                selectedIcon: selectedTabIcon(i),
              ),
          ],
        );

    // Its own context sits inside the pages' navigator, so what it opens
    // keeps the bar.
    final home = Builder(
        builder: (context) => Scaffold(
              key: _homeKey,
              appBar: AppBar(
                title: Text(current.label == AppStrings.dashboard
                    ? AppStrings.appTitle
                    : current.label),
                actions: [
                  IconButton(
                    tooltip: AppStrings.search,
                    icon: const Icon(Icons.search),
                    onPressed: () => showSearch<void>(
                      context: context,
                      delegate: AppSearchDelegate(
                        classes: session.myClasses,
                        isAdmin: session.isAdmin,
                      ),
                    ),
                  ),
                  const NotificationsBell(),
                  // A class servant may import into their own class too (the import
                  // screen offers only their classes; the policies enforce it).
                  if (_index == 2 && !isGeneralServant)
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
                    // The profile and classes, then the screen itself: the tab on
                    // view reloads now, the others when next opened.
                    onPressed: () async {
                      await session.refreshAll();
                      session.markChanged();
                    },
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
                    child:
                        (isOnline && pendingCount == 0 && sync.failedCount == 0)
                            ? (_justSynced
                                ? const SyncedBanner()
                                : const SizedBox(width: double.infinity))
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
                      decoration: const BoxDecoration(
                          gradient: AppGradients.warmSurface),
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
                                _opened.contains(i)
                                    ? TickerMode(
                                        enabled: i == _index,
                                        // A hidden tab's heroes must not fly in from
                                        // where nobody can see them.
                                        child: HeroMode(
                                          enabled: i == _index,
                                          child: tabBody(i, tab.child),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ));

    return ShellFrame(
      navigatorKey: _pages,
      home: home,
      onSelect: _selectTab,
      bottomBar: wide ? null : bottomBar,
      sideMenu: wide ? sideMenu : null,
    );
  }
}

/// Shown on leaving the attendance tab with marks not saved yet. It goes by
/// itself (a snack bar with an action would otherwise stay until tapped).
SnackBar unsavedAttendanceSnackBar({required VoidCallback onBack}) => SnackBar(
      content: const Text(AppStrings.attendanceNotSaved),
      persist: false,
      action: SnackBarAction(
        label: AppStrings.backToAttendance,
        onPressed: onBack,
      ),
    );

/// The attendance tab's icon: the number of saves waiting to be sent, or a
/// dot while marks taken on it are not saved yet.
class AttendanceTabIcon extends StatelessWidget {
  const AttendanceTabIcon({
    super.key,
    required this.icon,
    this.color,
    required this.pendingCount,
    required this.unsaved,
  });

  final IconData icon;
  final Color? color;
  final int pendingCount;
  final bool unsaved;

  @override
  Widget build(BuildContext context) {
    if (pendingCount > 0) {
      // A save queued offline makes the count pop once.
      return PopOnIncrease(
        value: pendingCount,
        child: Badge(
          label: AnimatedCount(value: pendingCount),
          child: Icon(icon, color: color),
        ),
      );
    }
    return Badge(
      isLabelVisible: unsaved,
      backgroundColor: AppColors.warning,
      smallSize: 9,
      child: Icon(icon, color: color),
    );
  }
}

class _Tab {
  const _Tab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.motion,
    required this.child,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
  final _TabMotion motion;
  final Widget child;
}

/// How a tab's icon plays when its tab is selected.
enum _TabMotion { bounce, swing, pop, tick, pulse, spin }

class _AnimatedTabIcon extends StatelessWidget {
  const _AnimatedTabIcon({
    required this.icon,
    required this.color,
    required this.motion,
  });

  final IconData icon;
  final Color color;
  final _TabMotion motion;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, color: color);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      builder: (_, t, __) {
        final decay = 1 - t;
        switch (motion) {
          case _TabMotion.bounce:
            return Transform.translate(
              offset: Offset(0, -10 * math.sin(t * math.pi * 3) * decay),
              child: child,
            );
          case _TabMotion.swing:
            return Transform.rotate(
              angle: 0.5 * math.sin(t * math.pi * 4) * decay,
              alignment: Alignment.topCenter,
              child: child,
            );
          case _TabMotion.pop:
            return Transform.scale(
              scale: Curves.elasticOut.transform(t) * 0.5 + 0.5,
              child: child,
            );
          case _TabMotion.tick:
            return Transform.rotate(
              angle: -0.35 * math.sin(t * math.pi * 3) * decay,
              child: Transform.scale(
                  scale: 1 + 0.25 * math.sin(t * math.pi), child: child),
            );
          case _TabMotion.pulse:
            return Transform.scale(
              scale: 1 + 0.3 * math.sin(t * math.pi * 2) * decay,
              child: child,
            );
          case _TabMotion.spin:
            return Transform.rotate(
              angle: Curves.easeOutBack.transform(t) * math.pi * 2,
              child: child,
            );
        }
      },
    );
  }
}

/// The saves waiting to be sent have all gone: online, none refused.
@visibleForTesting
bool syncJustFinished({
  required int before,
  required int after,
  required int failed,
  required bool online,
}) =>
    before > 0 && after == 0 && failed == 0 && online;

/// «اتزامن كل حاجة ✓» for a moment, where the offline banner was.
@visibleForTesting
class SyncedBanner extends StatelessWidget {
  const SyncedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.success.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_rounded, size: 16, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.syncedAll,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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

/// Replaces the real download in tests.
@visibleForTesting
Stream<OtaEvent> Function(AppUpdate)? debugOtaStarter;

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

/// Downloads and installs the APK from inside the app; shared by the
/// dismissible banner and the blocking screen.
mixin _InstallLogic<T extends StatefulWidget> on State<T> {
  static final _page = Uri.parse('https://sabtawya.vercel.app/apk.html');

  AppUpdate get update;

  /// Null: waiting for a tap. 0-100: downloading. 101: installer opened.
  int? _progress;
  String? _problem;

  /// True when the problem can be fixed by trying again (not by the web page).
  bool _canRetry = false;

  StreamSubscription<OtaEvent>? _events;
  Timer? _installerTimer;

  /// How long the installer may stay open before the screen offers a retry:
  /// cancelling Android's install prompt tells the app nothing.
  static const _installerWait = Duration(seconds: 45);

  /// What the button does: try again when that can help, else the web page.
  void _onButton() => _problem != null && !_canRetry ? _openPage() : _start();

  /// The button's label to match [_onButton].
  String get _buttonLabel => _problem != null && !_canRetry
      ? AppStrings.updateOpenPage
      : AppStrings.updateNow;

  void _openPage() => launchUrl(_page, mode: LaunchMode.externalApplication);

  void _start() {
    // A download is already running: a second tap must not start another.
    if (_progress != null) return;
    final u = update;
    if (!u.canInstallInApp) {
      _openPage();
      return;
    }
    setState(() {
      _progress = 0;
      _problem = null;
      _canRetry = false;
    });
    try {
      _events?.cancel();
      final stream = debugOtaStarter?.call(u) ??
          OtaUpdate().execute(
            u.apkUrl!,
            destinationFilename: 'sabtawya-update.apk',
            sha256checksum: u.sha256,
          );
      _events = stream.listen(
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
        AccessLog.updateDownloadStarted();
        setState(() => _progress = int.tryParse(e.value ?? '') ?? _progress);
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() => _progress = 101);
        _installerTimer?.cancel();
        _installerTimer = Timer(_installerWait, () {
          if (mounted && _progress == 101) {
            _fail(AppStrings.updateNotFinished, retry: true);
          }
        });
      case OtaStatus.ALREADY_RUNNING_ERROR:
        // A download from before is still going: not a failure.
        break;
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail(AppStrings.updateNeedsPermission, retry: true);
      case OtaStatus.CHECKSUM_ERROR:
        _fail(AppStrings.updateBadFile, retry: true);
      default:
        _fail(AppStrings.updateFailed);
    }
  }

  void _fail(String message, {bool retry = false}) {
    if (!mounted) return;
    _installerTimer?.cancel();
    setState(() {
      _progress = null;
      _problem = message;
      _canRetry = retry;
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    _installerTimer?.cancel();
    super.dispose();
  }
}

class _UpdateBannerState extends State<_UpdateBanner>
    with _InstallLogic<_UpdateBanner> {
  @override
  AppUpdate get update => widget.update;

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
                    onPressed: _onButton,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.olive,
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      _buttonLabel,
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

/// Shown instead of the app when this build is below the published
/// `min_build`. No close button and no back: the only way on is to update.
class ForcedUpdateScreen extends StatefulWidget {
  const ForcedUpdateScreen({super.key, required this.update});

  final AppUpdate update;

  @override
  State<ForcedUpdateScreen> createState() => _ForcedUpdateScreenState();
}

class _ForcedUpdateScreenState extends State<ForcedUpdateScreen>
    with _InstallLogic<ForcedUpdateScreen> {
  @override
  AppUpdate get update => widget.update;

  /// Nobody has to find a button or a web page: the download starts by itself
  /// and Android then asks only for the usual "install" tap.
  @override
  void initState() {
    super.initState();
    if (widget.update.canInstallInApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final String text;
    if (_problem != null) {
      text = _problem!;
    } else if (p == null) {
      text = AppStrings.updateRequiredBody(widget.update.version);
    } else if (p > 100) {
      text = AppStrings.updateInstalling;
    } else {
      text = AppStrings.updateDownloading(p);
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration:
              const BoxDecoration(gradient: AppGradients.loginBackground),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.system_update_rounded,
                        size: 72, color: Colors.white),
                    const SizedBox(height: 20),
                    const Text(
                      AppStrings.updateRequiredTitle,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (p != null && p <= 100)
                      LinearProgressIndicator(
                        value: p / 100,
                        minHeight: 6,
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      ),
                    if (p == null)
                      FilledButton(
                        onPressed: _onButton,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.navyDark,
                          minimumSize: const Size(200, 48),
                        ),
                        child: Text(
                          _buttonLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    // Always there: an installer that is cancelled or never
                    // opens tells the app nothing, and this screen has no
                    // other way out. The web page installs the same APK.
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _openPage,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        minimumSize: const Size(200, 44),
                      ),
                      child: const Text(AppStrings.updateManual),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
