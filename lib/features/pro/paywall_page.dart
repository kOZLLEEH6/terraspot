import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Die Paywall. Öffnet sich als Bottom-Sheet, wenn ein PRO-Feature angetippt wird.
///
/// Im MVP ist der Kauf eine Zustandsänderung (`purchasePro`/`cancelSubscription`).
/// Die echten App-Store-/Play-Käufe hängen genau hier an: ihr Erfolgs-Callback
/// ruft dann `purchasePro`, die Store-Kündigung spiegelt sich in `cancelSubscription`.
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
              child: _SubscriptionControls(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

/// Der untere Steuerbereich der Paywall — je nach Abo-Status: kaufen,
/// kündigen (bleibt bis Monatsende) oder Verlängerung wieder aktivieren.
class _SubscriptionControls extends StatelessWidget {
  const _SubscriptionControls({required this.state});

  final AppState state;

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.proGold,
        content: Text(msg,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w700)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Zahlendes Abo aktiv?
    if (state.hasPaidPro) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.proGold, size: 20),
              const SizedBox(width: 8),
              Text(
                state.autoRenew
                    ? 'PRO aktiv — verlängert sich automatisch'
                    : 'PRO aktiv bis ${state.proUntilLabel}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.proGold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            state.autoRenew
                ? 'Nächste Abbuchung am ${state.proUntilLabel} · jederzeit kündbar'
                : 'Kündigung aktiv — läuft am ${state.proUntilLabel} aus und wird '
                    'nicht verlängert.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
          if (state.autoRenew)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  state.cancelSubscription();
                  _toast(context,
                      'Abo gekündigt — PRO bleibt bis ${state.proUntilLabel} aktiv.');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Abo kündigen'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  state.resumeSubscription();
                  _toast(context, 'Automatische Verlängerung wieder aktiv.');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.proGold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Verlängerung wieder aktivieren'),
              ),
            ),
          if (state.isOwner)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Als Owner hast du dauerhaft Zugriff auf alle Funktionen.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ),
        ],
      );
    }

    // Owner ohne laufendes Abo: Hinweis + trotzdem Testkauf möglich.
    // Sonst: normaler Kauf-Button.
    final store = state.billingAvailable;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              if (store) {
                // Echter Store-Kauf — PRO wird über den Purchase-Stream frei-
                // geschaltet, nicht hier direkt.
                final started = await state.buyProViaStore();
                if (context.mounted && !started) {
                  _toast(context, 'Kauf konnte nicht gestartet werden.');
                }
              } else {
                state.purchasePro();
                if (context.mounted) {
                  _toast(context,
                      'PRO gestartet — verlängert sich monatlich, jederzeit kündbar.');
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.proGold,
              foregroundColor: Colors.black,
            ),
            child: Text('PRO starten — ${state.proPriceDisplay}'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Verlängert sich automatisch um 1 Monat. Jederzeit kündbar — nach der '
          'Kündigung bleibt PRO bis zum Ende des bezahlten Zeitraums.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        if (store)
          TextButton(
            onPressed: () => state.restorePurchases(),
            child: const Text('Käufe wiederherstellen',
                style: TextStyle(fontSize: 12)),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Demo: ohne echte Zahlung. Auf dem Handy mit eingerichtetem '
              'Store-Produkt läuft der echte Kauf.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
          ),
      ],
    );
  }
}
