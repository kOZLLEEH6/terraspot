import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../pro/collections_page.dart';
import '../pro/paywall_page.dart';
import '../pro/trip_planner_page.dart';
import '../search/search_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            onPressed: () => PaywallPage.show(context),
            icon: Icon(
              Icons.workspace_premium,
              color: state.isPro ? AppTheme.proGold : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Header(state: state),
          const SizedBox(height: 20),
          _LevelCard(state: state),
          const SizedBox(height: 20),

          if (!state.isPro) ...[
            _ProUpsell(),
            const SizedBox(height: 20),
          ] else ...[
            _ProTools(),
            const SizedBox(height: 20),
          ],

          const _SectionTitle('Badges'),
          const SizedBox(height: 12),
          for (final badge in state.badges)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BadgeTile(badge: badge),
            ),
          const SizedBox(height: 20),

          _SectionTitle('Gespeicherte Orte (${state.savedSpots.length})'),
          if (!state.isPro)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${state.savedSpots.length} von ${AppState.freeSaveLimit} im Free-Tier',
                style: TextStyle(
                  fontSize: 12,
                  color: state.saveLimitReached ? AppTheme.accent : AppTheme.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (state.savedSpots.isEmpty)
            const _Empty(
              emoji: '🔖',
              text: 'Noch nichts gespeichert.\nTipp auf das Lesezeichen bei einem Spot.',
            )
          else
            for (final s in state.savedSpots)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SpotListTile(spot: s),
              ),
          const SizedBox(height: 20),

          _SectionTitle('Meine Spots (${state.mySpots.length})'),
          const SizedBox(height: 12),
          if (state.mySpots.isEmpty)
            const _Empty(
              emoji: '📍',
              text: 'Du hast noch keinen Spot gepostet.',
            )
          else
            for (final s in state.mySpots)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SpotListTile(spot: s),
              ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentAlt],
              ),
              border: state.isPro
                  ? Border.all(color: AppTheme.proGold, width: 2.5)
                  : null,
            ),
            child: const Center(
              child: Text(
                'AH',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      state.currentUserName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    if (state.isPro) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.proGold,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Counter(value: '${state.mySpots.length}', label: 'Spots'),
                    _Counter(value: '${state.likesReceived}', label: 'Likes'),
                    _Counter(value: '${state.countriesVisited.length}', label: 'Länder'),
                    const _Counter(value: '284', label: 'Follower'),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.accent.withValues(alpha: 0.22),
              AppTheme.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      '${state.level}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${state.level} · ${state.levelTitle}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${state.xp} XP',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${(state.levelProgress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.levelProgress,
                minHeight: 7,
                backgroundColor: AppTheme.bg,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Noch ${500 - (state.xp % 500)} XP bis Level ${state.level + 1}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
}

class _ProUpsell extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => PaywallPage.show(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppTheme.proGold.withValues(alpha: 0.2),
                AppTheme.surface,
              ],
            ),
            border: Border.all(color: AppTheme.proGold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: AppTheme.proGold, size: 26),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TerraSpot PRO',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Heatmap, Wetter-Score, Golden Hour, Routenplaner',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.proGold),
            ],
          ),
        ),
      );
}

class _ProTools extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _ToolCard(
              emoji: '🗺️',
              label: 'Routenplaner',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TripPlannerPage()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ToolCard(
              emoji: '📚',
              label: 'Collections',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CollectionsPage()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ToolCard(
              emoji: '📥',
              label: 'Offline',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Offline-Karten: noch nicht gebaut — braucht einen Tile-Cache',
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.proGold.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final AchievementBadge badge;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: badge.unlocked
              ? Border.all(color: AppTheme.proGold.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Opacity(
              opacity: badge.unlocked ? 1 : 0.35,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: badge.unlocked
                      ? AppTheme.proGold.withValues(alpha: 0.2)
                      : AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(badge.emoji, style: const TextStyle(fontSize: 19)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        badge.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: badge.unlocked
                              ? AppTheme.proGold
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (badge.unlocked) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle,
                            size: 14, color: AppTheme.proGold),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge.description,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: badge.fraction,
                      minHeight: 5,
                      backgroundColor: AppTheme.bg,
                      valueColor: AlwaysStoppedAnimation(
                        badge.unlocked ? AppTheme.proGold : AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${badge.progress}/${badge.target}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      );
}
