import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/spot_photo.dart';

/// Die Karte, die beim Tippen auf einen Pin von unten einfährt.
class SpotPreviewCard extends StatelessWidget {
  const SpotPreviewCard({
    super.key,
    required this.spot,
    required this.onOpen,
    required this.onClose,
  });

  final Spot spot;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return GestureDetector(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 108,
              height: 108,
              child: SpotPhoto(spot: spot),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(spot.category.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            spot.category.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w800,
                              color: spot.category.color,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: onClose,
                          child: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${spot.region}, ${spot.country}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 15, color: AppTheme.proGold),
                        const SizedBox(width: 2),
                        Text(
                          spot.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          spot.bestTimeOfDay,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.terrain, size: 14, color: spot.difficulty.color),
                        const SizedBox(width: 3),
                        Text(
                          spot.hikeLabel,
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                        ),
                        const Spacer(),
                        if (state.isPro && spot.isHiddenGem)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentAlt.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '💎',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
