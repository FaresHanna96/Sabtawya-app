import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/announcement.dart';
import '../../data/repositories/announcement_repository.dart';
import 'announcement_compose_screen.dart';

/// أمين الخدمة's announcements: what was sent, to whom, and how many read it.
/// Tapping one shows who has and has not read it, with a WhatsApp nudge for
/// those who have not.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  static const _repository = AnnouncementRepository();
  final _sectionKey = GlobalKey<AsyncSectionState<List<Announcement>>>();

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _compose() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AnnouncementComposeScreen(),
      ),
    );
    if (sent == true) await _reload();
  }

  Future<void> _showReads(Announcement a) async {
    final delete = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ReadsSheet(announcement: a),
    );
    if (delete != true || !mounted) return;
    final yes = await Ui.confirm(
      context,
      title: AppStrings.deleteAnnouncement,
      message: AppStrings.confirmDeleteAnnouncement,
      confirmLabel: AppStrings.deleteAnnouncement,
      destructive: true,
    );
    if (!yes || !mounted) return;
    final ok = await Ui.runGuarded(context, () => _repository.delete(a.id));
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.announcementsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        icon: const Icon(Icons.campaign_rounded),
        label: const Text(AppStrings.newAnnouncement),
      ),
      body: SafeArea(
        child: AsyncSection<List<Announcement>>(
          key: _sectionKey,
          loading: const SkeletonList(),
          load: _repository.sent,
          builder: (context, items, reload) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.campaign_outlined,
                    title: AppStrings.noAnnouncements,
                    body: AppStrings.noAnnouncementsBody,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => FadeSlideIn(
                index: i,
                child: _AnnouncementTile(
                  announcement: items[i],
                  onTap: () => _showReads(items[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement, required this.onTap});

  final Announcement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    final progress = a.recipients == 0 ? 0.0 : a.readCount / a.recipients;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign_rounded,
                      color: AppColors.maroon, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                a.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                '${a.audienceLabel} • ${AppDateUtils.sinceLabel(a.createdAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: AppColors.success,
                        backgroundColor:
                            AppColors.success.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppStrings.readOf(a.readCount, a.recipients),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Who got the announcement: those who have not read it first, each with a
/// WhatsApp nudge; then those who did, with when.
class _ReadsSheet extends StatelessWidget {
  const _ReadsSheet({required this.announcement});

  final Announcement announcement;

  static const _repository = AnnouncementRepository();

  Future<void> _remind(AnnouncementRead r) async {
    final number = WhatsApp.normalise(r.mobile);
    if (number == null) return;
    final first = r.fullName.trim().split(RegExp(r'\s+')).first;
    await launchUrl(
      WhatsApp.link(
        number,
        AppStrings.announcementReminder(first, announcement.title),
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => AsyncSection<List<AnnouncementRead>>(
        load: () => _repository.reads(announcement.id),
        enableRefresh: false,
        builder: (context, reads, reload) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              announcement.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SelectableText(
              announcement.body,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                label: const Text(
                  AppStrings.deleteAnnouncement,
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ),
            const Divider(height: 20),
            Text(
              '${AppStrings.announcementReads} — '
              '${AppStrings.readOf(reads.where((r) => r.isRead).length, reads.length)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final r in reads)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  r.isRead
                      ? Icons.done_all_rounded
                      : Icons.schedule_rounded,
                  color: r.isRead ? AppColors.success : AppColors.muted,
                ),
                title: Text(r.fullName),
                subtitle: Text(
                  r.isRead
                      ? '${AppStrings.readAt} ${AppDateUtils.sinceLabel(r.readAt!)}'
                      : AppStrings.notReadYet,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: !r.isRead && WhatsApp.normalise(r.mobile) != null
                    ? IconButton(
                        tooltip: AppStrings.remindOnWhatsApp,
                        onPressed: () => _remind(r),
                        icon: const WhatsAppIcon(size: 22),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
