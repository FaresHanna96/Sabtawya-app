import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/services/location_service.dart';
import '../../core/services/map_link_resolver.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_location.dart';

/// Sets a child's home on the map. Two big buttons do the common things: use
/// where the phone is now (standing at the door on a home visit), or paste a
/// Google Maps link from the clipboard (shortened links are opened for you).
/// Typing a link or coordinates is there too, read once the typing pauses. It
/// shows what was understood, warns when the place looks wrong, and lets the
/// place be looked at on the map or cleared.
class LocationEditor extends StatefulWidget {
  const LocationEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.fetchCurrent,
    this.resolveLink,
    this.readClipboard,
    this.typingPause = const Duration(milliseconds: 700),
  });

  final MapLocation? value;
  final ValueChanged<MapLocation?> onChanged;

  /// Where the phone is. Defaults to the real one; tests give their own.
  final Future<PhoneFix> Function()? fetchCurrent;

  /// Opens a shortened link. Defaults to the server function.
  final Future<ResolvedLink> Function(String text)? resolveLink;

  /// What is on the clipboard. Defaults to the real one.
  final Future<String?> Function()? readClipboard;

  /// How long typing must pause before it is read.
  final Duration typingPause;

  @override
  State<LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<LocationEditor> {
  final _typed = TextEditingController();
  Timer? _pause;
  String? _problem;
  String? _warning;
  bool _busy = false;
  bool _reading = false;
  bool _typing = false;

  @override
  void dispose() {
    _pause?.cancel();
    _typed.dispose();
    super.dispose();
  }

  /// Takes [place] as the answer, with a warning when it looks off.
  void _accept(
    MapLocation place, {
    double? accuracy,
    bool approximate = false,
  }) {
    String? warning;
    if (approximate) {
      warning = AppStrings.locationFromPlacePage;
    } else if (accuracy != null && accuracy > 150) {
      warning = AppStrings.locationWeakFix(accuracy.round());
    } else if (!place.isInEgypt) {
      warning = AppStrings.locationOutsideEgypt;
    }
    setState(() {
      _problem = null;
      _warning = warning;
    });
    widget.onChanged(place);
  }

  /// Reads [text]: a link or coordinates, or a shortened link opened first.
  Future<void> _read(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _problem = null);
      return;
    }
    final place = MapLocation.parse(trimmed);
    if (place != null) {
      _accept(place);
      return;
    }
    if (MapLocation.isShortLink(trimmed)) {
      setState(() {
        _reading = true;
        _problem = null;
      });
      final opened =
          await (widget.resolveLink ?? MapLinkResolver.resolve)(trimmed);
      if (!mounted) return;
      setState(() => _reading = false);
      if (opened.place != null) {
        _accept(opened.place!, approximate: opened.approximate);
      } else {
        setState(() => _problem = opened.opened
            ? AppStrings.locationNamedPlace
            : AppStrings.locationShortLink);
      }
      return;
    }
    setState(() => _problem = AppStrings.locationNotRecognised);
  }

  void _onTyped(String text) {
    _pause?.cancel();
    setState(() => _problem = null);
    // Wait for the typing to pause: "30.0" on the way to "30.0561" is not a
    // place yet.
    _pause = Timer(widget.typingPause, () => _read(text));
  }

  Future<void> _fromClipboard() async {
    String? text;
    try {
      text = widget.readClipboard != null
          ? await widget.readClipboard!()
          : (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {}
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      setState(() => _problem = AppStrings.locationClipboardEmpty);
      return;
    }
    _pause?.cancel();
    _typed.text = text.trim();
    await _read(text);
  }

  Future<void> _useCurrent() async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final fix = await (widget.fetchCurrent ?? LocationService.current)();
      if (!mounted) return;
      _typed.clear();
      _accept(fix.place, accuracy: fix.accuracy);
    } on LocationFailure catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } catch (_) {
      if (mounted) setState(() => _problem = AppStrings.locationFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clear() {
    _pause?.cancel();
    _typed.clear();
    setState(() {
      _problem = null;
      _warning = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.value;
    final working = _busy || _reading;
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
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          place.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
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
            if (_warning != null) _Note(_warning!, AppColors.warning),
          ],
          const SizedBox(height: 12),
          _Option(
            icon: Icons.my_location_rounded,
            title: _busy
                ? AppStrings.locationLocating
                : AppStrings.locationUseCurrent,
            subtitle: AppStrings.locationUseCurrentHint,
            busy: _busy,
            compact: place != null,
            filled: true,
            onTap: working ? null : _useCurrent,
          ),
          const SizedBox(height: 8),
          _Option(
            icon: Icons.content_paste_rounded,
            title: _reading
                ? AppStrings.locationReadingLink
                : AppStrings.locationPasteButton,
            subtitle: AppStrings.locationHowTo,
            busy: _reading,
            compact: place != null,
            filled: false,
            onTap: working ? null : _fromClipboard,
          ),
          if (_problem != null) _Note(_problem!, AppColors.danger),
          const SizedBox(height: 4),
          if (!_typing && _typed.text.isEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _typing = true),
                child: const Text(AppStrings.locationTypeInstead),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextField(
                controller: _typed,
                onChanged: _onTyped,
                onSubmitted: _read,
                autofocus: _typing && _typed.text.isEmpty,
                keyboardType: TextInputType.text,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: AppStrings.locationPasteLabel,
                  hintText: 'https://maps.app.goo.gl/…  /  30.0561, 31.3416',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 12.5, color: AppColors.readable(color), height: 1.4),
        ),
      );
}

/// A big, plain choice: what it does in bold, how in a line under it. Once a
/// place is set the choices shrink to plain buttons for changing it.
class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.compact,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool busy;
  final bool compact;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final leading = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Icon(icon, size: 24);
    if (compact) {
      return OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        icon: leading,
        label: Text(title),
      );
    }
    final fg = filled ? Colors.white : AppColors.navy;
    return Material(
      color: filled ? AppColors.navy : AppColors.navy.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(color: fg),
                child: leading,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: fg,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
