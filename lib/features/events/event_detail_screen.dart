import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/event.dart';
import '../../data/repositories/child_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/services/excel_service.dart';
import '../../data/services/file_service.dart';
import '../../state/session_controller.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _repository = EventRepository();

  final _sectionKey = GlobalKey<AsyncSectionState<List<ChildEventBalance>>>();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Collected so far, by payment method (`cash` / `tayo`).
  Map<String, Map<String, double>> _byChild = const {};

  /// Cash / kitty totals for [ids] (every child when null).
  Map<String, double> _methodSum([Iterable<String>? ids]) {
    final sum = <String, double>{'cash': 0, 'tayo': 0};
    for (final e in _byChild.entries) {
      if (ids != null && !ids.contains(e.key)) continue;
      sum['cash'] = sum['cash']! + (e.value['cash'] ?? 0);
      sum['tayo'] = sum['tayo']! + (e.value['tayo'] ?? 0);
    }
    return sum;
  }

  /// Who to ring for each child: his own number, else his mother's, else his
  /// father's. Children with no number at all are left out.
  Map<String, String> _phones = const {};

  /// "كاش 150  •  كيتي 50"
  String _methodLine(Map<String, double> m) =>
      '${AppStrings.paymentMethodCash} ${(m['cash'] ?? 0).toStringAsFixed(0)}'
      '  •  ${AppStrings.paymentMethodTayo} '
      '${(m['tayo'] ?? 0).toStringAsFixed(0)}';

  Future<List<ChildEventBalance>> _load() async {
    final balances = await _repository.balances(widget.event.id);
    try {
      final children = await const ChildRepository().all();
      final phones = <String, String>{};
      for (final c in children) {
        for (final n in [c.mobile, c.motherMobile, c.fatherMobile]) {
          if (n != null && n.trim().isNotEmpty) {
            phones[c.id] = n.trim();
            break;
          }
        }
      }
      _phones = phones;
    } catch (_) {
      _phones = const {}; // the call button is an extra; never block the list
    }
    try {
      _byChild = await _repository.methodTotalsByChild(widget.event.id);
    } catch (_) {
      _byChild = const {}; // the split is an extra; never block the list
    }
    return balances;
  }

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

  bool _exporting = false;

  /// Asks which statuses to include (the tab being viewed is pre-ticked),
  /// then shares an Excel file with one sheet per chosen status.
  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final balances = await _load();
      if (!mounted) return;
      final picked = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _ExportStatusSheet(
          counts: ExcelService.eventTabCounts(balances),
          initial: ExcelService.eventTabs[_tabController.index],
        ),
      );
      if (picked == null || picked.isEmpty || !mounted) return;
      final names = {
        for (final c in context.read<SessionController>().myClasses)
          c.classId: c.className,
      };
      final bytes = ExcelService.eventWorkbook(
        balances: balances,
        methodByChild: _byChild,
        phones: _phones,
        classNameOf: (id) => names[id] ?? AppStrings.unknown,
        tabs: picked,
      );
      // "اسم الرحلة - تاريخ الرحلة - الحالة.xlsx"
      final name = [
        widget.event.title,
        AppDateUtils.toIsoDate(widget.event.eventDate),
        picked.join(' + '),
      ].join(' - ').replaceAll(RegExp(r'[\/:*?"<>|]'), '-').trim();
      await FileService.saveAndShare(
        fileName: '$name.xlsx',
        bytes: bytes,
      );
      if (mounted) Ui.success(context, AppStrings.exportDone);
    } catch (e) {
      if (mounted) Ui.error(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openPayments(ChildEventBalance balance) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentHistorySheet(
        event: widget.event,
        balance: balance,
        onChanged: _reload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        actions: [
          IconButton(
            tooltip: AppStrings.exportEvent,
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.ios_share),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              AppDateUtils.formatDate(widget.event.eventDate),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AsyncSection<List<ChildEventBalance>>(
          key: _sectionKey,
          load: _load,
          builder: (context, balances, reload) {
            if (balances.isEmpty) {
              return const Center(
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: AppStrings.noChildren,
                  body: AppStrings.noChildrenBody,
                ),
              );
            }

            final totalCollected =
                balances.fold<double>(0, (s, b) => s + b.totalPaid);
            final totalExpected =
                balances.fold<double>(0, (s, b) => s + b.cost);
            final progress =
                totalExpected > 0 ? totalCollected / totalExpected : 0.0;

            // Same rules as the counts and the Excel export.
            List<ChildEventBalance> tab(String name) =>
                balances.where(ExcelService.eventTabFilter[name]!).toList();
            final partial = tab(AppStrings.partialPay);
            final notPaid = tab(AppStrings.notPaidTab);
            final fullPaid = tab(AppStrings.paidInFull);
            // Booked the trip: reserved, started paying, or paid in full.
            final booked = tab(AppStrings.bookedTab);

            final session = context.read<SessionController>();
            String getClassName(String id) {
              for (final c in session.myClasses) {
                if (c.classId == id) return c.className;
              }
              return 'فصل غير معروف';
            }

            return Column(
              children: [
                // Summary card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${AppStrings.collected}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.olive,
                                ),
                              ),
                              // The collected amount counts up.
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: totalCollected),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => Text(
                                  '${v.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.olive,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${AppStrings.expected}: ${totalExpected.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            // The bar fills up when the trip opens.
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: progress.clamp(0.0, 1.0),
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => LinearProgressIndicator(
                                value: v,
                                minHeight: 8,
                                backgroundColor:
                                    AppColors.navy.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.olive,
                                ),
                              ),
                            ),
                          ),
                          if (_byChild.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _methodLine(_methodSum()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Filter tab bar with live counts
                // All five fit on screen (no swiping): the count on top, a
                // short label under it.
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    _countTab(balances.length, AppStrings.all),
                    _countTab(booked.length, AppStrings.bookedTab),
                    _countTab(partial.length, AppStrings.partialPay),
                    _countTab(fullPaid.length, AppStrings.paidInFull),
                    _countTab(notPaid.length, AppStrings.notPaidTab),
                  ],
                ),
                // Filtered list - rebuilds on tab change without reloading data
                Expanded(
                  child: ListenableBuilder(
                    listenable: _tabController,
                    builder: (context, _) {
                      final List<ChildEventBalance> filtered;
                      switch (_tabController.index) {
                        case 1:
                          filtered = booked;
                        case 2:
                          filtered = partial;
                        case 3:
                          filtered = fullPaid;
                        case 4:
                          filtered = notPaid;
                        default:
                          filtered = balances;
                      }

                      if (filtered.isEmpty) {
                        return const Center(
                          child: EmptyState(
                            icon: Icons.payments_outlined,
                            title: 'لا يوجد',
                            body: '',
                          ),
                        );
                      }

                      final filteredExpected =
                          filtered.fold<double>(0, (s, b) => s + b.cost);
                      final filteredCollected =
                          filtered.fold<double>(0, (s, b) => s + b.totalPaid);
                      final filteredRemaining =
                          filteredExpected - filteredCollected;

                      final byClass = <String, List<ChildEventBalance>>{};
                      for (final b in filtered) {
                        (byClass[b.classId] ??= []).add(b);
                      }
                      final sortedClasses = byClass.entries.toList()
                        ..sort((a, b) =>
                            getClassName(a.key).compareTo(getClassName(b.key)));

                      var row = 0;
                      return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: ListView(
                            key: ValueKey(_tabController.index),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: [
                              // Estimated payment summary for the filtered group
                              if (_tabController.index > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  // Two short lines: totals, then cash / kitty for
                                  // the children in this tab.
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text.rich(
                                        TextSpan(
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                          children: [
                                            const TextSpan(
                                                text:
                                                    '${AppStrings.collected} '),
                                            TextSpan(
                                              text: filteredCollected
                                                  .toStringAsFixed(0),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.olive,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  ' من ${filteredExpected.toStringAsFixed(0)}',
                                            ),
                                            if (filteredRemaining > 0) ...[
                                              const TextSpan(
                                                  text:
                                                      '  •  ${AppStrings.remaining} '),
                                              TextSpan(
                                                text: filteredRemaining
                                                    .toStringAsFixed(0),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.danger,
                                                ),
                                              ),
                                            ],
                                            const TextSpan(text: ' ج.م'),
                                          ],
                                        ),
                                      ),
                                      if (_byChild.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            _methodLine(_methodSum(filtered
                                                .map((b) => b.childId))),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              for (final entry in sortedClasses) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8, top: 4),
                                  child: Text(
                                    getClassName(entry.key),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                                ...entry.value.map(
                                  (b) => staggered(
                                    row++,
                                    _BalanceRow(
                                      balance: b,
                                      onTap: () => _openPayments(b),
                                      // A call button on every tab (no number,
                                      // no button).
                                      phone: _phones[b.childId],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ));
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// A tab with the count big on top and a short label under it, so five of
/// them share the screen width.
Tab _countTab(int count, String label) => Tab(
      height: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );

// ---------------------------------------------------------------------------

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.balance,
    required this.onTap,
    this.phone,
  });

  final ChildEventBalance balance;
  final VoidCallback onTap;

  /// When set, a call button is shown beside the row.
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final isPaid = balance.remaining <= 0;
    final isPartial = !isPaid && balance.totalPaid > 0;
    final reservedOnly = balance.reserved && balance.totalPaid == 0;

    final chipColor = isPaid
        ? AppColors.olive
        : isPartial
            ? AppColors.warning
            : AppColors.danger;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  balance.childName,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (reservedOnly) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sky.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    AppStrings.reservedBadge,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sky,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isPaid)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppStrings.paidInFull,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: chipColor,
                    ),
                  ),
                )
              else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${balance.totalPaid.toStringAsFixed(0)} / ${balance.cost.toStringAsFixed(0)} ج.م',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${AppStrings.remaining}: ${balance.remaining.toStringAsFixed(0)} ج.م',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: chipColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (phone != null)
                IconButton(
                  icon: const Icon(Icons.call, size: 20),
                  color: AppColors.success,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  tooltip: 'اتصال',
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone!)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left, size: 18, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment history bottom sheet
// ---------------------------------------------------------------------------

class _PaymentHistorySheet extends StatefulWidget {
  const _PaymentHistorySheet({
    required this.event,
    required this.balance,
    required this.onChanged,
  });

  final Event event;
  final ChildEventBalance balance;
  final VoidCallback onChanged;

  @override
  State<_PaymentHistorySheet> createState() => _PaymentHistorySheetState();
}

class _PaymentHistorySheetState extends State<_PaymentHistorySheet> {
  static const _repository = EventRepository();

  List<EventPayment>? _payments;
  bool _loading = true;
  String? _error;

  /// Booked without paying; flips locally after reserve / cancel.
  late bool _reserved = widget.balance.reserved;

  Future<void> _toggleReservation() async {
    if (_reserved) {
      final yes = await Ui.confirm(
        context,
        title: AppStrings.cancelReservation,
        message: AppStrings.cancelReservationBody,
        destructive: true,
      );
      if (!yes || !mounted) return;
    }
    final cancel = _reserved;
    final ok = await Ui.runGuarded(
      context,
      () => cancel
          ? _repository.unreserve(widget.event.id, widget.balance.childId)
          : _repository.reserve(widget.event.id, widget.balance.childId),
      successMessage:
          cancel ? AppStrings.reservationCancelled : AppStrings.reservedSaved,
    );
    if (!ok || !mounted) return;
    setState(() => _reserved = !cancel);
    widget.onChanged();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p =
          await _repository.payments(widget.event.id, widget.balance.childId);
      if (mounted) setState(() => _payments = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(EventPayment payment) async {
    final confirmed = await Ui.confirm(
      context,
      title: AppStrings.deletePayment,
      message: AppStrings.confirmDeletePayment,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await Ui.runGuarded(
      context,
      () => _repository.deletePayment(payment.id),
      successMessage: AppStrings.paymentDeleted,
    );
    await _load();
    widget.onChanged();
  }

  Future<void> _addPayment() async {
    final liveRemaining = _payments != null
        ? widget.balance.cost -
            _payments!.fold<double>(0, (s, p) => s + p.amount)
        : widget.balance.remaining;

    final result = await showDialog<({double amount, String method})>(
      context: context,
      builder: (_) => _AddPaymentDialog(
        maxAmount: liveRemaining > 0 ? liveRemaining : 0,
      ),
    );

    if (result == null || !mounted) return;

    await Ui.runGuarded(
      context,
      () => _repository.addPayment(
        widget.event.id,
        widget.balance.childId,
        result.amount,
        paymentMethod: result.method,
      ),
      successMessage: AppStrings.paymentSaved,
    );
    await _load();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<SessionController>().profile?.id;
    final isAdmin = context.read<SessionController>().isAdmin;
    final balance = widget.balance;

    final maxListHeight = MediaQuery.of(context).size.height * 0.45;
    final effectiveRemaining = _payments != null
        ? balance.cost - _payments!.fold<double>(0, (s, p) => s + p.amount)
        : balance.remaining;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.childName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${AppStrings.remaining}: ${balance.remaining.toStringAsFixed(0)} ج.م',
                      style: TextStyle(
                        fontSize: 13,
                        color: balance.remaining <= 0
                            ? AppColors.olive
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: effectiveRemaining > 0 ? _addPayment : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(AppStrings.addPayment),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        // Reserve now, pay later: only while nothing is paid yet.
        if ((_payments ?? const <EventPayment>[]).isEmpty &&
            balance.totalPaid == 0 &&
            !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleReservation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _reserved ? AppColors.danger : AppColors.sky,
                ),
                icon: Icon(
                  _reserved
                      ? Icons.event_busy_outlined
                      : Icons.bookmark_add_outlined,
                  size: 18,
                ),
                label: Text(
                  _reserved
                      ? AppStrings.cancelReservation
                      : AppStrings.reserveWithoutPay,
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _payments == null || _payments!.isEmpty
                      ? const Center(
                          child: EmptyState(
                            icon: Icons.payments_outlined,
                            title: AppStrings.noPayments,
                            body: '',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          itemCount: _payments!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final p = _payments![index];
                            final canDelete = isAdmin || p.paidBy == myId;
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              leading: const Icon(
                                Icons.payments_outlined,
                                color: AppColors.navy,
                                size: 20,
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    '${p.amount.toStringAsFixed(0)} ج.م',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (p.isTayo
                                              ? AppColors.navy
                                              : AppColors.olive)
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p.isTayo
                                          ? AppStrings.paymentMethodTayo
                                          : AppStrings.paymentMethodCash,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: p.isTayo
                                            ? AppColors.navy
                                            : AppColors.olive,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                AppDateUtils.formatDate(p.paidAt),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted),
                              ),
                              trailing: canDelete
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.danger,
                                        size: 20,
                                      ),
                                      onPressed: () => _delete(p),
                                    )
                                  : null,
                            );
                          },
                        ),
        ),
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add payment dialog
// ---------------------------------------------------------------------------

class _AddPaymentDialog extends StatefulWidget {
  const _AddPaymentDialog({required this.maxAmount});

  final double maxAmount;

  @override
  State<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<_AddPaymentDialog> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _method = 'cash';

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AppStrings.addPayment),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: AppStrings.paymentAmount,
                helperText:
                    '${AppStrings.remaining}: ${widget.maxAmount.toStringAsFixed(0)} ج.م',
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null) return AppStrings.paymentAmountRequired;
                if (n <= 0) return AppStrings.paymentAmountInvalid;
                if (n > widget.maxAmount) {
                  return AppStrings.paymentAmountExceeds;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppStrings.paymentMethodLabel,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MethodChip(
                  label: AppStrings.paymentMethodCash,
                  selected: _method == 'cash',
                  onTap: () => setState(() => _method = 'cash'),
                ),
                const SizedBox(width: 8),
                _MethodChip(
                  label: AppStrings.paymentMethodTayo,
                  selected: _method == 'tayo',
                  onTap: () => setState(() => _method = 'tayo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: AppStrings.paymentNotes,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final amount = double.tryParse(_amountController.text.trim()) ?? 0;
            Navigator.of(context).pop((amount: amount, method: _method));
          },
          child: const Text(AppStrings.save),
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.navy;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

/// "Which statuses do you want in the file?" One tick per tab of the event
/// screen, each with its number of children.
class _ExportStatusSheet extends StatefulWidget {
  const _ExportStatusSheet({required this.counts, required this.initial});

  final Map<String, int> counts;
  final String initial;

  @override
  State<_ExportStatusSheet> createState() => _ExportStatusSheetState();
}

class _ExportStatusSheetState extends State<_ExportStatusSheet> {
  late final _selected = <String>{widget.initial};

  @override
  Widget build(BuildContext context) {
    const all = ExcelService.eventTabs;
    final allSelected = _selected.length == all.length;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    AppStrings.exportEventHint,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    allSelected ? _selected.clear() : _selected.addAll(all);
                  }),
                  child: Text(allSelected
                      ? AppStrings.clearSelection
                      : AppStrings.selectAll),
                ),
              ],
            ),
          ),
          for (final tab in all)
            CheckboxListTile(
              dense: true,
              value: _selected.contains(tab),
              onChanged: (v) => setState(() {
                v == true ? _selected.add(tab) : _selected.remove(tab);
              }),
              title: Text(
                tab,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              secondary: Text(
                '${widget.counts[tab] ?? 0}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          all.where(_selected.contains).toList(),
                        ),
                icon: const Icon(Icons.ios_share_rounded),
                label:
                    Text('${AppStrings.exportSelected} (${_selected.length})'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
