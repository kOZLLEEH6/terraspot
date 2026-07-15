import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/state/app_state.dart';
import 'core/theme.dart';
import 'features/create/create_spot_page.dart';
import 'features/feed/feed_page.dart';
import 'features/map/map_page.dart';
import 'features/profile/profile_page.dart';
import 'features/search/search_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');

  final state = await AppState.create();

  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const TerraSpotApp(),
    ),
  );
}

class TerraSpotApp extends StatelessWidget {
  const TerraSpotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TerraSpot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const RootShell(),
      );
}

/// Die Karte ist das Zuhause der App — erster Tab, Startseite.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _pages = [
    MapPage(),
    SearchPage(),
    CreateSpotPage(),
    FeedPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    if (context.watch<AppState>().loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Karte',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Suchen',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Erstellen',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
