import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'illustrations.dart';
import 'motion.dart';

/// The Sabtawya emblem.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.school_outlined,
        size: size * 0.7,
        color: AppColors.navy,
      ),
    );
  }
}

/// The church's golden jubilee emblem.
class ChurchLogo extends StatelessWidget {
  const ChurchLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/church_logo.jpg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.church_outlined,
        size: size * 0.7,
        color: AppColors.maroon,
      ),
    );
  }
}

/// The two emblems in the top corners with the church and service names below.
///
/// Shared by the splash and the login screen so the opening of the app always
/// reads the same way. The row is laid out left to right on purpose: inside the
/// app's RTL [Directionality] the first child would otherwise land on the right.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.logoSize = 96});

  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppLogo(size: logoSize),
              ChurchLogo(size: logoSize),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          AppStrings.churchName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: AppColors.maroon,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          AppStrings.appTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          AppStrings.appSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

/// Warm gradient welcome banner shared by both dashboards. The greeting follows
/// the time of day.
class GreetingBanner extends StatelessWidget {
  const GreetingBanner({super.key, required this.name, this.subtitle});

  final String name;
  final String? subtitle;

  static (String, String) _greetingFor(int hour) {
    if (hour < 12) return ('صباح الخير', '☀️');
    if (hour < 18) return ('مساء النور', '🌤️');
    return ('مساء الخير', '🌙');
  }

  @override
  Widget build(BuildContext context) {
    final (greeting, emoji) = _greetingFor(DateTime.now().hour);
    return FadeSlideIn(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppGradients.navyHeader,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              end: -24,
              top: -28,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.22),
                ),
              ),
            ),
            PositionedDirectional(
              end: 40,
              bottom: -30,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.oliveLight.withValues(alpha: 0.20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const AppLogo(size: 44),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting $emoji',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${AppStrings.welcome}، $name 👋',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (subtitle != null ||
                            AppStrings.appSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle ?? AppStrings.appSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.oliveLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small branded card shown over the screen while an action runs.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: const [
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.oliveLight,
            ),
          ),
          Pulse(child: AppLogo(size: 40)),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.oliveLight,
                ),
              ),
              const Pulse(child: AppLogo(size: 52)),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Illustration(IllustrationKind.error, size: 130),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(AppStrings.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatefulWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.inbox_outlined,
    this.illustration,
    this.action,
  });

  final String title;
  final String? body;
  final IconData icon;

  /// The picture to show. When null it is chosen from [icon].
  final IllustrationKind? illustration;
  final Widget? action;

  static IllustrationKind kindForIcon(IconData icon) {
    if (icon == Icons.groups_outlined || icon == Icons.people_outline) {
      return IllustrationKind.children;
    }
    if (icon == Icons.class_outlined || icon == Icons.photo_library_outlined) {
      return IllustrationKind.classes;
    }
    if (icon == Icons.event_busy_outlined ||
        icon == Icons.calendar_month_outlined ||
        icon == Icons.calendar_view_month_outlined) {
      return IllustrationKind.attendance;
    }
    if (icon == Icons.volunteer_activism_outlined ||
        icon == Icons.assignment_outlined ||
        icon == Icons.how_to_reg_outlined) {
      return IllustrationKind.activities;
    }
    if (icon == Icons.event_outlined || icon == Icons.payments_outlined) {
      return IllustrationKind.events;
    }
    if (icon == Icons.emoji_events_outlined ||
        icon == Icons.leaderboard_outlined ||
        icon == Icons.insert_chart_outlined) {
      return IllustrationKind.competitions;
    }
    if (icon == Icons.cake_outlined) return IllustrationKind.birthdays;
    if (icon == Icons.person_search_outlined) return IllustrationKind.search;
    if (icon == Icons.block_outlined ||
        icon == Icons.settings_suggest_outlined) {
      return IllustrationKind.error;
    }
    return IllustrationKind.generic;
  }

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Illustration(
                  widget.illustration ?? EmptyState.kindForIcon(widget.icon),
                  size: 160,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                if (widget.body != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.body!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                ],
                if (widget.action != null) ...[
                  const SizedBox(height: 20),
                  widget.action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLead extends StatelessWidget {
  const _SectionLead({required this.icon, required this.accent});

  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Container(
        width: 4,
        height: 18,
        margin: const EdgeInsetsDirectional.only(end: 8),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(6),
      margin: const EdgeInsetsDirectional.only(end: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: accent),
    );
  }
}

/// A titled white panel used throughout the app.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.collapsible = false,
    this.initiallyExpanded = false,
    this.icon,
    this.accent = AppColors.navy,
  });

  /// Optional icon shown in a tinted badge before the title.
  final IconData? icon;
  final Color accent;

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool collapsible;

  /// Only used when [collapsible]; birthdays start closed, the lesson open.
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (collapsible && title != null) {
      return Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: padding,
            title: Row(
              children: [
                _SectionLead(icon: icon, accent: accent),
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            children: [child],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  _SectionLead(icon: icon, accent: accent),
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color = AppColors.navy,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Animate numeric values from 0 to the target.
    final numeric = double.tryParse(value);

    return Bounce(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Color.alphaBlend(color.withValues(alpha: 0.05), Colors.white),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.45)],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(height: 10),
                    ],
                    numeric != null
                        ? TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: numeric),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOut,
                            builder: (_, v, __) => Text(
                              numeric == numeric.truncateToDouble()
                                  ? v.round().toString()
                                  : v.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows `10/15` style scores with a colour that reflects the ratio.
class ScoreChip extends StatelessWidget {
  const ScoreChip({
    super.key,
    required this.score,
    required this.maxScore,
    this.compact = false,
    this.showMax = true,
  });

  final int score;
  final int maxScore;
  final bool compact;
  final bool showMax;

  Color get _color {
    if (maxScore <= 0) return AppColors.muted;
    final ratio = score / maxScore;
    if (ratio >= 0.8) return AppColors.success;
    if (ratio >= 0.5) return AppColors.warning;
    if (ratio > 0) return AppColors.danger;
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        showMax ? '$score/$maxScore' : '$score',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 12 : 13,
        ),
      ),
    );
  }
}

class PercentageBar extends StatelessWidget {
  const PercentageBar({super.key, required this.percentage, this.label});

  final double percentage;
  final String? label;

  Color get _color {
    if (percentage >= 80) return AppColors.success;
    if (percentage >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Expanded(
                  child: Text(label!, style: const TextStyle(fontSize: 14))),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (percentage / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              backgroundColor: AppColors.muted.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(_color),
            ),
          ),
        ),
      ],
    );
  }
}

/// A label/value row used by the child profile and the detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.isPhone = false,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    final text = hasValue ? value! : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          if (isPhone && hasValue) _CallButton(number: value!),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.call, size: 20),
      color: AppColors.success,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: 'اتصال',
      onPressed: () => launchUrl(Uri(scheme: 'tel', path: number)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? AppStrings.active : AppStrings.inactive,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// Compact tinted tile: icon, big value and a label (profile summaries).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
