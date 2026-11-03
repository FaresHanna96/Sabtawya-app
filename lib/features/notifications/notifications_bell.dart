import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/push_service.dart';
import '../../data/repositories/notification_repository.dart';
import 'notifications_screen.dart';

/// The notification ring in the app bar, for every signed-in user: shows how
/// many notifications are unread and opens the list.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key});

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  static const _repository = NotificationRepository();

  int _count = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    PushService.instance.received.addListener(_load);
    // A push can be missed (permission off, app closed); keep the count fresh.
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    PushService.instance.received.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final count = await _repository.unreadCount();
      if (mounted) setState(() => _count = count);
    } catch (_) {
      // The bell is a hint; a failed count just leaves it as it was.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.notificationsTitle,
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text('$_count'),
        child: Icon(
          _count > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
