import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_location.dart';

/// The child's home on the map, on their page: the address (or the
/// coordinates) with a button to see it on the map and one for directions.
/// With no location saved, someone who may edit gets a prompt to add one;
/// everybody else sees nothing.
class ChildLocationCard extends StatelessWidget {
  const ChildLocationCard({
    super.key,
    required this.location,
    this.address,
    this.onSet,
  });

  final MapLocation? location;

  /// The written address, shown under the title when there is one.
  final String? address;

  /// Opens the editor; null for who may not edit.
  final VoidCallback? onSet;

  @override
  Widget build(BuildContext context) {
    final place = location;
    if (place == null) {
      if (onSet == null) return const SizedBox.shrink();
      return _AddPrompt(onTap: onSet!);
    }
    final written = (address ?? '').trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: AppColors.coral, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.locationTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  written.isEmpty ? place.label : written,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MapAction(
            tooltip: AppStrings.locationOpen,
            icon: Icons.map_rounded,
            color: AppColors.navy,
            onTap: () =>
                launchUrl(place.viewUri, mode: LaunchMode.externalApplication),
          ),
          const SizedBox(width: 10),
          _MapAction(
            tooltip: AppStrings.locationDirections,
            icon: Icons.directions_rounded,
            color: AppColors.success,
            onTap: () => launchUrl(place.directionsUri,
                mode: LaunchMode.externalApplication),
          ),
        ],
      ),
    );
  }
}

class _AddPrompt extends StatelessWidget {
  const _AddPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.coral.withValues(alpha: 0.4),
            ),
            color: AppColors.coral.withValues(alpha: 0.05),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_location_alt_outlined,
                  color: AppColors.coral, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.locationAddPrompt,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.coral,
                  ),
                ),
              ),
              Icon(AppIcons.forward, color: AppColors.coral),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round 48 px button with a tinted fill, as on the contact card.
class _MapAction extends StatelessWidget {
  const _MapAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: color.withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: color, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
