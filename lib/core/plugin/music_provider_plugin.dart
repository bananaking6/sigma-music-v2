import '../models/album.dart';
import '../models/artist.dart';
import '../models/audio_stream_info.dart';
import '../models/lyrics.dart';
import '../models/playlist.dart';
import '../models/search_result.dart';
import '../models/track.dart';
import '../result/result.dart';
import 'provider_capabilities.dart';
import 'provider_types.dart';

/// Contract that every music provider must implement.
///
/// Providers are discovered and managed by [ProviderRegistry].  All app
/// features talk to providers through [UnifiedMusicRepository], never
/// directly.
///
/// ## Adding a new provider
/// 1. Create a class that `implements MusicProviderPlugin`.
/// 2. Implement every required method (return `Result.failure` where the
///    operation is genuinely unsupported).
/// 3. Override [capabilities] to advertise what your provider can do.
/// 4. Register the plugin in the bootstrap wiring (`AppBootstrap`).
abstract interface class MusicProviderPlugin {
  // ---------------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------------

  /// Unique machine-readable identifier, e.g. `"tidal"` or `"local"`.
  String get id;

  /// Human-readable name shown in the UI, e.g. `"TIDAL"`.
  String get displayName;

  /// Broad category of this provider.
  ProviderType get type;

  /// Set of capabilities this provider supports. Used by the registry and
  /// repository for routing and fallback logic.
  Set<ProviderCapability> get capabilities;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Called once by [ProviderRegistry.initializeAll] before the provider is
  /// used.  Perform network probes, endpoint discovery, or permission checks
  /// here.
  Future<Result<void>> initialize();

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Full-text search across tracks, albums, and artists.
  ///
  /// Returns a heterogeneous list of [SearchResultItem] subtypes
  /// ([TrackResult], [AlbumResult], [ArtistResult]).
  Future<Result<List<SearchResultItem>>> search(
    String query, {
    int limit = 25,
  });

  // ---------------------------------------------------------------------------
  // Entity lookup
  // ---------------------------------------------------------------------------

  Future<Result<Track>> getTrackById(String id);

  Future<Result<Album>> getAlbumById(String id);

  Future<Result<Artist>> getArtistById(String id);

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  /// Returns the information needed to start playback of [trackId].
  ///
  /// [quality] defaults to [AudioQuality.hiResLossless]; providers that do not
  /// support the requested quality should fall back gracefully.
  Future<Result<AudioStreamInfo>> getStreamInfo(
    String trackId, {
    AudioQuality quality = AudioQuality.hiResLossless,
  });

  // ---------------------------------------------------------------------------
  // Lyrics & recommendations
  // ---------------------------------------------------------------------------

  Future<Result<Lyrics>> getLyrics(String trackId);

  Future<Result<List<Track>>> getRecommendations(String trackId);

  // ---------------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------------

  Future<Result<List<Playlist>>> getUserPlaylists();

  Future<Result<Playlist>> getPlaylistById(String id);

  // ---------------------------------------------------------------------------
  // Optional hooks (safe defaults provided)
  // ---------------------------------------------------------------------------

  /// Downloads [trackId] to local storage for offline playback.
  ///
  /// Providers that do not support downloads return a failure by default.
  Future<Result<void>> downloadTrack(String trackId) async {
    return const Result.failure('Download not supported by this provider');
  }

  /// Returns `true` if [trackId] is already available offline.
  Future<Result<bool>> isTrackDownloaded(String trackId) async {
    return const Result.success(false);
  }
}
