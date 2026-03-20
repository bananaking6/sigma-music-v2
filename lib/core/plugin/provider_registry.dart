import '../result/result.dart';
import 'music_provider_plugin.dart';
import 'provider_capabilities.dart';

/// Central registry for all [MusicProviderPlugin] instances.
///
/// Usage:
/// ```dart
/// final registry = ProviderRegistry();
/// registry.register(TidalProviderPlugin(...));
/// registry.register(LocalFilesProviderPlugin());
/// await registry.initializeAll();
/// registry.setActiveProvider('tidal');
/// ```
class ProviderRegistry {
  final Map<String, MusicProviderPlugin> _providers = {};
  String? _activeProviderId;

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  /// All registered providers in registration order.
  List<MusicProviderPlugin> get allProviders => _providers.values.toList();

  /// The currently active provider, or `null` if none is registered.
  MusicProviderPlugin? get activeProvider =>
      _activeProviderId == null ? null : _providers[_activeProviderId];

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers [plugin] with the registry.
  ///
  /// The first registered provider is automatically set as the active one.
  /// Returns [Result.failure] if a provider with the same [id] is already
  /// registered.
  Result<void> register(MusicProviderPlugin plugin) {
    if (_providers.containsKey(plugin.id)) {
      return Result.failure('Provider "${plugin.id}" is already registered');
    }
    _providers[plugin.id] = plugin;
    _activeProviderId ??= plugin.id;
    return const Result.success(null);
  }

  // ---------------------------------------------------------------------------
  // Active provider
  // ---------------------------------------------------------------------------

  /// Changes the active provider to [providerId].
  ///
  /// Returns [Result.failure] if the provider is not registered.
  Result<void> setActiveProvider(String providerId) {
    if (!_providers.containsKey(providerId)) {
      return Result.failure('Provider "$providerId" is not registered');
    }
    _activeProviderId = providerId;
    return const Result.success(null);
  }

  // ---------------------------------------------------------------------------
  // Query
  // ---------------------------------------------------------------------------

  /// Returns all providers that advertise [capability].
  List<MusicProviderPlugin> providersWithCapability(
    ProviderCapability capability,
  ) {
    return _providers.values
        .where((p) => p.capabilities.contains(capability))
        .toList();
  }

  /// Returns the provider registered under [id], or `null`.
  MusicProviderPlugin? byId(String id) => _providers[id];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Calls [MusicProviderPlugin.initialize] on every registered provider in
  /// registration order.
  ///
  /// Stops and returns the first failure encountered.
  Future<Result<void>> initializeAll() async {
    for (final provider in _providers.values) {
      final result = await provider.initialize();
      if (result.isFailure) {
        return Result.failure(
          'Failed to initialize provider "${provider.id}": '
          '${result.errorMessage}',
        );
      }
    }
    return const Result.success(null);
  }
}
