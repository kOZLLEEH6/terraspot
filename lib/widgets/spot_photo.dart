import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/models/category.dart';
import '../core/models/spot.dart';

/// Zeigt ein Spot-Foto. Fällt auf einen Kategorie-Farbverlauf mit Emoji zurück,
/// wenn das Bild fehlt — so sieht die UI nie kaputt aus, sondern absichtlich.
class SpotPhoto extends StatelessWidget {
  const SpotPhoto({
    super.key,
    required this.spot,
    this.index = 0,
    this.fit = BoxFit.cover,
  });

  final Spot spot;
  final int index;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // Selbst erstellte Spots haben ein lokales Foto (Datei bzw. Blob-URL im Web).
    final local = spot.localPhotoPath;
    if (local != null && index == 0) {
      final image = kIsWeb ? Image.network(local, fit: fit) : Image.file(File(local), fit: fit);
      return _Frame(spot: spot, child: image);
    }

    if (index >= spot.photoUrls.length) {
      return _Fallback(category: spot.category);
    }

    return _Frame(
      spot: spot,
      child: Image.asset(
        spot.photoUrls[index],
        fit: fit,
        errorBuilder: (_, _, _) => _Fallback(category: spot.category),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.spot, required this.child});

  final Spot spot;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: child);
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.category});

  final SpotCategory category;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              category.color.withValues(alpha: 0.85),
              category.color.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: Center(
          child: Text(category.emoji, style: const TextStyle(fontSize: 44)),
        ),
      );
}

/// Dunkler Verlauf über dem Foto, damit weiße Schrift immer lesbar bleibt.
class PhotoScrim extends StatelessWidget {
  const PhotoScrim({super.key, this.opacity = 0.75});

  final double opacity;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: opacity * 0.5),
              Colors.black.withValues(alpha: opacity),
            ],
            stops: const [0.35, 0.72, 1.0],
          ),
        ),
      );
}
