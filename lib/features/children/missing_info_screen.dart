import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_sort.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/class_filter_chips.dart';
import '../../core/widgets/class_group_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';
import '../../data/repositories/child_repository.dart';
import '../../state/session_controller.dart';
import 'child_form_screen.dart';
import 'child_profile_screen.dart';
import 'missing_info.dart';

/// بيانات ناقصة: the children whose record has gaps, the birthday first. Pick
/// what to look for, tap a child to fill it in, or ask the family on WhatsApp.
/// A servant sees their own classes only (row level security), an admin all.
class MissingInfoScreen extends StatefulWidget {
  const MissingInfoScreen({super.key});

  @override
  State<MissingInfoScreen> createState() => _MissingInfoScreenState();
}

class _MissingInfoScreenState extends State<MissingInfoScreen> {
  static const _repository = ChildRepository();

  List<Child> _children = const <Child>[];
  bool _loading = true;
  String? _error;

  /// What is being looked for; the birthday to begin with, null for anything.
  MissingField? _field = MissingField.birthDate;
  Set<String> _classIds = <String>{};

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
      final children = await _repository.all();
      if (!mounted) return;
      setState(() {
        _children = children;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _open(Child child) async {
    final session = context.read<SessionController>();
    // The general servant reads; everybody else can fill the gaps in.
    final Widget screen = session.isGeneralServant
        ? ChildProfileScreen(childId: child.id)
        : ChildFormScreen(child: child);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final classNames = {
      for (final c in session.myClasses) c.classId: c.className,
    };
    final inClasses = [
      for (final c in _children)
        if (_classIds.isEmpty || _classIds.contains(c.classId)) c,
    ];
    final counts = MissingInfo.counts(inClasses);
    final shown = MissingInfo.filter(inClasses, _field);
    final anyMissing = MissingInfo.filter(inClasses, null).length;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.missingInfoTitle)),
      body: SafeArea(
        child: _loading
            ? const SkeletonList()
            : _error != null
                ? EmptyState(
                    title: AppStrings.loadFailed,
                    body: _error,
                    icon: Icons.error_outline_rounded,
                    action: FilledButton(
                      onPressed: _load,
                      child: const Text(AppStrings.retry),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        _Progress(
                          field: _field,
                          total: inClasses.length,
                          missing:
                              _field == null ? anyMissing : counts[_field]!,
                        ),
                        const SizedBox(height: 12),
                        _FieldChips(
                          counts: counts,
                          anyMissing: anyMissing,
                          selected: _field,
                          onSelected: (f) => setState(() => _field = f),
                        ),
                        if (session.myClasses.length > 1) ...[
                          const SizedBox(height: 8),
                          ClassFilterChips(
                            classes: [
                              for (final c in session.myClasses)
                                ClassFilterOption(
                                    id: c.classId, name: c.className),
                            ],
                            selectedIds: _classIds,
                            onChanged: (ids) => setState(() => _classIds = ids),
                          ),
                        ],
                        const SizedBox(height: 4),
                        if (shown.isEmpty)
                          EmptyState(
                            title: AppStrings.missingNone,
                            body: _field == null
                                ? AppStrings.missingNoneAny
                                : AppStrings.missingNoneField(_field!.label),
                            icon: Icons.check_circle_outline_rounded,
                          )
                        else
                          ..._grouped(shown, classNames, session),
                      ],
                    ),
                  ),
      ),
    );
  }

  /// The children under their class, by name inside each class.
  List<Widget> _grouped(
    List<Child> shown,
    Map<String, String> classNames,
    SessionController session,
  ) {
    final byClass = <String, List<Child>>{};
    for (final c in shown) {
      (byClass[c.classId] ??= <Child>[]).add(c);
    }
    final ids = byClass.keys.toList()
      ..sort((a, b) =>
          ArabicSort.compare(classNames[a] ?? '', classNames[b] ?? ''));
    final servantName = session.displayName;
    return [
      for (final id in ids) ...[
        ClassGroupHeader(
          name: classNames[id] ?? '',
          count: byClass[id]!.length,
        ),
        for (final child
            in (byClass[id]!
              ..sort((a, b) => ArabicSort.compare(a.fullName, b.fullName))))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MissingInfoTile(
              child: child,
              servantName: servantName,
              onTap: () => _open(child),
            ),
          ),
      ],
    ];
  }
}

