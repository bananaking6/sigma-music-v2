import '../../core/models/album.dart';
import '../../core/models/audio_stream_info.dart';
import '../../core/models/lyrics.dart';
import '../../core/models/search_result.dart';
import '../../core/models/track.dart';
import '../../core/plugin/provider_capabilities.dart';
import '../../core/plugin/provider_registry.dart';
import '../../core/result/result.dart';

/// Provider-agnostic music repository used by all app features.
///
/// [UnifiedMusicRepository] delegates every operation to the currently active
/// provider returned by [ProviderRegistry.activeProvider].  Features never
/// reference TIDAL or local classes directly — they only depend on this class.
///
/// ### Lyrics fallback
/// [getLyricsBestEffort] first tries the active provider, then falls back to
/// any other registered provider that advertises [ProviderCapability.lyrics].
class UnifiedMusicRepository {
  const UnifiedMusicRepository(this._registry);

  final ProviderRegistry _registry;

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<Result<List<SearchResultItem>>> search(
    String query, {
    int limit = 25,
  }) {
    final provider = _registry.activeProvider;
    if (provider == null) return _noProvider();
    return provider.search(query, limit: limit);
  }

  // ---------------------------------------------------------------------------
  // Entity lookup
  // ---------------------------------------------------------------------------

  Future<Result<Track>> getTrackById(String id) {
    final provider = _registry.activeProvider;
    if (provider == null) return _noProvider();
    return provider.getTrackById(id);
  }

  Future<Result<Album>> getAlbumById(String id) {
    final provider = _registry.activeProvider;
    if (provider == null) return _noProvider();
    return provider.getAlbumById(id);
  }

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  Future<Result<AudioStreamInfo>> getStreamInfo(
    String trackId, {
    AudioQuality quality = AudioQuality.hiResLossless,
  }) {
    final provider = _registry.activeProvider;
    if (provider == null) return _noProvider();
    return provider.getStreamInfo(trackId, quality: quality);
  }

  // ---------------------------------------------------------------------------
  // Lyrics (with best-effort fallback)
  // ---------------------------------------------------------------------------

  /// Returns lyrics for [trackId], trying the active provider first.
  ///
  /// If the active provider does not support lyrics or fails, the repository
  /// falls back to every other registered provider that advertises
  /// [ProviderCapability.lyrics].
  Future<Result<Lyrics>> getLyricsBestEffort(String trackId) async {
    final active = _registry.activeProvider;
    if (active != null &&
        active.capabilities.contains(ProviderCapability.lyrics)) {
      final result = await active.getLyrics(trackId);
      if (result.isSuccess) return result;
    }

    for (final provider
        in _registry.providersWithCapability(ProviderCapability.lyrics)) {
      if (provider.id == active?.id) continue;
      final result = await provider.getLyrics(trackId);
      if (result.isSuccess) return result;
    }

    return const Result.failure('Lyrics unavailable from all providers');
  }

  // ---------------------------------------------------------------------------
  // Recommendations
  // ---------------------------------------------------------------------------

  Future<Result<List<Track>>> getRecommendations(String trackId) {
    final provider = _registry.activeProvider;
    if (provider == null) return _noProvider();
    return provider.getRecommendations(trackId);
  }

  // ---------------------------------------------------------------------------
  // Active provider info
  // ---------------------------------------------------------------------------

  /// Display name of the currently active provider, or `null` if none.
  String? get activeProviderName => _registry.activeProvider?.displayName;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<Result<T>> _noProvider<T>() async =>
      const Result.failure('No active provider');
}
