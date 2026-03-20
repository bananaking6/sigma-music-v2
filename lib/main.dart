import 'package:flutter/material.dart';

import 'app/app_bootstrap.dart';
import 'features/playback/unified_music_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = AppBootstrap();
  await bootstrap.initialize();

  runApp(SigmaMusicApp(repository: bootstrap.repository));
}

class SigmaMusicApp extends StatelessWidget {
  const SigmaMusicApp({super.key, required this.repository});

  final UnifiedMusicRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sigma Music',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1DB954),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _HomeShell(repository: repository),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.repository});

  final UnifiedMusicRepository repository;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(repository: widget.repository),
      const _SearchTab(),
      const _LibraryTab(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sigma Music')),
      body: IndexedStack(index: _selectedTabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) => setState(() => _selectedTabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.repository});

  final UnifiedMusicRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Active provider'),
            subtitle: Text(repository.activeProviderName ?? 'None'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.recommend_outlined),
            title: Text('Recommendations ready'),
            subtitle: Text('Provider architecture is initialized.'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.graphic_eq),
            title: Text('Playback engine'),
            subtitle: Text('Coming in next milestone.'),
          ),
        ),
      ],
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Search UI scaffold\n\n'
          'The provider-backed search pipeline is available and can now be wired '
          'to a full query experience.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Library UI scaffold\n\n'
          'Local and cloud library screens will appear here once indexing and '
          'playlists are fully connected.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
