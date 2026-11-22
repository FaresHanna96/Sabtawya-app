import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ui.dart';
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, p) in Prayers.all.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              _PrayerCard(
                prayer: p,
                // Before: the morning gold; after: the evening navy.
                color: p == Prayers.beforeService
                    ? AppColors.gold
                    : AppColors.navyLight,
                icon: p == Prayers.beforeService
                    ? Icons.wb_sunny_rounded
                    : Icons.nights_stay_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.prayer,
    required this.color,
    required this.icon,
  });

  final Prayer prayer;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => PrayerScreen(prayer: prayer)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prayer.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prayer.when,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.forward, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One prayer, large and well spaced, with the text size the reader picks
/// (kept while the app is open) and a copy button.
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
  double get _size => PrayerScreen._size;

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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // A comfortable line length on a tablet or the web.
            constraints: const BoxConstraints(maxWidth: 680),
            child: SelectionArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  for (final para in p.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
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
          ),
        ),
      ),
    );
  }
}
