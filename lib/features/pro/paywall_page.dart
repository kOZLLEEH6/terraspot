import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Die Paywall. Öffnet sich als Bottom-Sheet, wenn ein PRO-Feature angetippt wird.
///
/// Im MVP ist der Kauf ein Schalter — Stripe (Web) und In-App-Käufe (iOS/Android)
/// hängen genau hier an: `state.setPro(true)` wird durch den Callback des
/// Zahlungsanbieters ersetzt.
class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key, this.feature});

  /// Das Feature, das den Aufruf ausgelöst hat — die Paywall spricht es direkt an.
  final String? feature;

  static void show(BuildContext context, {String? feature}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaywallPage(feature: feature),
    );
  }

  static const _features = [
    ('🔥', 'Heatmap', 'Die heißesten Regionen weltweit auf einen Blick'),
    ('⭐', 'Lohnt-sich-Score', '7-Tage-Prognose aus Wolken, Regen, Wind, Sonnenstand und Mond'),
    ('🌅', 'Golden & Blue Hour', 'Minutengenau für jeden Spot, weltweit'),
    ('🌌', 'Milchstraße & Mond', 'Wann der Himmel wirklich dunkel ist'),
    ('👥', 'Crowd-Prognose', 'Heute sehr voll, morgen leer — plan drumherum'),
    ('💎', 'Hidden Gems', 'Spots mit wenigen Besuchern, die kaum jemand kennt'),
    ('🗺️', 'Routenplaner', 'KI baut dir aus deinen Spots einen Roadtrip'),
    ('📸', 'Fotografie-Modus', 'Sonnenstand, Kompass, Brennweite'),
    ('📚', 'Collections', '100 schönste Wasserfälle Europas & mehr'),
    ('📥', 'Offline-Karten', 'Alle Spots offline — ideal für die Berge'),
    ('♾️', 'Unbegrenzt speichern', 'Statt ${AppState.freeSaveLimit} Orte im Free-Tier'),
    ('🚫', 'Keine Werbung', 'Nie wieder Anzeigen im Feed'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.proGold, AppTheme.accent],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'TERRASPOT PRO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    feature != null
                        ? '$feature ist ein PRO-Feature'
                        : 'Wisse, wann sich der Weg lohnt',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Free zeigt dir, wo ein Spot ist. PRO sagt dir, wann du hinfahren '
                    'solltest — und wann besser nicht.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 26),
                  for (final (emoji, title, desc) in _features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(emoji, style: const TextStyle(fontSize: 17)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                14 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: Color(0xFF25313C))),
              ),
              child: state.isPro
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: AppTheme.proGold, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'PRO ist aktiv',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.proGold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            state.setPro(false);
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'PRO deaktivieren (Demo)',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              state.setPro(true);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.proGold,
                                  content: Text(
                                    'PRO aktiv — Heatmap, Score und Golden Hour sind jetzt frei',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.proGold,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('PRO starten — 9,99 €/Monat'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Demo: schaltet PRO ohne Zahlung frei. '
                          'Hier hängen später Stripe und In-App-Käufe.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