/// "اكتمل 12 من 20": how far the filled-in part is, as a bar.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.field,
    required this.total,
    required this.missing,
  });

  final MissingField? field;
  final int total;
  final int missing;

  @override
  Widget build(BuildContext context) {
    final done = total - missing;
    final ratio = total == 0 ? 1.0 : done / total;
    final color = ratio >= 0.9
        ? AppColors.success
        : ratio >= 0.6
            ? AppColors.warning
            : AppColors.danger;
    return SectionCard(
      icon: Icons.rule_rounded,
      title: field == null
          ? AppStrings.missingProgressAll
          : AppStrings.missingProgressField(field!.label),
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                AppStrings.missingCount(missing),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: missing == 0 ? AppColors.success : color,
                ),
              ),
              const Spacer(),
              Text(
                AppStrings.missingDoneOf(done, total),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

/// What to look for: anything, or one field, each with how many children miss it.
class _FieldChips extends StatelessWidget {
  const _FieldChips({
    required this.counts,
    required this.anyMissing,
    required this.selected,
    required this.onSelected,
  });

  final Map<MissingField, int> counts;
  final int anyMissing;
  final MissingField? selected;
  final ValueChanged<MissingField?> onSelected;

  @override
  Widget build(BuildContext context) {
    // One row that scrolls sideways: seven wrapped chips took half the screen.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FieldChip(
            label: AppStrings.missingAny,
            count: anyMissing,
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final f in MissingField.values) ...[
            const SizedBox(width: 8),
            FieldChip(
              label: f.label,
              count: counts[f] ?? 0,
              icon: f.icon,
              isSelected: selected == f,
              onTap: () => onSelected(f),
            ),
          ],
        ],
      ),
    );
  }
}

/// One filter: its icon and name, and a small badge with how many children
/// miss it. A filter with nothing missing is quieter and shows a tick instead
/// of "0", so the eye goes to what still needs work.
@visibleForTesting
class FieldChip extends StatelessWidget {
  const FieldChip({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final done = count == 0;
    final fg = isSelected ? Colors.white : AppColors.navy;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, $count',
      child: Opacity(
        opacity: done && !isSelected ? 0.6 : 1,
        child: Material(
          color: isSelected ? AppColors.navy : AppColors.card,
          shape: StadiumBorder(
            side: BorderSide(
              color: isSelected
                  ? AppColors.navy
                  : AppColors.navy.withValues(alpha: 0.15),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints:
                        const BoxConstraints(minWidth: 24, minHeight: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : done
                              ? AppColors.success.withValues(alpha: 0.14)
                              : AppColors.coral.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color:
                                isSelected ? Colors.white : AppColors.success,
                          )
                        : Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isSelected ? Colors.white : AppColors.coral,
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

/// One child with what is missing from the record, and a way to ask for it.
@visibleForTesting
class MissingInfoTile extends StatelessWidget {
  const MissingInfoTile({
    super.key,
    required this.child,
    required this.servantName,
    required this.onTap,
  });

  final Child child;
  final String servantName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = MissingInfo.of(child);
    final number = WhatsApp.numberFor(child);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final f in missing)
                          _GapChip(
                            label: f.label,
                            // The birthday is the one that matters most.
                            strong: f == MissingField.birthDate,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (number != null)
                IconButton(
                  tooltip: AppStrings.missingAskFamily,
                  icon: const WhatsAppIcon(size: 24),
                  onPressed: () => launchUrl(
                    WhatsApp.link(
                      number,
                      WhatsApp.missingInfoMessage(
                        childName: child.fullName,
                        servantName: servantName,
                        missing: [for (final f in missing) f.label],
                      ),
                    ),
                    mode: LaunchMode.externalApplication,
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

class _GapChip extends StatelessWidget {
  const _GapChip({required this.label, required this.strong});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = strong ? AppColors.danger : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: strong ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
