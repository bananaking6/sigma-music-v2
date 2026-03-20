import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/errors/app_error.dart';
import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/audio_stream_info.dart';
import '../../core/models/lyrics.dart';
import '../../core/models/playlist.dart';
import '../../core/models/search_result.dart';
import '../../core/models/track.dart';
import '../../core/plugin/music_provider_plugin.dart';
import '../../core/plugin/provider_capabilities.dart';
import '../../core/plugin/provider_types.dart';
import '../../core/result/result.dart';
import 'tidal_api_client.dart';
import 'tidal_endpoint_resolver.dart';

/// TIDAL music provider plugin (no-auth implementation).
///
/// Uses the open TIDAL metadata API.  Authentication is intentionally not
/// implemented; the plugin provides search, metadata, streaming, lyrics, and
/// recommendations without a user account.
///
/// The [TidalEndpointResolver] is used on startup to discover and rank
/// available API endpoints.  All HTTP requests are routed through [Dio] with
/// automatic retry and endpoint rotation on failure.
class TidalProviderPlugin implements MusicProviderPlugin {
  TidalProviderPlugin({
    TidalEndpointResolver? resolver,
    Dio? dio,
  }) : _dio = dio ?? Dio(),
       _resolver = resolver ??
           TidalEndpointResolver(
             httpGet: (url) async {
               final d = Dio();
               final resp = await d.get<String>(url);
               return resp.data ?? '{}';
             },
           );

  final Dio _dio;
  final TidalEndpointResolver _resolver;
  late TidalApiClient _client;

  // ---------------------------------------------------------------------------
  // MusicProviderPlugin identity
  // ---------------------------------------------------------------------------

  @override
  String get id => 'tidal';

  @override
  String get displayName => 'TIDAL';

  @override
  ProviderType get type => ProviderType.cloud;

  @override
  Set<ProviderCapability> get capabilities => const {
        ProviderCapability.search,
        ProviderCapability.streaming,
        ProviderCapability.lyrics,
        ProviderCapability.recommendations,
        ProviderCapability.playlists,
        ProviderCapability.gaplessReady,
      };

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void>> initialize() async {
    try {
      // Discover and rank available endpoints.
      await _resolver.refresh();

      // Wire up the API client with injected HTTP helpers.
      _client = TidalApiClient(
        get: _getJson,
        getList: _getJsonList,
      );

      return const Result.success(null);
    } catch (e) {
      return Result.failure('TIDAL init failed: $e', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<SearchResultItem>>> search(
    String query, {
    int limit = 25,
  }) =>
      _wrap(() => _client.searchTracks(query, limit: limit));

  // ---------------------------------------------------------------------------
  // Entity lookup
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Track>> getTrackById(String id) =>
      _wrap(() => _client.getTrackInfo(id));

  @override
  Future<Result<Album>> getAlbumById(String id) =>
      _wrap(() => _client.getAlbum(id));

  @override
  Future<Result<Artist>> getArtistById(String id) =>
      _wrap(() => _client.getArtist(id));

  // ---------------------------------------------------------------------------
  // Streaming
  // ---------------------------------------------------------------------------

  @override
  Future<Result<AudioStreamInfo>> getStreamInfo(
    String trackId, {
    AudioQuality quality = AudioQuality.hiResLossless,
  }) =>
      _wrap(() => _client.getStreamInfo(trackId, quality.tidalValue));

  // ---------------------------------------------------------------------------
  // Lyrics & recommendations
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Lyrics>> getLyrics(String trackId) =>
      _wrap(() => _client.getLyrics(trackId));

  @override
  Future<Result<List<Track>>> getRecommendations(String trackId) =>
      _wrap(() => _client.getRecommendations(trackId));

  // ---------------------------------------------------------------------------
  // Playlists (auth not implemented)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Playlist>>> getUserPlaylists() async {
    return const Result.failure(
      'Playlist listing requires authentication (not yet implemented)',
    );
  }

  @override
  Future<Result<Playlist>> getPlaylistById(String id) async {
    return const Result.failure(
      'Playlist retrieval requires authentication (not yet implemented)',
    );
  }

  // ---------------------------------------------------------------------------
  // Offline hooks (not implemented for no-auth scaffold)
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void>> downloadTrack(String trackId) async {
    return const Result.failure(
      'Downloads require authentication (not yet implemented)',
    );
  }

  @override
  Future<Result<bool>> isTrackDownloaded(String trackId) async {
    return const Result.success(false);
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  /// Issues a GET request to [path] with optional query [params], retrying
  /// with endpoint rotation on network failures.
  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final url = '${_resolver.metadataBaseUrl}$path';
      try {
        final resp = await _dio.get<dynamic>(
          url,
          queryParameters: params,
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
        final data = resp.data;
        if (data is Map<String, dynamic>) return data;
        if (data is String) return jsonDecode(data) as Map<String, dynamic>;
        throw ParseError('Unexpected response type: ${data.runtimeType}');
      } on DioException catch (e) {
        if (attempt < 2 && _resolver.rotateMetadata()) continue;
        throw NetworkError(
          'GET $url failed: ${e.message}',
          statusCode: e.response?.statusCode,
        );
      }
    }
    throw const EndpointUnavailableError('All metadata endpoints failed');
  }

  Future<List<dynamic>> _getJsonList(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final url = '${_resolver.metadataBaseUrl}$path';
      try {
        final resp = await _dio.get<dynamic>(
          url,
          queryParameters: params,
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
        final data = resp.data;
        if (data is List) return data;
        if (data is String) return jsonDecode(data) as List<dynamic>;
        // Some endpoints wrap the list in a map; try common keys.
        if (data is Map<String, dynamic>) {
          for (final key in ['items', 'results', 'tracks', 'data']) {
            if (data[key] is List) return data[key] as List<dynamic>;
          }
        }
        return [];
      } on DioException catch (e) {
        if (attempt < 2 && _resolver.rotateMetadata()) continue;
        throw NetworkError(
          'GET $url failed: ${e.message}',
          statusCode: e.response?.statusCode,
        );
      }
    }
    throw const EndpointUnavailableError('All metadata endpoints failed');
  }

  // ---------------------------------------------------------------------------
  // Result wrapper
  // ---------------------------------------------------------------------------

  Future<Result<T>> _wrap<T>(Future<T> Function() call) async {
    try {
      return Result.success(await call());
    } on AppError catch (e) {
      return Result.failure(e.message, error: e);
    } catch (e) {
      return Result.failure('Unexpected error: $e', error: e);
    }
  }
}
