import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/spot.dart';
import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Das Drei-Punkte-Menü auf der Spot-Detailseite: Melden, Löschen und
/// (für den Owner) Sperren von Spot oder Nutzer.
class SpotActionsButton extends StatelessWidget {
  const SpotActionsButton({super.key, required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isMine = spot.authorName == state.currentUserName;
    final spotBlocked = state.spotBlocked(spot.id);
    final userBlocked = state.userBlocked(spot.authorName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: PopupMenuButton<String>(
        icon: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.more_vert, size: 20, color: Colors.white),
        ),
        color: AppTheme.surfaceHigh,
        itemBuilder: (context) => [
          if (!isMine)
            const PopupMenuItem(
              value: 'report',
              child: _Row(icon: Icons.flag_outlined, label: 'Melden'),
            ),
          if (state.canDelete(spot))
            const PopupMenuItem(
              value: 'delete',
              child: _Row(
                icon: Icons.delete_outline,
                label: 'Löschen',
                color: Color(0xFFFF6B6B),
              ),
            ),
          if (state.isOwner) ...[
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'block_spot',
              child: _Row(
                icon: spotBlocked ? Icons.visibility : Icons.block,
                label: spotBlocked ? 'Spot entsperren' : 'Spot sperren',
                color: AppTheme.proGold,
              ),
            ),
            if (!isMine)
              PopupMenuItem(
                value: 'block_user',
                child: _Row(
                  icon: userBlocked ? Icons.lock_open : Icons.person_off,
                  label: userBlocked
                      ? 'Nutzer entsperren'
                      : 'Nutzer sperren',
                  color: AppTheme.proGold,
                ),
              ),
          ],
        ],
        onSelected: (value) => _handle(context, state, value),
      ),
    );
  }

  Future<void> _handle(BuildContext context, AppState state, String value) async {
    switch (value) {
      case 'report':
        await _showReportSheet(context, state);
      case 'delete':
        await _confirmDelete(context, state);
      case 'block_spot':
        final blocked = state.spotBlocked(spot.id);
        await state.setSpotBlocked(spot.id, !blocked);
        if (context.mounted) {
          _toast(context, blocked ? 'Spot ist wieder sichtbar' : 'Spot gesperrt');
        }
      case 'block_user':
        final blocked = state.userBlocked(spot.authorName);
        await state.setUserBlocked(spot.authorName, !blocked);
        if (context.mounted) {
          _toast(
            context,
            blocked
                ? '${spot.authorName} ist wieder freigeschaltet'
                : '${spot.authorName} gesperrt',
          );
        }
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Spot löschen?'),
        content: Text(
          '„${spot.title}" wird dauerhaft entfernt. Das lässt sich nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await state.deleteSpot(spot.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // zurück von der Detailseite
        _toast(context, 'Spot gelöscht');
      }
    }
  }

  Future<void> _showReportSheet(BuildContext context, AppState state) async {
    const reasons = [
      'Spam oder Werbung',
      'Falscher oder gefährlicher Ort',
      'Anstößiger Inhalt',
      'Urheberrechtsverletzung',
      'Etwas anderes',
    ];

    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Spot melden',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            for (final r in reasons)
              ListTile(
                title: Text(r),
                leading: const Icon(Icons.flag_outlined, size: 20),
                onTap: () => Navigator.pop(context, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (reason != null) {
      await state.reportSpot(spot.id, reason);
      if (context.mounted) {
        _toast(context, 'Danke — die Meldung ist beim Team.');
      }
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 19, color: color ?? AppTheme.textPrimary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color ?? AppTheme.textPrimary)),
        ],
      );
}
