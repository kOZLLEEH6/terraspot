import 'package:flutter/material.dart';

/// Die 11 Spot-Kategorien aus dem Konzept. Farbe + Emoji steuern die Pins auf der Karte.
enum SpotCategory {
  sunrise('Sonnenaufgang', '🌅', Color(0xFFFF8A3D)),
  viewpoint('Aussicht', '🌄', Color(0xFFE05A47)),
  nightSky('Nachthimmel', '🌌', Color(0xFF5B4FE0)),
  hiking('Wanderung', '🥾', Color(0xFF3E7C4A)),
  camping('Camping', '🏕️', Color(0xFF7A5C3E)),
  flowers('Blumen', '🌸', Color(0xFFE86AA8)),
  autumn('Herbst', '🍂', Color(0xFFC96A1E)),
  winter('Winter', '❄️', Color(0xFF4FA8D8)),
  waterfall('Wasserfall', '🌊', Color(0xFF1E9BB0)),
  beach('Strand', '🏖️', Color(0xFFF0C04A)),
  campfire('Lagerfeuer', '🔥', Color(0xFFD94A2B));

  const SpotCategory(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;

  static SpotCategory fromName(String name) =>
      SpotCategory.values.firstWhere((c) => c.name == name,
          orElse: () => SpotCategory.viewpoint);
}

enum Difficulty {
  easy('Leicht', Color(0xFF3E9C5A)),
  medium('Mittel', Color(0xFFE0A020)),
  hard('Schwer', Color(0xFFD9452B));

  const Difficulty(this.label, this.color);

  final String label;
  final Color color;

  static Difficulty fromName(String name) =>
      Difficulty.values.firstWhere((d) => d.name == name,
          orElse: () => Difficulty.medium);
}
