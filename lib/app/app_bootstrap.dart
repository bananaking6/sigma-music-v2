import '../core/plugin/provider_registry.dart';
import '../features/playback/unified_music_repository.dart';
import '../providers/local/local_provider_plugin.dart';
import '../providers/tidal/tidal_provider_plugin.dart';

/// Wires together all providers and produces the root [UnifiedMusicRepository]
/// instance used throughout the app.
///
/// Call [AppBootstrap.initialize] once at app startup (before rendering the
/// first frame) to ensure providers are ready.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final bootstrap = AppBootstrap();
///   await bootstrap.initialize();
///   runApp(SigmaMusicApp(repository: bootstrap.repository));
/// }
/// ```
class AppBootstrap {
  AppBootstrap({
    TidalProviderPlugin? tidalPlugin,
    LocalFilesProviderPlugin? localPlugin,
  })  : _tidalPlugin = tidalPlugin ?? TidalProviderPlugin(),
        _localPlugin = localPlugin ?? LocalFilesProviderPlugin();

  final TidalProviderPlugin _tidalPlugin;
  final LocalFilesProviderPlugin _localPlugin;

  late final ProviderRegistry _registry;
  late final UnifiedMusicRepository _repository;

  ProviderRegistry get registry => _registry;
  UnifiedMusicRepository get repository => _repository;

  // ---------------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------------

  /// Registers providers, initialises them, and sets TIDAL as the default.
  ///
  /// Errors during local provider init are non-fatal (e.g. missing storage
  /// permission); errors during TIDAL init surface as a thrown exception.
  Future<void> initialize() async {
    _registry = ProviderRegistry();

    // Register providers.  First registered becomes default active provider.
    _registry.register(_tidalPlugin);
    _registry.register(_localPlugin);

    // Initialise all providers; stop on first hard failure.
    final initResult = await _registry.initializeAll();
    if (initResult.isFailure) {
      // For now just log; a real app would show a setup screen.
      // ignore: avoid_print
      print('[AppBootstrap] Provider init warning: ${initResult.errorMessage}');
    }

    // Explicitly set TIDAL as the active provider.
    _registry.setActiveProvider('tidal');

    // Expose the unified repository.
    _repository = UnifiedMusicRepository(_registry);
  }
}
