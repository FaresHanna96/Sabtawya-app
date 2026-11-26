import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A profile page: a header that scrolls away, a tab bar that stays pinned,
/// and one list per tab.
///
/// The pinned bar is "absorbed" by the scroll view and each tab leaves room
/// for it, so a tab never opens with its first card hidden under the bar
/// (which looked like the page had scrolled down by itself). Each tab also
/// keeps its own scroll position. Needs a [DefaultTabController] above it.
class ProfileTabs extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.header,
    required this.tabBar,
    required this.tabs,
    required this.onRefresh,
  });

  /// What scrolls away above the bar.
  final Widget header;
  final TabBar tabBar;

  /// The cards of each tab, in the bar's order.
  final List<List<Widget>> tabs;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final barHeight = tabBar.preferredSize.height;
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: header),
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: _TabsHeader(tabBar),
          ),
        ),
      ],
      body: TabBarView(
        children: [
          for (var i = 0; i < tabs.length; i++)
            RefreshIndicator(
              onRefresh: onRefresh,
              edgeOffset: barHeight,
              child: Builder(
                builder: (context) => CustomScrollView(
                  key: PageStorageKey<String>('profile-tab-$i'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverOverlapInjector(
                      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Each card gets its own storage slot: a folding
                          // card would otherwise read the tab's saved scroll
                          // position as its open/closed flag and fail.
                          for (var j = 0; j < tabs[i].length; j++)
                            KeyedSubtree(
                              key: PageStorageKey<String>('profile-card-$i-$j'),
                              child: tabs[i][j],
                            ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader(this.tabs);

  final TabBar tabs;

  @override
  double get minExtent => tabs.preferredSize.height;

  @override
  double get maxExtent => tabs.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) =>
      Material(
        color: AppColors.surface,
        elevation: overlapsContent || shrinkOffset > 0 ? 2 : 0,
        child: tabs,
      );

  @override
  bool shouldRebuild(_TabsHeader old) => old.tabs != tabs;
}
