import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/legal.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Erscheint beim allerersten Start (und nach wesentlichen Änderungen der
/// Bedingungen). Der Nutzer muss die Texte bis zum Ende scrollen und aktiv
/// zustimmen, bevor die App nutzbar ist — die Zustimmung wird gespeichert.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key});

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _acceptedTerms = false;
  bool _confirmedAge = false;

  bool get _canContinue => _reachedEnd && _acceptedTerms && _confirmedAge;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!_reachedEnd &&
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40) {
        setState(() => _reachedEnd = true);
      }
    });
    // Falls der Text kürzer als der Bildschirm ist: sofort freischalten.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients &&
          _scroll.position.maxScrollExtent <= 0 &&
          !_reachedEnd) {
        setState(() => _reachedEnd = true);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Kopf mit Logo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/branding/icon.png',
                        width: 46, height: 46, cacheWidth: 138),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Willkommen bei TerraSpot',
                            style: TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w800)),
                        Text('Nutzungsbedingungen & Datenschutz',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Text('⚠️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        Legal.summary,
                        style: TextStyle(fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollbare Bedingungen
            Expanded(
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    for (final s in Legal.sections) ...[
                      Row(
                        children: [
                          Text(s.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.body,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Stand: Version ${Legal.version}. Vorlagentext — vor '
                      'Veröffentlichung anwaltlich prüfen lassen.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Zustimmen-Leiste
            Container(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 14 + MediaQuery.of(context).padding.bottom * 0),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: Color(0xFF25313C))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_reachedEnd)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward,
                              size: 14, color: AppTheme.textMuted),
                          SizedBox(width: 6),
                          Text(
                            'Bitte bis zum Ende lesen, um fortzufahren',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  _ConsentCheck(
                    value: _acceptedTerms,
                    enabled: _reachedEnd,
                    label:
                        'Ich habe die Nutzungsbedingungen und den Haftungsausschluss '
                        'gelesen und akzeptiere sie.',
                    onChanged: (v) => setState(() => _acceptedTerms = v),
                  ),
                  _ConsentCheck(
                    value: _confirmedAge,
                    enabled: _reachedEnd,
                    label:
                        'Ich bin mindestens 18 Jahre alt (oder habe die Zustimmung '
                        'eines Erziehungsberechtigten).',
                    onChanged: (v) => setState(() => _confirmedAge = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _canContinue
                          ? () => context.read<AppState>().acceptTerms()
                          : null,
                      child: const Text('Zustimmen & starten'),
                    ),
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

/// Eine Zustimmungs-Zeile mit Häkchen. Vor dem Durchlesen deaktiviert.
class _ConsentCheck extends StatelessWidget {
  const _ConsentCheck({
    required this.value,
    required this.enabled,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: value,
                  onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                  activeColor: AppTheme.accent,
                  checkColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 12.5, height: 1.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
