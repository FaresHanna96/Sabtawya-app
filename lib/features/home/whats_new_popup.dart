import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/config/app_version.dart';
import '../../core/config/whats_new.dart';

/// Remembers, on this phone, the newest build whose popup was already shown.
class WhatsNewStore {
  WhatsNewStore({Future<Box<dynamic>> Function()? open})
      : _open = open ?? (() => Hive.openBox<dynamic>(_boxName)),
        _memory = null;

  /// Kept in memory only, for tests.
  WhatsNewStore.memory([int? seen])
      : _open = null,
        _memory = {if (seen != null) _key: seen};

  static const _boxName = 'whats_new';
  static const _key = 'seen_build';

  static final WhatsNewStore instance = WhatsNewStore();

  final Future<Box<dynamic>> Function()? _open;
  final Map<String, int>? _memory;

  Future<int> seen() async {
    if (_memory != null) return _memory[_key] ?? 0;
    try {
      final v = (await _open!()).get(_key);
      return v is int ? v : 0;
    } catch (_) {
      return -1; // unreadable: show nothing rather than repeat it every start
    }
  }

  Future<void> markSeen(int build) async {
    if (_memory != null) {
      _memory[_key] = build;
      return;
    }
    try {
      await (await _open!()).put(_key, build);
    } catch (_) {}
  }
}

/// Shows the "what's new" popup once after an update. A phone that has not seen
/// this build's notes yet gets them; afterwards (and on a build with no notes)
/// nothing appears.
class WhatsNewPopup {
  const WhatsNewPopup._();

  /// True while one call is reading and recording what this phone has seen.
  static bool _checking = false;

  static Future<void> maybeShow(
    BuildContext context, {
    int build = kAppBuild,
    Map<int, List<WhatsNewItem>> notes = kWhatsNew,
    WhatsNewStore? store,
  }) async {
    // The home screen can be built twice while the profile loads; a second
    // call arriving while the first is still checking would see "not shown
    // yet" too and stack a second popup.
    if (_checking) return;
    _checking = true;
    final List<WhatsNewItem>? items;
    try {
      final s = store ?? WhatsNewStore.instance;
      final seen = await s.seen();
      if (seen < 0 || seen >= build) return;
      items = notes[build];
      await s.markSeen(build);
    } finally {
      _checking = false;
    }
    final shown = items;
    if (shown == null || shown.isEmpty || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('جديد في سبتاوية'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final i in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(i.icon, color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.title,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(i.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }
}
