import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_location.dart';

/// Sets a child's home on the map, in the child's form: paste a Google Maps
/// link or the coordinates (read as they are typed), or take the phone's
/// current position (standing at the door on a home visit). It shows what was
/// understood, and lets the place be looked at on the map or cleared.
class LocationEditor extends StatefulWidget {
  const LocationEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.fetchCurrent,
  });

  final MapLocation? value;
  final ValueChanged<MapLocation?> onChanged;

  /// Where the phone is. Defaults to the real one; tests give their own.
  final Future<MapLocation> Function()? fetchCurrent;

  @override
  State<LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<LocationEditor> {
  final _paste = TextEditingController();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _read(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _problem = null);
      return;
    }
    final place = MapLocation.parse(trimmed);
    if (place != null) {
      setState(() => _problem = null);
      widget.onChanged(place);
      return;
    }
    setState(() {
      _problem = MapLocation.isShortLink(trimmed)
          ? AppStrings.locationShortLink
          : AppStrings.locationNotRecognised;
    });
  }

  Future<void> _fromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) return;
    _paste.text = text.trim();
    _read(text);
  }

  Future<void> _useCurrent() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final place = await (widget.fetchCurrent ?? LocationService.current)();
      if (!mounted) return;
      _paste.clear();
      widget.onChanged(place);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } catch (_) {
      if (mounted) setState(() => _problem = AppStrings.locationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    _paste.clear();
    setState(() => _problem = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.12)),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_drop_outlined, color: AppColors.coral),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  AppStrings.locationTitle,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              if (place != null)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(AppStrings.locationClear),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.danger),
                ),
            ],
          ),
          if (place != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        place.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(place.viewUri,
                        mode: LaunchMode.externalApplication),
                    child: const Text(AppStrings.locationOpen),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _paste,
            onChanged: _read,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: AppStrings.locationPasteLabel,
              hintText: 'https://maps.google.com/…  /  30.0561, 31.3416',
              errorText: _problem,
              errorMaxLines: 3,
              prefixIcon: const Icon(Icons.link_rounded),
              suffixIcon: IconButton(
                tooltip: AppStrings.locationPasteFromClipboard,
                icon: const Icon(Icons.content_paste_rounded),
                onPressed: _fromClipboard,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _useCurrent,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded),
            label: Text(
              _busy
                  ? AppStrings.locationLocating
                  : AppStrings.locationUseCurrent,
            ),
          ),
        ],
      ),
    );
  }
}
