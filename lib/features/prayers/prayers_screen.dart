import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/motion.dart';
import 'prayers.dart';

/// «صلوات» (from المزيد): the servants' prayers, each opening to a page
/// that is easy to read aloud.
class PrayersScreen extends StatelessWidget {
  const PrayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.prayersTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const FadeSlideIn(child: _Intro()),
                const SizedBox(height: 16),
                for (final (i, p) in Prayers.all.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  FadeSlideIn(index: i + 1, child: _PrayerCard(prayer: p)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A calm line above the list: when the prayers are for.
class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyLight],
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              AppStrings.prayersIntro,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.prayer});

  final Prayer prayer;

  @override
  Widget build(BuildContext context) {
    final color = prayer.color;
    return Bounce(
      onTap: () => _open(context),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: () => _open(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.12), Colors.white],
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(prayer.icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayer.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        prayer.when,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: AppColors.readable(color)),
                          Text(
                            AppStrings.prayerReadTime(prayer.readMinutes),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.readable(color),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(AppIcons.forward, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => PrayerScreen(prayer: prayer)),
      );
}

/// One prayer, large and well spaced, with the text size the reader picks
/// (kept while the app is open), a copy button and a thin bar showing how
/// far down the reader is.
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key, required this.prayer});

  final Prayer prayer;

  /// The size last chosen, for the next prayer opened.
  static double _size = 20;

  static const minSize = 16.0;
  static const maxSize = 32.0;

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final _scroll = ScrollController();

  /// 0–1: how far down the prayer the reader has got.
  final _progress = ValueNotifier<double>(0);

  double get _size => PrayerScreen._size;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _progress.value = max <= 0 ? 0 : (_scroll.offset / max).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _resize(double by) => setState(() {
        PrayerScreen._size = (_size + by)
            .clamp(PrayerScreen.minSize, PrayerScreen.maxSize)
            .toDouble();
      });

  Future<void> _copy() async {
    final p = widget.prayer;
    await Clipboard.setData(
      ClipboardData(text: '${p.title}\n\n${p.paragraphs.join('\n\n')}'),
    );
    if (mounted) Ui.info(context, AppStrings.prayerCopied);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prayer;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.title),
        actions: [
          IconButton(
            tooltip: AppStrings.textSmaller,
            onPressed: _size > PrayerScreen.minSize ? () => _resize(-2) : null,
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          IconButton(
            tooltip: AppStrings.textBigger,
            onPressed: _size < PrayerScreen.maxSize ? () => _resize(2) : null,
            icon: const Icon(Icons.text_increase_rounded),
          ),
          IconButton(
            tooltip: AppStrings.copy,
            onPressed: _copy,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              color: p.color,
              backgroundColor: Colors.white24,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // A comfortable line length on a tablet or the web.
            constraints: const BoxConstraints(maxWidth: 680),
            child: SelectionArea(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _Heading(prayer: p),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: p.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final para in p.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              para,
                              textAlign: TextAlign.justify,
                              style: TextStyle(
                                fontSize: _size,
                                height: 1.9,
                                color: AppColors.navyDark,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon, the title and when it is said, above the text.
class _Heading extends StatelessWidget {
  const _Heading({required this.prayer});

  final Prayer prayer;

  @override
  Widget build(BuildContext context) {
    final color = prayer.color;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(prayer.icon, color: color, size: 32),
        ),
        const SizedBox(height: 10),
        Text(
          prayer.when,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppStrings.prayerReadTime(prayer.readMinutes),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.readable(color),
          ),
        ),
      ],
    );
  }
}
