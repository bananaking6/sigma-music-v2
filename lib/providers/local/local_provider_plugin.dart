import 'package:sigma_music/core/models/album.dart';
import 'package:sigma_music/core/models/artist.dart';
import 'package:sigma_music/core/models/audio_stream_info.dart';
import 'package:sigma_music/core/models/lyrics.dart';
import 'package:sigma_music/core/models/playlist.dart';
import 'package:sigma_music/core/models/search_result.dart';
import 'package:sigma_music/core/models/track.dart';
import 'package:sigma_music/core/plugin/music_provider_plugin.dart';
import 'package:sigma_music/core/plugin/provider_capabilities.dart';
import 'package:sigma_music/core/plugin/provider_types.dart';
import 'package:sigma_music/core/result/result.dart';
import 'package:sigma_music/providers/local/local_indexer_service.dart';

/// Scaffold implementation of a local-files music provider.
///
/// This plugin reads audio files from the device storage via
/// [LocalIndexerService].  The implementation is intentionally minimal and
/// serves as a compile-ready scaffold that can be fleshed out with a real
/// media-store / file-picker integration later.
class LocalFilesProviderPlugin implements MusicProviderPlugin {
  LocalFilesProviderPlugin({
    LocalIndexerService? indexer,
  }) : _indexer = indexer ?? LocalIndexerService();

  final LocalIndexerService _indexer;

  // ---------------------------------------------------------------------------
  // MusicProviderPlugin identity
  // ---------------------------------------------------------------------------

  @override
  String get id => 'local';

  @override
  String get displayName => 'Local Files';

  @override
  ProviderType get type => ProviderType.local;

  @override
  Set<ProviderCapability> get capabilities => const {
        ProviderCapability.search,
        ProviderCapability.streaming,
        ProviderCapability.localFiles,
        ProviderCapability.downloads,
      };

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void>> initialize() async {
    try {
      await _indexer.scanLibrary();
      return const Result.success(null);
    } catch (e) {
      // Non-fatal: provider still usable once the user grants permission.
      return Result.failure('Local library scan failed: $e', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<SearchResultItem>>> search(
    String query, {
    int limit = 25,
  }) async {
    final matches = _indexer.search(query, limit: limit);
    final results = matches
        .map((t) => TrackResult(t) as SearchResultItem)
        .toList();
    return Result.success(results);
  }

  // ---------------------------------------------------------------------------
  // Entity lookup
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Track>> getTrackById(String id) async {
    final track = _indexer.trackById(id);
    if (track == null) return Result.failure('Local track $id not found');
    return Result.success(track);
  }

  @override
  Future<Result<Album>> getAlbumById(String id) async {
    final album = _indexer.albumById(id);
    if (album == null) return Result.failure('Local album $id not found');
    return Result.success(album);
  }

  @override
  Future<Result<Artist>> getArtistById(String id) async {
    final artist = _indexer.artistById(id);
    if (artist == null) return Result.failure('Local artist $id not found');
    return Result.success(artist);
  }

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  @override
  Future<Result<AudioStreamInfo>> getStreamInfo(
    String trackId, {
    AudioQuality quality = AudioQuality.hiResLossless,
  }) async {
    final track = _indexer.trackById(trackId);
    if (track == null) {
      return Result.failure('Local track $trackId not found');
    }

    final filePath = _indexer.filePathForTrack(trackId);
    if (filePath == null) {
      return Result.failure('File path for track $trackId not found');
    }

    return Result.success(
      AudioStreamInfo(
        trackId: trackId,
        audioQuality: AudioQuality.lossless,
        mimeType: 'audio/flac',
        streamUrl: 'file://$filePath',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lyrics & recommendations
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Lyrics>> getLyrics(String trackId) async {
    return const Result.failure('Lyrics not available for local files');
  }

  @override
  Future<Result<List<Track>>> getRecommendations(String trackId) async {
    return const Result.failure('Recommendations not available for local files');
  }

  // ---------------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Playlist>>> getUserPlaylists() async {
    return Result.success(_indexer.playlists);
  }

  @override
  Future<Result<Playlist>> getPlaylistById(String id) async {
    final playlist = _indexer.playlistById(id);
    if (playlist == null) {
      return Result.failure('Local playlist $id not found');
    }
    return Result.success(playlist);
  }

  // ---------------------------------------------------------------------------
  // Downloads (local files are already on-device)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void>> downloadTrack(String trackId) async {
    return const Result.failure(
      'Use the system file picker to add local tracks',
    );
  }

  @override
  Future<Result<bool>> isTrackDownloaded(String trackId) async {
    return Result.success(_indexer.trackById(trackId) != null);
  }
}
