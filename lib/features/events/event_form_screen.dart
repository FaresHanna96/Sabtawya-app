import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/utils/ui.dart';
import '../../data/models/event.dart';
import '../../data/repositories/event_repository.dart';

class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final Event? event;

  bool get isEdit => event != null;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  static const _repository = EventRepository();

  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _description =
      TextEditingController(text: widget.event?.description ?? '');
  late final _cost = TextEditingController(
    text: widget.event != null
        ? widget.event!.cost.toStringAsFixed(
            widget.event!.cost == widget.event!.cost.truncateToDouble() ? 0 : 2)
        : '',
  );

  late DateTime _eventDate = widget.event?.eventDate ?? DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: AppStrings.eventDateLabel,
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final title = _title.text.trim();
    final description = _description.text.trim();
    final cost = double.tryParse(_cost.text.trim()) ?? 0;

    final saved = await Ui.runGuarded(
      context,
      () async {
        if (widget.isEdit) {
          await _repository.updateEvent(
            widget.event!.id,
            title: title,
            eventDate: _eventDate,
            cost: cost,
            description: description,
          );
        } else {
          await _repository.createEvent(
            title: title,
            eventDate: _eventDate,
            cost: cost,
            description: description.isEmpty ? null : description,
          );
        }
      },
    );

    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? AppStrings.editEvent : AppStrings.addEvent),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: AppStrings.eventTitleLabel,
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? AppStrings.eventTitleRequired
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: AppStrings.eventDescription,
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: AppStrings.eventDateLabel,
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixIcon: Icon(Icons.edit_calendar_outlined, size: 20),
                  ),
                  child: Text(
                    AppDateUtils.formatDate(_eventDate),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: AppStrings.eventCost,
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null) return AppStrings.eventCostRequired;
                  if (n <= 0) return AppStrings.eventCostInvalid;
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text(AppStrings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
