import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/servant_repository.dart';

/// أمين الخدمة's inbox for open sign-ups.
class PendingRequestsScreen extends StatefulWidget {
  const PendingRequestsScreen({super.key});

  @override
  State<PendingRequestsScreen> createState() => _PendingRequestsScreenState();
}

class _PendingRequestsScreenState extends State<PendingRequestsScreen> {
  static const _repository = ServantRepository();
  final _sectionKey = GlobalKey<AsyncSectionState<List<PendingServant>>>();

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  Future<void> _review(PendingServant request, {required bool accept}) async {
    if (!accept) {
      final confirmed = await Ui.confirm(
        context,
        title: AppStrings.rejectRequest,
        message: AppStrings.confirmRejectRequest,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    final ok = await Ui.runGuarded(
      context,
      () => _repository.reviewSignup(
        profileId: request.id,
        accept: accept,
        servantEmail: request.email,
        servantName: request.fullName,
      ),
      successMessage:
          accept ? AppStrings.requestAccepted : AppStrings.requestRejected,
    );
    if (ok) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.pendingRequests)),
      body: AsyncSection<List<PendingServant>>(
        key: _sectionKey,
        load: _repository.pendingSignups,
        builder: (context, requests, reload) {
          if (requests.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 40),
                EmptyState(
                  icon: Icons.how_to_reg_outlined,
                  title: AppStrings.noPendingRequests,
                  body: AppStrings.pendingRequestsBody,
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final request = requests[index];
              return staggered(
                  index,
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            request.fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            request.roleLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.maroon,
                            ),
                          ),
                          if (request.email != null)
                            Text(
                              request.email!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          if (request.mobile != null)
                            Text(
                              request.mobile!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          Text(
                            AppDateUtils.formatDateTime(request.requestedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      _review(request, accept: true),
                                  child: const Text(AppStrings.acceptRequest),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _review(request, accept: false),
                                  child: const Text(AppStrings.rejectRequest),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ));
            },
          );
        },
      ),
    );
  }
}
