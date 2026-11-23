import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// From this window width the app is laid out for a laptop or desktop
/// browser: a side menu instead of the bottom bar, a two-column home.
const double kWideBreakpoint = 900;

/// From this width the side menu shows its labels next to the icons.
const double kExtendedRailBreakpoint = 1200;

/// How wide an opened screen (a child's profile, a form, a report) is drawn
/// on a wide window. The screens are designed for a phone; stretched across a
/// desktop their rows and fields would be hard to read.
const double kPageMaxWidth = 720;

/// How wide a tab's content is drawn next to the side menu. The home lays
/// out two columns in it; the other tabs are lists that read best narrower.
const double kHomeMaxWidth = 1200;
const double kTabMaxWidth = 960;

/// The window is wide enough for the desktop layout.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Centres [child] in a column at most [maxWidth] wide, and tells it the
/// column's width through [MediaQuery] (screens that measure the window then
/// see their column). Narrower than [maxWidth]: [child] unchanged.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({
    super.key,
    required this.maxWidth,
    required this.child,
    this.background,
  });

  final double maxWidth;
  final Widget child;

  /// Paints the space on either side; transparent when null.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final media = MediaQuery.of(context);
        final width = box.maxWidth.isFinite && box.maxWidth < maxWidth
            ? box.maxWidth
            : maxWidth;
        // Already the window and no wider than allowed: nothing to do.
        if (width >= media.size.width) return child;
        final column = SizedBox(
          width: width,
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: ClipRect(child: child),
          ),
        );
        // Only paint the sides when there are sides.
        final centred = Center(child: column);
        return background == null || width >= box.maxWidth
            ? centred
            : ColoredBox(color: background!, child: centred);
      },
    );
  }
}

/// Two columns side by side when there is room ([main] at the start, which
/// is the right in Arabic; [side] at the end), one under the other when
/// there is not, [main] first. So the narrow order stays the phone's order.
class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.main,
    required this.side,
    this.minWidth = 840,
    this.gap = 16,
  });

  final List<Widget> main;
  final List<Widget> side;

  /// The narrowest width that still gets two columns.
  final double minWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < minWidth || side.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...main, ...side],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: main,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: side,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Every screen pushed over the home is drawn at most [kPageMaxWidth] wide,
/// centred on the navy background, with [inner]'s transition. The first
/// route (the home with its side menu) uses the whole window.
class CappedPageTransitionsBuilder extends PageTransitionsBuilder {
  const CappedPageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final page = route.isFirst
        ? child
        : MaxWidthBox(
            maxWidth: kPageMaxWidth,
            background: AppColors.navyDark,
            child: child,
          );
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      page,
    );
  }
}
