import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../search/search_page.dart';
import '../spot/spot_detail_page.dart';

/// Der Owner-Bereich (nur für dich): Gift-Codes erzeugen, Meldungen bearbeiten,
/// gesperrte Nutzer verwalten.
class OwnerPanelPage extends StatelessWidget {
  const OwnerPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.shield, size: 18, color: AppTheme.proGold),
              SizedBox(width: 8),
              Text('Owner-Bereich'),
            ],
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.proGold,
            labelColor: AppTheme.proGold,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: [
              const Tab(text: 'Gift-Codes'),
              Tab(text: 'Meldungen (${state.openReports.length})'),
              Tab(text: 'Gesperrt (${state.blockedUsers.length})'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GiftCodesTab(),
            _ReportsTab(),
            _BlockedTab(),
          ],
        ),
      ),
    );
  }
}

// --- Tab 1: Gift-Codes ---

class _GiftCodesTab extends StatelessWidget {
  const _GiftCodesTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final codes = state.giftCodes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const Text(
          'Verschenke PRO',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Erzeuge einen Code und gib ihn weiter. Wer ihn einlöst, bekommt PRO für '
          'den gewählten Zeitraum.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final months in [1, 3, 12])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton(
                    onPressed: () async {
                      final code = await state.generateGiftCode(months);
                      if (context.mounted) {
                        _showNewCode(context, code.code, months);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.surfaceHigh,
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$months',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.proGold,
                          ),
                        ),
                        Text(months == 1 ? 'Monat' : 'Monate',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Erzeugte Codes (${codes.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (codes.isEmpty)
          const _Empty(emoji: '🎁', text: 'Noch keine Codes erzeugt.')
        else
          for (final c in codes)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.redeemed
                      ? Colors.transparent
                      : AppTheme.proGold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.code,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          decoration:
                              c.redeemed ? TextDecoration.lineThrough : null,
                          color: c.redeemed
                              ? AppTheme.textMuted
                              : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        c.redeemed
                            ? 'eingelöst'
                            : '${c.months} ${c.months == 1 ? "Monat" : "Monate"} PRO',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.redeemed
                              ? const Color(0xFF3E9C5A)
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!c.redeemed)
                    IconButton(
                      tooltip: 'Kopieren',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code kopiert')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 18),
                    ),
                  IconButton(
                    tooltip: 'Löschen',
                    onPressed: () => state.deleteGiftCode(c.code),
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  void _showNewCode(BuildContext context, String code, int months) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Code erzeugt 🎁'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$months ${months == 1 ? "Monat" : "Monate"} PRO',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppTheme.proGold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code kopiert')),
              );
            },
            child: const Text('Kopieren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }
}

// --- Tab 2: Meldungen ---

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reports = state.openReports;

    if (reports.isEmpty) {
      return const _Empty(emoji: '✅', text: 'Keine offenen Meldungen. Alles ruhig.');
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = reports[i];
        final spot = state.reportedSpot(r);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, size: 16, color: Color(0xFFFF6B6B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.reason,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (spot != null)
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SpotDetailPage(spotId: spot.id),
                    ),
                  ),
                  child: Text(
                    '„${spot.title}" von ${spot.authorName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              else
                const Text('(Spot nicht mehr vorhanden)',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
              Text(
                'gemeldet von ${r.reporter}',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => state.dismissReport(r.id),
                      child: const Text('Verwerfen'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => state.setSpotBlocked(r.spotId, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                      ),
                      child: const Text('Spot sperren'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- Tab 3: Gesperrte ---

class _BlockedTab extends StatelessWidget {
  const _BlockedTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final users = state.blockedUsers.toList();
    final spots = state.blockedSpots
        .map((id) => state.spotById(id))
        .whereType<Spot>()
        .toList();

    if (users.isEmpty && spots.isEmpty) {
      return const _Empty(emoji: '🔓', text: 'Nichts gesperrt.');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (users.isNotEmpty) ...[
          const Text('Gesperrte Nutzer',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final u in users)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_off, size: 18, color: Color(0xFFFF6B6B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(u,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => state.setUserBlocked(u, false),
                    child: const Text('Entsperren'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
        if (spots.isNotEmpty) ...[
          const Text('Gesperrte Spots',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final s in spots)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SpotListTile(
                spot: s,
                trailing: IconButton(
                  tooltip: 'Entsperren',
                  onPressed: () => state.setSpotBlocked(s.id, false),
                  icon: const Icon(Icons.visibility, size: 18),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
}
