import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/push_service.dart';
import '../../data/repositories/servant_repository.dart';
import 'pending_requests_screen.dart';

/// The admin's notification ring: a bell in the app bar with the number of
/// sign-ups waiting for a decision. Tapping it opens the requests.
class PendingRequestsBell extends StatefulWidget {
  const PendingRequestsBell({super.key});

  @override
  State<PendingRequestsBell> createState() => _PendingRequestsBellState();
}

class _PendingRequestsBellState extends State<PendingRequestsBell> {
  static const _servants = ServantRepository();

  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
    PushService.instance.received.addListener(_load);
    PushService.instance.registerDevice();
  }

  @override
  void dispose() {
    PushService.instance.received.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final count = await _servants.pendingSignupCount();
      if (mounted) setState(() => _count = count);
    } catch (_) {
      // The bell is a hint; a failed count just leaves it quiet.
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PendingRequestsScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppStrings.pendingRequests,
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
