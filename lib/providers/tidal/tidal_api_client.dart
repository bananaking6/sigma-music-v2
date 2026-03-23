import 'package:sigma_music/core/errors/app_error.dart';
import 'package:sigma_music/core/models/album.dart';
import 'package:sigma_music/core/models/artist.dart';
import 'package:sigma_music/core/models/audio_stream_info.dart';
import 'package:sigma_music/core/models/lyrics.dart';
import 'package:sigma_music/core/models/playlist.dart';
import 'package:sigma_music/core/models/search_result.dart';
import 'package:sigma_music/core/models/track.dart';
import 'package:sigma_music/providers/tidal/tidal_mapper.dart';

/// Raw HTTP client for the Tidal metadata/streaming API.
///
/// All methods return plain Dart objects decoded by [TidalMapper].
/// The caller ([TidalProviderPlugin]) is responsible for wrapping the results
/// in [Result] and handling errors.
///
/// The [_get] function is injected so the networking layer (Dio / http) can
/// be swapped without touching this class.
class TidalApiClient {
  TidalApiClient({
    required Future<Map<String, dynamic>> Function(String path,
        {Map<String, dynamic>? params}) get,
    required Future<List<dynamic>> Function(String path,
        {Map<String, dynamic>? params}) getList,
  })  : _get = get,
        _getList = getList;

  final Future<Map<String, dynamic>> Function(
    String path, {
    Map<String, dynamic>? params,
  }) _get;

  final Future<List<dynamic>> Function(
    String path, {
    Map<String, dynamic>? params,
  }) _getList;

  final TidalMapper _mapper = const TidalMapper();

  // ---------------------------------------------------------------------------
  // Track
  // ---------------------------------------------------------------------------

  /// `GET /info?id=<id>`
  Future<Track> getTrackInfo(String id) async {
    final json = await _get('/info', params: {'id': id});
    return _mapper.trackFromJson(json);
  }

  /// `GET /track?id=<id>&quality=<quality>`
  Future<AudioStreamInfo> getStreamInfo(
    String id,
    String quality,
  ) async {
    final json = await _get('/track', params: {'id': id, 'quality': quality});
    return _mapper.streamInfoFromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// `GET /search?s=<query>&limit=<limit>` – track search.
  Future<List<SearchResultItem>> searchTracks(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    final list = await _getList('/search', params: {
      's': query,
      'limit': limit,
      'offset': offset,
    });
    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => TrackResult(_mapper.trackFromJson(j)))
        .toList();
  }

  /// `GET /search?al=<query>&limit=<limit>` – album search.
  Future<List<SearchResultItem>> searchAlbums(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    final list = await _getList('/search', params: {
      'al': query,
      'limit': limit,
      'offset': offset,
    });
    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => AlbumResult(_mapper.albumFromJson(j)))
        .toList();
  }

  /// `GET /search?a=<query>&limit=<limit>` – artist search.
  Future<List<SearchResultItem>> searchArtists(
    String query, {
    int limit = 25,
    int offset = 0,
  }) async {
    final list = await _getList('/search', params: {
      'a': query,
      'limit': limit,
      'offset': offset,
    });
    return list
        .whereType<Map<String, dynamic>>()
        .map((j) => ArtistResult(_mapper.artistFromJson(j)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Album / Artist
  // ---------------------------------------------------------------------------

  /// `GET /album?id=<id>`
  Future<Album> getAlbum(String id, {int limit = 100, int offset = 0}) async {
    final json =
        await _get('/album', params: {'id': id, 'limit': limit, 'offset': offset});
    return _mapper.albumFromJson(json);
  }

  /// `GET /artist?id=<id>`
  Future<Artist> getArtist(String id) async {
    final json = await _get('/artist', params: {'id': id});
    return _mapper.artistFromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Lyrics & recommendations
  // ---------------------------------------------------------------------------

  /// `GET /lyrics?id=<id>`
  Future<Lyrics> getLyrics(String id) async {
    final json = await _get('/lyrics', params: {'id': id});
    return _mapper.lyricsFromJson(id, json);
  }

  /// `GET /recommendations?id=<id>`
  Future<List<Track>> getRecommendations(String id) async {
    final list = await _getList('/recommendations', params: {'id': id});
    return list
        .whereType<Map<String, dynamic>>()
        .map(_mapper.trackFromJson)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Playlists (stub – requires auth; included for interface completeness)
  // ---------------------------------------------------------------------------

  Future<List<Playlist>> getUserPlaylists() async {
    throw const UnsupportedOperationError(
      'Playlist listing requires authentication which is not yet implemented.',
    );
  }

  Future<Playlist> getPlaylistById(String id) async {
    throw const UnsupportedOperationError(
      'Playlist retrieval requires authentication which is not yet implemented.',
    );
  }
}
