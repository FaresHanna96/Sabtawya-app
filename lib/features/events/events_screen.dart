import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/event.dart';
import '../../data/repositories/event_repository.dart';
import '../../state/session_controller.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _repository = EventRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<Event>>>();

  Future<List<Event>> _load() => _repository.listEvents();
  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const EventFormScreen()),
    );
    if (added == true) await _reload();
  }

  Future<void> _edit(Event event) async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EventFormScreen(event: event)),
    );
    if (edited == true) await _reload();
  }

  Future<void> _delete(Event event) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.deleteEvent,
      message: AppStrings.confirmDeleteEvent,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await Ui.runGuarded(context, () => _repository.deleteEvent(event.id));
    if (mounted) await _reload();
  }

  Future<void> _open(Event event) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(event: event),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<SessionController>().isAdmin;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.events)),
      body: SafeArea(
        child: Stack(
          children: [
            AsyncSection<List<Event>>(
              loading: const SkeletonList(),
              key: _sectionKey,
              load: _load,
              builder: (context, events, reload) {
                if (events.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.event_outlined,
                        title: AppStrings.noEvents,
                        body: AppStrings.noEventsBody,
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = events[index];
                    return FadeSlideIn(
                      index: index,
                      child: _EventTile(
                        event: e,
                        isAdmin: isAdmin,
                        onTap: () => _open(e),
                        onEdit: () => _edit(e),
                        onDelete: () => _delete(e),
                      ),
                    );
                  },
                );
              },
            ),
            if (isAdmin)
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                  label: const Text(AppStrings.addEvent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Event event;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.goldTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: AppColors.gold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.formatDate(event.eventDate),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.olive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${event.cost.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.olive,
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_Action>(
                  onSelected: (action) {
                    if (action == _Action.edit) onEdit();
                    if (action == _Action.delete) onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _Action.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text(AppStrings.editEvent),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: _Action.delete,
                      child: ListTile(
                        leading: Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          AppStrings.deleteEvent,
                          style: TextStyle(color: AppColors.danger),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Action { edit, delete }
