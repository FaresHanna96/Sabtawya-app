import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/motion.dart';
import '../../state/session_controller.dart';
import 'more_entries.dart';

/// Raise to show the tour once more to everyone (after it changes).
const int kTourVersion = 1;

/// One page of the tour: a big icon, a title and two lines.
class TourPage {
  const TourPage(this.icon, this.color, this.title, this.body);

  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

/// The pages each role sees: what they will use first, in that order.
List<TourPage> tourPagesFor(MoreRole role) {
  const welcome = TourPage(
    Icons.waving_hand_rounded,
    AppColors.gold,
    AppStrings.tourWelcomeTitle,
    AppStrings.tourWelcomeBody,
  );
  const attendance = TourPage(
    Icons.fact_check_rounded,
    AppColors.success,
    AppStrings.tourAttendanceTitle,
    AppStrings.tourAttendanceBody,
  );
  return switch (role) {
    MoreRole.servant => const [
        welcome,
        attendance,
        TourPage(
          Icons.support_agent_rounded,
          AppColors.coral,
          AppStrings.tourFollowUpTitle,
          AppStrings.tourFollowUpServantBody,
        ),
        TourPage(
          Icons.menu_book_rounded,
          AppColors.olive,
          AppStrings.tourPrepTitle,
          AppStrings.tourPrepBody,
        ),
      ],
    MoreRole.generalServant => const [
        welcome,
        TourPage(
          Icons.fact_check_rounded,
          AppColors.success,
          AppStrings.tourAttendanceTitle,
          AppStrings.tourAttendanceGeneralBody,
        ),
        TourPage(
          Icons.support_agent_rounded,
          AppColors.coral,
          AppStrings.tourFollowUpTitle,
          AppStrings.tourFollowUpGeneralBody,
        ),
        TourPage(
          Icons.insert_chart_outlined,
          AppColors.sky,
          AppStrings.tourMoreTitle,
          AppStrings.tourMoreBody,
        ),
      ],
    MoreRole.admin => const [
        welcome,
        attendance,
        TourPage(
          Icons.support_agent_rounded,
          AppColors.coral,
          AppStrings.tourFollowUpTitle,
          AppStrings.tourFollowUpAdminBody,
        ),
        TourPage(
          Icons.monitor_heart_outlined,
          AppColors.navyLight,
          AppStrings.tourClassesTitle,
          AppStrings.tourClassesBody,
        ),
      ],
  };
}

/// Remembers, on this phone, the newest tour already shown.
class TourStore {
  TourStore()
      : _memory = null,
        _gate = null;

  /// Kept in memory only, for tests. [gate], when given, holds back the
  /// answer of [seen] until it completes.
  TourStore.memory([int seen = 0, this._gate]) : _memory = {_key: seen};

  static const _boxName = 'whats_new';
  static const _key = 'tour_seen';

  static final TourStore instance = TourStore();

  final Map<String, int>? _memory;
  final Future<void>? _gate;

  Future<int> seen() async {
    if (_gate != null) await _gate;
    if (_memory != null) return _memory[_key] ?? 0;
    try {
      final v = (await Hive.openBox<dynamic>(_boxName)).get(_key);
      return v is int ? v : 0;
    } catch (_) {
      return kTourVersion; // unreadable: do not show it on every start
    }
  }

  Future<void> markSeen(int version) async {
    if (_memory != null) {
      _memory[_key] = version;
      return;
    }
    try {
      await (await Hive.openBox<dynamic>(_boxName)).put(_key, version);
    } catch (_) {}
  }
}

/// Shows the tour once on this phone (per [kTourVersion]).
class WelcomeTour {
  const WelcomeTour._();

  static bool _checking = false;

  /// True when the tour was shown (the caller then skips "what's new").
  static Future<bool> maybeShow(
    BuildContext context, {
    TourStore? store,
    int version = kTourVersion,
    MoreRole? role,
  }) async {
    if (_checking) return false;
    _checking = true;
    final s = store ?? TourStore.instance;
    final Future<void> closed;
    try {
      if (await s.seen() >= version) return false;
      // The home can be built twice while the profile loads: a first copy
      // gone by now must not mark the tour seen, or the second never shows
      // it. So it is marked only once it is actually open.
      if (!context.mounted) return false;
      closed = Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => WelcomeTourScreen(role: role),
        ),
      );
      await s.markSeen(version);
    } finally {
      _checking = false;
    }
    await closed;
    return true;
  }
}

/// The tour itself: swipe or «التالي» through the pages, «تخطي» to leave.
class WelcomeTourScreen extends StatefulWidget {
  const WelcomeTourScreen({super.key, this.role});

  /// Taken from the signed-in person when null.
  final MoreRole? role;

  @override
  State<WelcomeTourScreen> createState() => _WelcomeTourScreenState();
}

class _WelcomeTourScreenState extends State<WelcomeTourScreen> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  MoreRole _role(BuildContext context) {
    if (widget.role != null) return widget.role!;
    final s = context.read<SessionController>();
    return s.isAdmin
        ? MoreRole.admin
        : s.isGeneralServant
            ? MoreRole.generalServant
            : MoreRole.servant;
  }

  void _next(int count) {
    Haptics.select();
    if (_index >= count - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = tourPagesFor(_role(context));
    final last = _index == pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AnimatedOpacity(
                opacity: last ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: last ? null : () => Navigator.of(context).pop(),
                  child: const Text(AppStrings.tourSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _PageBody(page: pages[i]),
              ),
            ),
            _Dots(count: pages.length, index: _index),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _next(pages.length),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child:
                      Text(last ? AppStrings.tourStart : AppStrings.tourNext),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final TourPage page;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Float(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusTint(page.color, 0.16),
              ),
              child: Icon(page.icon, size: 68, color: page.color),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${index + 1} / $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index
                    ? AppColors.navy
                    : AppColors.navy.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
