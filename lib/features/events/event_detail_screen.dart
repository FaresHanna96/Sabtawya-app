import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/event.dart';
import '../../data/repositories/event_repository.dart';
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

  final _sectionKey =
      GlobalKey<AsyncSectionState<List<ChildEventBalance>>>();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<ChildEventBalance>> _load() =>
      _repository.balances(widget.event.id);

  Future<void> _reload() =>
      _sectionKey.currentState?.reload() ?? Future.value();

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

            final partial = balances
                .where((b) => b.totalPaid > 0 && b.remaining > 0)
                .toList();
            final notPaid =
                balances.where((b) => b.totalPaid == 0).toList();
            final fullPaid =
                balances.where((b) => b.remaining <= 0).toList();

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${AppStrings.collected}: ${totalCollected.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.olive,
                                ),
                              ),
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
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor:
                                  AppColors.navy.withValues(alpha: 0.1),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      AppColors.olive),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Filter tab bar with live counts
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: '${AppStrings.all} (${balances.length})'),
                    Tab(text: '${AppStrings.partialPay} (${partial.length})'),
                    Tab(text: '${AppStrings.notPaidTab} (${notPaid.length})'),
                    Tab(text: '${AppStrings.paidInFull} (${fullPaid.length})'),
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
                          filtered = partial;
                        case 2:
                          filtered = notPaid;
                        case 3:
                          filtered = fullPaid;
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
                        ..sort((a, b) => getClassName(b.key)
                            .compareTo(getClassName(a.key)));

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          // Estimated payment summary for the filtered group
                          if (_tabController.index > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Wrap(
                                spacing: 16,
                                children: [
                                  _MiniStat(
                                    label: AppStrings.expected,
                                    value:
                                        '${filteredExpected.toStringAsFixed(0)} ج.م',
                                    color: AppColors.muted,
                                  ),
                                  _MiniStat(
                                    label: AppStrings.collected,
                                    value:
                                        '${filteredCollected.toStringAsFixed(0)} ج.م',
                                    color: AppColors.olive,
                                  ),
                                  if (filteredRemaining > 0)
                                    _MiniStat(
                                      label: AppStrings.remaining,
                                      value:
                                          '${filteredRemaining.toStringAsFixed(0)} ج.م',
                                      color: AppColors.danger,
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
                              (b) => _BalanceRow(
                                balance: b,
                                onTap: () => _openPayments(b),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
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

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance, required this.onTap});

  final ChildEventBalance balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPaid = balance.remaining <= 0;
    final isPartial = !isPaid && balance.totalPaid > 0;

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
              if (isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
      final p = await _repository.payments(
          widget.event.id, widget.balance.childId);
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
        ? balance.cost -
            _payments!.fold<double>(0, (s, p) => s + p.amount)
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
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')),
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
                if (n > widget.maxAmount) return AppStrings.paymentAmountExceeds;
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
            final amount =
                double.tryParse(_amountController.text.trim()) ?? 0;
            Navigator.of(context)
                .pop((amount: amount, method: _method));
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
