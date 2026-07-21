import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/models/category.dart';
import '../../core/models/spot.dart';
import '../../core/services/description_generator.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';
import '../spot/spot_detail_page.dart';

class CreateSpotPage extends StatefulWidget {
  const CreateSpotPage({super.key});

  @override
  State<CreateSpotPage> createState() => _CreateSpotPageState();
}

class _CreateSpotPageState extends State<CreateSpotPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _country = TextEditingController();
  final _region = TextEditingController();
  final _mapController = MapController();

  XFile? _photo;
  SpotCategory _category = SpotCategory.viewpoint;
  Difficulty _difficulty = Difficulty.easy;
  TimeOfDay _bestTime = const TimeOfDay(hour: 6, minute: 30);
  final Set<int> _months = {6, 7, 8};
  LatLng _position = const LatLng(46.6069, 11.7047);
  double _hikeMinutes = 45;
  double _hikeKm = 3;
  double _elevation = 1200;

  bool _parking = true;
  bool _dogs = true;
  bool _kids = true;
  bool _camping = false;
  bool _saving = false;
  bool _locating = false;

  /// Legt der Nutzer den Pin selbst? Solange nicht, folgt der GPS-Punkt automatisch.
  bool _pinMovedManually = false;

  @override
  void initState() {
    super.initState();
    // GPS-Automatik: beim Öffnen den Standort ermitteln und den Pin dorthin setzen.
    // Kennt die App den Standort schon (z. B. vom Umkreisfilter), diesen sofort nutzen.
    final known = context.read<AppState>().userLocation;
    if (known != null) _position = known;
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _country.dispose();
    _region.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Beim Öffnen automatisch: nur, wenn der Nutzer den Pin noch nicht selbst gesetzt hat.
  Future<void> _autoLocate() async {
    if (_pinMovedManually) return;
    await _useMyLocation(silent: true);
  }

  /// Ermittelt den Gerätestandort und schiebt Karte + Pin dorthin.
  Future<void> _useMyLocation({bool silent = false}) async {
    if (_locating) return;
    setState(() => _locating = true);

    final result = await context.read<AppState>().locateUser();

    if (!mounted) return;
    setState(() => _locating = false);

    if (result.isSuccess) {
      setState(() => _position = result.position!);
      _mapController.move(result.position!, 13);
    } else if (!silent) {
      // Nur bei bewusstem Antippen eine Fehlermeldung zeigen — nicht beim Auto-Versuch.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Standort nicht verfügbar')),
      );
    }
  }

  /// Füllt die Beschreibung automatisch aus den bereits gewählten Feldern.
  void _autofillDescription() {
    final text = DescriptionGenerator.generate(
      title: _title.text,
      category: _category,
      region: _region.text,
      country: _country.text,
      bestTimeOfDay:
          '${_bestTime.hour.toString().padLeft(2, '0')}:${_bestTime.minute.toString().padLeft(2, '0')}',
      bestMonths: _months,
      difficulty: _difficulty,
      hikeMinutes: _hikeMinutes.round(),
      hikeKm: _hikeKm,
      elevationM: _elevation.round(),
      hasParking: _parking,
      dogsAllowed: _dogs,
      kidsFriendly: _kids,
      campingAllowed: _camping,
    );
    setState(() => _description.text = text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Beschreibung erstellt — du kannst sie anpassen.')),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked != null) setState(() => _photo = picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto konnte nicht geladen werden: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte lade ein Foto hoch')),
      );
      return;
    }
    if (_months.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte wähle mindestens einen Monat')),
      );
      return;
    }

    setState(() => _saving = true);

    final spot = Spot(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category,
      lat: _position.latitude,
      lng: _position.longitude,
      country: _country.text.trim().isEmpty ? 'Unbekannt' : _country.text.trim(),
      region: _region.text.trim().isEmpty ? '—' : _region.text.trim(),
      photoUrls: const [],
      localPhotoPath: _photo!.path,
      rating: 0,
      ratingCount: 0,
      bestTimeOfDay:
          '${_bestTime.hour.toString().padLeft(2, '0')}:${_bestTime.minute.toString().padLeft(2, '0')}',
      bestMonths: _months.toList()..sort(),
      difficulty: _difficulty,
      hikeMinutes: _hikeMinutes.round(),
      hikeKm: double.parse(_hikeKm.toStringAsFixed(1)),
      elevationM: _elevation.round(),
      hasParking: _parking,
      dogsAllowed: _dogs,
      kidsFriendly: _kids,
      campingAllowed: _camping,
      likes: 0,
      authorName: context.read<AppState>().currentUserName,
      createdAt: DateTime.now(),
      visitorsPerDay: 0,
    );

    final created = await context.read<AppState>().createSpot(spot);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${created.title}" ist jetzt auf der Karte')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SpotDetailPage(spotId: created.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spot erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _PhotoPicker(photo: _photo, onTap: _pickPhoto, category: _category),
            const SizedBox(height: 20),

            const _Label('Titel'),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'z. B. Seceda Grat'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Mindestens 3 Zeichen' : null,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const _Label('Beschreibung'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _autofillDescription,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Automatisch'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.proGold),
                ),
              ],
            ),
            TextFormField(
              controller: _description,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Was macht diesen Ort besonders? Worauf muss man achten?\n'
                    'Oder tippe oben auf „Automatisch".',
              ),
              validator: (v) =>
                  (v == null || v.trim().length < 10) ? 'Mindestens 10 Zeichen' : null,
            ),
            const SizedBox(height: 16),

            const _Label('Kategorie'),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final c in SpotCategory.values)
                  ChoiceChip(
                    label: Text('${c.emoji} ${c.label}'),
                    selected: _category == c,
                    selectedColor: c.color,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                const _Label('Standort'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _locating ? null : () => _useMyLocation(),
                  icon: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(_locating ? 'Ortung ...' : 'Mein Standort'),
                ),
              ],
            ),
            Text(
              _pinMovedManually
                  ? 'Pin manuell gesetzt. Tippe erneut auf die Karte, um ihn zu verschieben.'
                  : 'Wird automatisch per GPS gesetzt — oder tippe auf die Karte.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _position,
                    initialZoom: 9,
                    // Die Auto-Ortung beim Öffnen kann fertig sein, bevor die Karte
                    // bereit ist. Dann zentriert onMapReady nachträglich auf den Pin.
                    onMapReady: () {
                      if (!_pinMovedManually) _mapController.move(_position, 13);
                    },
                    onTap: (_, point) => setState(() {
                      _position = point;
                      _pinMovedManually = true;
                    }),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.terraspot.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _position,
                          width: 40,
                          height: 46,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.place,
                            size: 40,
                            color: _category.color,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, size: 16, color: AppTheme.accentAlt),
                  const SizedBox(width: 10),
                  const Text('GPS', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Text(
                    '${_position.latitude.toStringAsFixed(5)}, '
                    '${_position.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Land'),
                      TextFormField(
                        controller: _country,
                        decoration: const InputDecoration(hintText: 'Italien'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Region'),
                      TextFormField(
                        controller: _region,
                        decoration: const InputDecoration(hintText: 'Südtirol'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const _Label('Beste Uhrzeit'),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _bestTime,
                );
                if (picked != null) setState(() => _bestTime = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wb_twilight, size: 18, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    Text(
                      '${_bestTime.hour.toString().padLeft(2, '0')}:'
                      '${_bestTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit, size: 15, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const _Label('Beste Jahreszeit'),
            _MonthPicker(
              selected: _months,
              onToggle: (m) => setState(() {
                _months.contains(m) ? _months.remove(m) : _months.add(m);
              }),
            ),
            const SizedBox(height: 20),

            const _Label('Schwierigkeit'),
            Row(
              children: [
                for (final d in Difficulty.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(d.label),
                      selected: _difficulty == d,
                      selectedColor: d.color,
                      onSelected: (_) => setState(() => _difficulty = d),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            _Label('Wanderzeit: ${_hikeMinutes.round()} min'),
            Slider(
              value: _hikeMinutes,
              max: 480,
              divisions: 32,
              onChanged: (v) => setState(() => _hikeMinutes = v),
            ),

            _Label('Strecke: ${_hikeKm.toStringAsFixed(1)} km'),
            Slider(
              value: _hikeKm,
              max: 25,
              divisions: 50,
              onChanged: (v) => setState(() => _hikeKm = v),
            ),

            _Label('Höhe: ${_elevation.round()} m'),
            Slider(
              value: _elevation,
              max: 4000,
              divisions: 40,
              onChanged: (v) => setState(() => _elevation = v),
            ),
            const SizedBox(height: 12),

            const _Label('Vor Ort'),
            _Check(
              emoji: '🅿️',
              label: 'Parkplatz vorhanden',
              value: _parking,
              onChanged: (v) => setState(() => _parking = v),
            ),
            _Check(
              emoji: '🐕',
              label: 'Hund erlaubt',
              value: _dogs,
              onChanged: (v) => setState(() => _dogs = v),
            ),
            _Check(
              emoji: '👶',
              label: 'Für Kinder geeignet',
              value: _kids,
              onChanged: (v) => setState(() => _kids = v),
            ),
            _Check(
              emoji: '🏕️',
              label: 'Camping erlaubt',
              value: _camping,
              onChanged: (v) => setState(() => _camping = v),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt),
                label: Text(_saving ? 'Wird gespeichert ...' : 'Spot veröffentlichen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onTap,
    required this.category,
  });

  final XFile? photo;
  final VoidCallback onTap;
  final SpotCategory category;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 210,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: photo == null
                  ? AppTheme.textMuted.withValues(alpha: 0.3)
                  : Colors.transparent,
              style: BorderStyle.solid,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: photo == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_a_photo,
                        color: category.color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Foto hochladen',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Das Titelbild deines Spots',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    kIsWeb
                        ? Image.network(photo!.path, fit: BoxFit.cover)
                        : Image.file(File(photo!.path), fit: BoxFit.cover),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit, size: 14, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'Ändern',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _names = [
    'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
    'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var m = 1; m <= 12; m++)
            GestureDetector(
              onTap: () => onToggle(m),
              child: Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected.contains(m) ? AppTheme.accent : AppTheme.surface,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(
                    _names[m - 1],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected.contains(m) ? FontWeight.w800 : FontWeight.w500,
                      color: selected.contains(m)
                          ? Colors.black
                          : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      );
}

class _Check extends StatelessWidget {
  const _Check({
    required this.emoji,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String emoji;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppTheme.accent,
                checkColor: Colors.black,
              ),
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
}
