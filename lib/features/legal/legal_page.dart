import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/legal.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import 'photo_credits_page.dart';

/// Jederzeit erreichbare Rechtstexte (AGB, Datenschutz, Impressum) — rechtlich
/// müssen diese Inhalte dauerhaft abrufbar sein, nicht nur beim ersten Start.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final acceptedLabel = context.watch<AppState>().termsAcceptedLabel;

    return Scaffold(
      appBar: AppBar(title: const Text('Rechtliches')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (acceptedLabel != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, size: 18, color: Color(0xFF3E9C5A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Du hast am $acceptedLabel Uhr zugestimmt '
                      '(Version ${Legal.version}).',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          for (final s in Legal.sections) ...[
            Row(
              children: [
                Text(s.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              s.body,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.textMuted),
              title: const Text('Bildnachweise',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Urheber & Lizenzen der Beispiel-Fotos',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PhotoCreditsPage()),
              ),
            ),
          ),
          Text(
            'Stand: Version ${Legal.version}. Vorlagentext — vor Veröffentlichung '
            'anwaltlich prüfen lassen und Platzhalter ausfüllen.',
            style: TextStyle(
                fontSize: 11, color: AppTheme.textMuted.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
