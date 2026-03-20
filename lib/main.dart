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
      home: _PlaceholderHome(repository: repository),
    );
  }
}

/// Temporary placeholder home screen.
///
/// Replace this with the real feature screens once the playback engine,
/// search, and library UIs are implemented.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome({required this.repository});

  final UnifiedMusicRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64),
            const SizedBox(height: 16),
            Text(
              'Sigma Music',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Active provider: ${repository.activeProviderName ?? 'None'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
