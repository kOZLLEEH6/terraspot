import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/photo_credits.dart';
import '../../core/theme.dart';

/// Bildnachweise für die gebündelten Beispiel-Fotos. Rechtlich nötig, weil die
/// Fotos unter CC-BY-/CC-BY-SA-Lizenzen stehen und eine Namensnennung verlangen.
class PhotoCreditsPage extends StatelessWidget {
  const PhotoCreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildnachweise')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Die mitgelieferten Beispiel-Fotos stammen von Wikimedia Commons und '
              'stehen unter freien Lizenzen (CC BY, CC BY-SA, CC0 oder gemeinfrei), '
              'die eine kommerzielle Nutzung mit Namensnennung erlauben. Urheber, '
              'Lizenz und Quelle sind unten aufgeführt. Von Nutzern hochgeladene '
              'Fotos sind hier nicht enthalten.',
              style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textMuted),
            ),
          ),
          for (final c in photoCredits)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '© ${c.author}',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${c.license} · ${c.file}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (c.source.isNotEmpty)
                    IconButton(
                      tooltip: 'Quelle öffnen',
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => launchUrl(Uri.parse(c.source),
                          mode: LaunchMode.externalApplication),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
