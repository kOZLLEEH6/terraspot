import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Code einlösen — für jeden Nutzer. Ein gültiger Gift-Code schaltet PRO
/// für die im Code hinterlegte Anzahl Monate frei.
class RedeemCodeSheet extends StatefulWidget {
  const RedeemCodeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RedeemCodeSheet(),
    );
  }

  @override
  State<RedeemCodeSheet> createState() => _RedeemCodeSheetState();
}

class _RedeemCodeSheetState extends State<RedeemCodeSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _redeem() {
    final state = context.read<AppState>();
    final result = state.redeemCode(_controller.text);

    switch (result) {
      case RedeemResult.success:
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.proGold,
            content: Text(
              'Code eingelöst — PRO ist aktiv! 🎉',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ),
        );
      case RedeemResult.alreadyUsed:
        setState(() => _error = 'Dieser Code wurde bereits eingelöst.');
      case RedeemResult.invalid:
        setState(() => _error = 'Ungültiger Code. Bitte prüfe die Eingabe.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('🎁', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            const Text(
              'Code einlösen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hast du einen Gutschein-Code? Gib ihn ein und schalte PRO frei.',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseFormatter()],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _redeem(),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'TERRA-XXXX-XXXX',
                errorText: _error,
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _redeem,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.proGold,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Einlösen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wandelt die Eingabe in Großbuchstaben um — Codes sind case-insensitive.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue neu) {
    return neu.copyWith(text: neu.text.toUpperCase());
  }
}
