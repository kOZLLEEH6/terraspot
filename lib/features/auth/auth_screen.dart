import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../core/theme.dart';

/// Anmelden / Registrieren beim ersten Start (nach der AGB-Zustimmung).
///
/// Klassische Anmeldung mit Benutzername + Passwort. Gibt es auf dem Gerät
/// schon ein Konto, wird angemeldet; sonst registriert. Das Passwort wird
/// lokal nur als gesalzener Hash gespeichert. Mit Supabase wird daraus eine
/// echte Registrierung/Anmeldung über Supabase Auth.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();

  /// true = Registrieren, false = Anmelden. Vorbelegt je nachdem, ob schon ein
  /// Konto existiert.
  late bool _registerMode;
  bool _obscure = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _registerMode = !context.read<AppState>().hasAccount;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    final user = _username.text.trim();
    final pass = _password.text;

    if (_registerMode && pass != _passwordConfirm.text) {
      setState(() => _error = 'Die Passwörter stimmen nicht überein.');
      return;
    }

    setState(() {
      _error = null;
      _busy = true;
    });

    final result = _registerMode
        ? await state.register(user, pass)
        : await state.login(user, pass);

    if (!mounted) return;
    setState(() => _busy = false);

    if (result != AuthOutcome.success) {
      setState(() => _error = result.message);
    }
    // Bei Erfolg schaltet die App automatisch weiter (needsAuth wird false).
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/branding/icon.png',
                        width: 80, height: 80, cacheWidth: 240),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _registerMode ? 'Konto erstellen' : 'Willkommen zurück',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _registerMode
                        ? 'Wähle einen Benutzernamen und ein Passwort, um loszulegen.'
                        : 'Melde dich mit deinem Benutzernamen und Passwort an.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 28),

                  TextField(
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Benutzername',
                      hintText: 'z. B. alex',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    textInputAction:
                        _registerMode ? TextInputAction.next : TextInputAction.done,
                    onSubmitted: _registerMode ? null : (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Passwort',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_registerMode) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordConfirm,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Passwort bestätigen',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: Color(0xFFFF6B6B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFFFF6B6B))),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_registerMode ? 'Registrieren' : 'Anmelden'),
                  ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _registerMode = !_registerMode;
                              _error = null;
                            }),
                    child: Text(
                      _registerMode
                          ? 'Schon ein Konto? Anmelden'
                          : 'Neu hier? Konto erstellen',
                      style: const TextStyle(color: AppTheme.accent),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    'Mit der Anmeldung bestätigst du die bereits akzeptierten '
                    'Nutzungsbedingungen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
