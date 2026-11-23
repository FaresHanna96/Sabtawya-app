import 'package:flutter/material.dart';
import '../../core/utils/phone.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_sort.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/servant_repository.dart';
import '../../state/session_controller.dart';

/// Every servant's name, classes and two ways to reach them: call and
/// WhatsApp. Open to every servant; nothing else about the servant is shown.
class ServantDirectoryScreen extends StatefulWidget {
  const ServantDirectoryScreen({super.key});

  @override
  State<ServantDirectoryScreen> createState() => _ServantDirectoryScreenState();
}

class _ServantDirectoryScreenState extends State<ServantDirectoryScreen> {
  static const _repository = ServantRepository();

  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ServantContact> _visible(List<ServantContact> all) {
    final q = ArabicSort.key(_search.text);
    if (q.isEmpty) return all;
    return all
        .where((s) =>
            ArabicSort.key(s.fullName).contains(q) ||
            s.classNames.any((c) => ArabicSort.key(c).contains(q)) ||
            (s.mobile ?? '').contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.read<SessionController>().displayName;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.servantDirectory)),
      body: SafeArea(
        child: AsyncSection<List<ServantContact>>(
          loading: const SkeletonList(),
          load: _repository.directory,
          builder: (context, servants, reload) {
            final visible = _visible(servants);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchServantHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: AppStrings.clearSearch,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.person_search_outlined,
                      title: AppStrings.noData,
                    ),
                  )
                else
                  for (final s in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ServantContactCard(servant: s, senderName: me),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ServantContactCard extends StatelessWidget {
  const ServantContactCard({
    super.key,
    required this.servant,
    this.senderName = '',
  });

  final ServantContact servant;

  /// Who is writing; named in the WhatsApp check-in message.
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final tint =
        servant.gender == Gender.girl ? AppColors.coral : AppColors.navyLight;
    final mobile = (servant.mobile ?? '').trim();
    final whatsapp = WhatsApp.normalise(mobile);
    final subtitle = [
      servant.roleLabel,
      if (servant.classNames.isNotEmpty) servant.classNames.join('، '),
    ].join(' • ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: tint.withValues(alpha: 0.14),
              child: Text(
                servant.fullName.trim().isEmpty
                    ? '?'
                    : servant.fullName.trim().characters.first,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servant.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (mobile.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  AppStrings.noServantMobile,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              )
            else ...[
              IconButton(
                tooltip: AppStrings.call,
                icon: const Icon(Icons.call_rounded, size: 22),
                color: AppColors.success,
                onPressed: () => callNumber(mobile),
              ),
              if (whatsapp != null)
                IconButton(
                  tooltip: AppStrings.whatsapp,
                  icon: const WhatsAppIcon(size: 22),
                  // Opens with a ready check-in message (افتقاد الخدام).
                  onPressed: () => launchUrl(
                    WhatsApp.link(
                      whatsapp,
                      WhatsApp.servantCheckInMessage(
                        name: servant.fullName,
                        senderName: senderName,
                      ),
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
