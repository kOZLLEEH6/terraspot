import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/spot.dart';
import '../../core/services/score_service.dart';
import '../../core/services/sun_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import 'paywall_page.dart';

/// Das PRO-Herzstück auf der Spot-Seite.
///
/// Beantwortet: Lohnt sich der Spot heute? Wann ist das Licht am besten?
/// Wie voll wird es? Alles auf Basis von echtem Wetter (Open-Meteo) und
/// echter Astronomie (SunService) — nichts davon ist ausgedacht.
class SpotIntelligencePanel extends StatefulWidget {
  const SpotIntelligencePanel({super.key, required this.spot});

  final Spot spot;

  @override
  State<SpotIntelligencePanel> createState() => _SpotIntelligencePanelState();
}

class _SpotIntelligencePanelState extends State<SpotIntelligencePanel> {
  Future<List<DailyWeather>>? _forecast;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(SpotIntelligencePanel old) {
    super.didUpdateWidget(old);
    _maybeLoad();
  }

  void _maybeLoad() {
    // Das Wetter wird nur für PRO geladen — sonst verschwenden wir Requests.
    if (!context.read<AppState>().isPro || _forecast != null) return;
    _forecast = context
        .read<AppState>()
        .weather
        .forecast(widget.spot.lat, widget.spot.lng);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.isPro) return _ProTeaser(spot: widget.spot);

    // Nach dem Upgrade sofort nachladen, ohne Neuaufbau der Seite.
    if (_forecast == null) {
      _maybeLoad();
      if (_forecast == null) return const SizedBox.shrink();
    }

    return FutureBuilder<List<DailyWeather>>(
      future: _forecast,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _PanelShell(
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return _PanelShell(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: AppTheme.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Wetterdaten nicht erreichbar.\n${snap.error ?? ''}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _forecast = context
                          .read<AppState>()
                          .weather
                          .forecast(widget.spot.lat, widget.spot.lng);
                    }),
                    child: const Text('Erneut'),
                  ),
                ],
              ),
            ),
          );
        }

        final days = snap.data!;
        final scores = ScoreService.forecast(widget.spot, days);
        final day = _selectedDay.clamp(0, scores.length - 1);
        final score = scores[day];
        final crowd = ScoreService.crowd(widget.spot, days[day]);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Lohnt sich der Spot?', pro: true),
            const SizedBox(height: 10),
            _PanelShell(
              child: Column(
                children: [
                  _DayStrip(
                    scores: scores,
                    selected: day,
                    onSelect: (i) => setState(() => _selectedDay = i),
                  ),
                  const Divider(height: 1),
                  _ScoreDetail(score: score, crowd: crowd),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Licht & Himmel', pro: true),
            const SizedBox(height: 10),
            _LightPanel(spot: widget.spot, date: score.date),
            const SizedBox(height: 22),
            const _SectionTitle('Fotografie-Modus', pro: true),
            const SizedBox(height: 10),
            _PhotographyPanel(spot: widget.spot, date: score.date),
          ],
        );
      },
    );
  }
}

// --- Teaser für Free-Nutzer ---

class _ProTeaser extends StatelessWidget {
  const _ProTeaser({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => PaywallPage.show(context, feature: 'Wetter-Score & Golden Hour'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.proGold.withValues(alpha: 0.16),
                AppTheme.accent.withValues(alpha: 0.07),
              ],
            ),
            border: Border.all(color: AppTheme.proGold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.workspace_premium, size: 18, color: AppTheme.proGold),
                  const SizedBox(width: 8),
                  const Text(
                    'Lohnt sich der Spot heute?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.proGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Angedeutete Sterne — zeigt, was es gäbe, ohne es zu verraten.
              Row(
                children: [
                  for (var i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        Icons.star_rounded,
                        size: 22,
                        color: AppTheme.proGold.withValues(alpha: 0.22),
                      ),
                    ),
                  const SizedBox(width: 10),
                  const Text(
                    '? ? ?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'PRO wertet Wolkendecke, Regen, Wind, Sonnenstand und Mondphase aus und '
                'sagt dir für die nächsten 7 Tage, wann ${spot.title} sich wirklich lohnt — '
                'inklusive Golden Hour und Crowd-Prognose.',
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.lock_open, size: 15, color: AppTheme.proGold),
                  const SizedBox(width: 6),
                  Text(
                    'Freischalten — 9,99 €/Monat',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.proGold,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppTheme.proGold),
                ],
              ),
            ],
          ),
        ),
      );
}

// --- 7-Tage-Streifen ---

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.scores,
    required this.selected,
    required this.onSelect,
  });

  final List<SpotScore> scores;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          itemCount: scores.length,
          itemBuilder: (context, i) {
            final s = scores[i];
            final on = i == selected;
            final label = switch (i) {
              0 => 'Heute',
              1 => 'Morgen',
              _ => DateFormat('E', 'de').format(s.date),
            };

            return GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 68,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: on ? AppTheme.surfaceHigh : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on ? AppTheme.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: on ? AppTheme.textPrimary : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(s.weather.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 5),
                    _MiniStars(stars: s.stars),
                    const SizedBox(height: 3),
                    Text(
                      '${s.weather.tempMax.round()}°',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}

class _MiniStars extends StatelessWidget {
  const _MiniStars({required this.stars});

  final double stars;

  @override
  Widget build(BuildContext context) {
    final full = stars.round().clamp(0, 5);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            Icons.star_rounded,
            size: 9,
            color: i < full ? AppTheme.proGold : AppTheme.textMuted.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class _ScoreDetail extends StatelessWidget {
  const _ScoreDetail({required this.score, required this.crowd});

  final SpotScore score;
  final CrowdPrediction crowd;

  @override
  Widget build(BuildContext context) {
    final w = score.weather;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  Icons.star_rounded,
                  size: 24,
                  color: i < score.fullStars
                      ? AppTheme.proGold
                      : AppTheme.textMuted.withValues(alpha: 0.25),
                ),
              const SizedBox(width: 10),
              Text(
                score.headline,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Rohdaten, auf denen der Score beruht
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Metric(icon: w.emoji, label: w.condition),
              _Metric(icon: '🌡️', label: '${w.tempMin.round()}–${w.tempMax.round()}°C'),
              _Metric(icon: '☁️', label: '${w.cloudCover.round()}% Wolken'),
              _Metric(icon: '🌧️', label: '${w.precipitationProbability.round()}% Regen'),
              _Metric(icon: '💨', label: '${w.windSpeedKmh.round()} km/h'),
              _Metric(icon: '💧', label: '${w.humidity.round()}% Luftf.'),
            ],
          ),
          const SizedBox(height: 16),

          // Warum dieser Score? Nachvollziehbarkeit schlägt Magie.
          for (final r in score.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (r.impact) {
                      ScoreImpact.positive => Icons.check_circle,
                      ScoreImpact.neutral => Icons.remove_circle_outline,
                      ScoreImpact.negative => Icons.cancel,
                    },
                    size: 15,
                    color: switch (r.impact) {
                      ScoreImpact.positive => const Color(0xFF3E9C5A),
                      ScoreImpact.neutral => AppTheme.textMuted,
                      ScoreImpact.negative => const Color(0xFFD9452B),
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.text,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Crowd Prediction
          Row(
            children: [
              Text(crowd.level.emoji, style: const TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Andrang',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  Text(
                    crowd.level.label,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  crowd.drivers.isEmpty ? '' : crowd.drivers.join(' · '),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 12.5)),
          ],
        ),
      );
}

// --- Licht & Himmel ---

class _LightPanel extends StatelessWidget {
  const _LightPanel({required this.spot, required this.date});

  final Spot spot;
  final DateTime date;

  String _t(DateTime? utc) {
    if (utc == null) return '—';
    final local = utc.add(SunService.localOffsetFor(spot.lng));
    return DateFormat('HH:mm').format(local);
  }

  @override
  Widget build(BuildContext context) {
    final times = SunService.times(date, spot.lat, spot.lng);
    final moon = SunService.moon(date, spot.lat, spot.lng);
    final mw = SunService.milkyWay(date, spot.lat, spot.lng);

    if (times.polarDay || times.polarNight) {
      return _PanelShell(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(times.polarDay ? '☀️' : '🌑', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  times.polarDay
                      ? 'Mitternachtssonne — die Sonne geht an diesem Tag nicht unter.'
                      : 'Polarnacht — die Sonne geht an diesem Tag nicht auf.',
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _PanelShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _LightRow(
              emoji: '🔵',
              label: 'Blaue Stunde (morgens)',
              value: '${_t(times.blueHourMorningStart)} – ${_t(times.blueHourMorningEnd)}',
            ),
            _LightRow(
              emoji: '🌅',
              label: 'Sonnenaufgang',
              value: _t(times.sunrise),
              highlight: spot.category == SpotCategory.sunrise,
            ),
            _LightRow(
              emoji: '🟡',
              label: 'Goldene Stunde (morgens)',
              value:
                  '${_t(times.goldenHourMorningStart)} – ${_t(times.goldenHourMorningEnd)}',
              highlight: spot.category == SpotCategory.sunrise,
            ),
            const Divider(height: 20),
            _LightRow(
              emoji: '🟠',
              label: 'Goldene Stunde (abends)',
              value:
                  '${_t(times.goldenHourEveningStart)} – ${_t(times.goldenHourEveningEnd)}',
              highlight: spot.category == SpotCategory.viewpoint,
            ),
            _LightRow(
              emoji: '🌇',
              label: 'Sonnenuntergang',
              value: _t(times.sunset),
            ),
            _LightRow(
              emoji: '🔷',
              label: 'Blaue Stunde (abends)',
              value: '${_t(times.blueHourEveningStart)} – ${_t(times.blueHourEveningEnd)}',
            ),
            const Divider(height: 20),
            _LightRow(
              emoji: moon.emoji,
              label: moon.phaseLabel,
              value: '${(moon.illumination * 100).round()}% beleuchtet',
            ),
            _LightRow(
              emoji: '🌘',
              label: 'Mondaufgang / -untergang',
              value: '${_t(moon.rise)} / ${_t(moon.setTime)}',
            ),
            const Divider(height: 20),
            _LightRow(
              emoji: '🌌',
              label: 'Milchstraße',
              value: mw.visible ? 'sichtbar' : 'nicht sichtbar',
              highlight: mw.visible,
            ),
            if (mw.darkStart != null)
              _LightRow(
                emoji: '⚫',
                label: 'Astronomische Dunkelheit',
                value: '${_t(mw.darkStart)} – ${_t(mw.darkEnd)}',
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mw.reason,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Alle Zeiten in Ortszeit am Spot (Näherung über den Längengrad).',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _LightRow extends StatelessWidget {
  const _LightRow({
    required this.emoji,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String emoji;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                  color: highlight ? AppTheme.accent : AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: highlight ? AppTheme.accent : AppTheme.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

// --- Fotografie-Modus ---

class _PhotographyPanel extends StatelessWidget {
  const _PhotographyPanel({required this.spot, required this.date});

  final Spot spot;
  final DateTime date;

  /// Sonnenstand zur vom Ersteller angegebenen besten Uhrzeit.
  SolarPosition _sunAtBestTime() {
    final parts = spot.bestTimeOfDay.split(':');
    final h = int.tryParse(parts.first) ?? 6;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    // Ortszeit am Spot -> UTC
    final localNaive = DateTime.utc(date.year, date.month, date.day, h, m);
    final utc = localNaive.subtract(SunService.localOffsetFor(spot.lng));
    return SunService.sunPosition(utc, spot.lat, spot.lng);
  }

  /// Brennweiten-Empfehlung nach Motivtyp — ein Fotografen-Faustwert, keine Messung.
  String get _focalLength => switch (spot.category) {
        SpotCategory.nightSky => '14–24 mm, f/2.8, ISO 3200, 15–20 s',
        SpotCategory.viewpoint => '16–35 mm für die Weite, 70–200 mm für Details',
        SpotCategory.sunrise => '24–70 mm, Grauverlaufsfilter für den Himmel',
        SpotCategory.waterfall => '16–35 mm, ND-Filter, 1/4–2 s für seidiges Wasser',
        SpotCategory.flowers => '85–200 mm, offene Blende für Bokeh-Reihen',
        SpotCategory.autumn => '24–70 mm, Polfilter gegen Blattreflexe',
        SpotCategory.winter => '24–70 mm, +1 EV Belichtungskorrektur für weißen Schnee',
        SpotCategory.beach => '16–35 mm, Polfilter für das Wasser',
        SpotCategory.hiking => '24–70 mm — der Allrounder am Berg',
        SpotCategory.camping => '16–35 mm, f/2.8 für Zelt vor Sternenhimmel',
        SpotCategory.campfire => '35–50 mm, f/1.8, ISO 1600 für Feuerlicht',
      };

  @override
  Widget build(BuildContext context) {
    final sun = _sunAtBestTime();
    final moon = SunService.moon(date, spot.lat, spot.lng);

    return _PanelShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CompassDial(azimuth: sun.azimuthDeg, altitude: sun.altitudeDeg),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sonne um ${spot.bestTimeOfDay}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${sun.azimuthDeg.round()}° ${sun.compass}',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        sun.altitudeDeg >= 0
                            ? '${sun.altitudeDeg.toStringAsFixed(1)}° über dem Horizont'
                            : '${sun.altitudeDeg.abs().toStringAsFixed(1)}° unter dem Horizont',
                        style: TextStyle(
                          fontSize: 13,
                          color: sun.altitudeDeg >= -6 && sun.altitudeDeg <= 6
                              ? AppTheme.accent
                              : AppTheme.textMuted,
                          fontWeight: sun.altitudeDeg >= -6 && sun.altitudeDeg <= 6
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (sun.altitudeDeg >= -6 && sun.altitudeDeg <= 6)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Weiches Licht — genau im Fenster',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.accent),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _TipRow(icon: Icons.camera, label: 'Einstellung', value: _focalLength),
            _TipRow(
              icon: Icons.nightlight_round,
              label: 'Mond',
              value: '${moon.emoji} ${moon.phaseLabel}, '
                  '${(moon.illumination * 100).round()}% beleuchtet',
            ),
            _TipRow(
              icon: Icons.terrain,
              label: 'Anfahrt einplanen',
              value: spot.hikeMinutes == 0
                  ? 'Kein Fußweg — direkt am Parkplatz'
                  : '${spot.hikeLabel} Aufstieg — vor Sonnenaufgang losgehen',
            ),
          ],
        ),
      ),
    );
  }
}

/// Kompassscheibe mit der Sonnenrichtung.
class _CompassDial extends StatelessWidget {
  const _CompassDial({required this.azimuth, required this.altitude});

  final double azimuth;
  final double altitude;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 82,
        height: 82,
        child: CustomPaint(
          painter: _CompassPainter(azimuth: azimuth, altitude: altitude),
        ),
      );
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter({required this.azimuth, required this.altitude});

  final double azimuth;
  final double altitude;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.surfaceHigh
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.textMuted.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Himmelsrichtungen: N oben, O rechts, S unten, W links.
    const labels = {'N': Offset(0, -1), 'O': Offset(1, 0), 'S': Offset(0, 1), 'W': Offset(-1, 0)};
    for (final entry in labels.entries) {
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = center + entry.value * (radius - 9);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    // Sonnenstrahl in Azimut-Richtung (0° = Norden, im Uhrzeigersinn).
    // Der Bildschirm hat 0° rechts, deshalb -90°.
    final rad = (azimuth - 90) * math.pi / 180;
    final tip = Offset(
      center.dx + (radius - 14) * math.cos(rad),
      center.dy + (radius - 14) * math.sin(rad),
    );

    final aboveHorizon = altitude >= 0;
    final sunColor = aboveHorizon ? AppTheme.accent : AppTheme.textMuted;
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = sunColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(tip, 5, Paint()..color = sunColor);
    canvas.drawCircle(center, 3, Paint()..color = AppTheme.textPrimary);
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.azimuth != azimuth || old.altitude != altitude;
}

// --- gemeinsame Bausteine ---

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.pro = false});

  final String text;
  final bool pro;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (pro) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.proGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppTheme.proGold.withValues(alpha: 0.45)),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.proGold,
                ),
              ),
            ),
          ],
        ],
      );
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 1),
                  Text(value, style: const TextStyle(fontSize: 13.5, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
}
