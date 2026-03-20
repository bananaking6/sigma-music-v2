import 'package:flutter_test/flutter_test.dart';
import 'package:sigma_music/core/errors/app_error.dart';
import 'package:sigma_music/core/models/album.dart';
import 'package:sigma_music/core/models/artist.dart';
import 'package:sigma_music/core/models/audio_stream_info.dart';
import 'package:sigma_music/core/models/lyrics.dart';
import 'package:sigma_music/core/models/playlist.dart';
import 'package:sigma_music/core/models/search_result.dart';
import 'package:sigma_music/core/models/track.dart';
import 'package:sigma_music/core/plugin/music_provider_plugin.dart';
import 'package:sigma_music/core/plugin/provider_capabilities.dart';
import 'package:sigma_music/core/plugin/provider_registry.dart';
import 'package:sigma_music/core/plugin/provider_types.dart';
import 'package:sigma_music/core/result/result.dart';
import 'package:sigma_music/features/playback/unified_music_repository.dart';

// ---------------------------------------------------------------------------
// Fake provider for testing
// ---------------------------------------------------------------------------

class FakeProvider implements MusicProviderPlugin {
  FakeProvider({
    required this.id,
    this.shouldFail = false,
    this.hasLyrics = true,
  });

  @override
  final String id;

  @override
  String get displayName => id.toUpperCase();

  @override
  ProviderType get type => ProviderType.cloud;

  @override
  Set<ProviderCapability> get capabilities => {
        ProviderCapability.search,
        ProviderCapability.streaming,
        if (hasLyrics) ProviderCapability.lyrics,
      };

  final bool shouldFail;
  final bool hasLyrics;

  static final _artist = const Artist(id: '1', name: 'Test Artist');
  static final _album = Album(
    id: '1',
    title: 'Test Album',
    artist: _artist,
  );
  static final _track = Track(
    id: '1',
    title: 'Test Track',
    durationMs: 180000,
    artist: _artist,
    album: _album,
  );

  @override
  Future<Result<void>> initialize() async =>
      shouldFail ? const Result.failure('init failed') : const Result.success(null);

  @override
  Future<Result<List<SearchResultItem>>> search(String query,
          {int limit = 25}) async =>
      shouldFail
          ? const Result.failure('search failed')
          : Result.success([TrackResult(_track)]);

  @override
  Future<Result<Track>> getTrackById(String id) async =>
      shouldFail ? const Result.failure('not found') : Result.success(_track);

  @override
  Future<Result<Album>> getAlbumById(String id) async =>
      shouldFail ? const Result.failure('not found') : Result.success(_album);

  @override
  Future<Result<Artist>> getArtistById(String id) async =>
      shouldFail ? const Result.failure('not found') : Result.success(_artist);

  @override
  Future<Result<AudioStreamInfo>> getStreamInfo(String trackId,
          {AudioQuality quality = AudioQuality.hiResLossless}) async =>
      shouldFail
          ? const Result.failure('stream failed')
          : Result.success(AudioStreamInfo(
              trackId: trackId,
              audioQuality: AudioQuality.lossless,
              mimeType: 'audio/flac',
              streamUrl: 'https://example.com/stream',
            ));

  @override
  Future<Result<Lyrics>> getLyrics(String trackId) async =>
      shouldFail
          ? const Result.failure('lyrics failed')
          : Result.success(Lyrics(
              trackId: trackId,
              plainText: 'Test lyrics',
              provider: 'fake',
            ));

  @override
  Future<Result<List<Track>>> getRecommendations(String trackId) async =>
      shouldFail
          ? const Result.failure('recs failed')
          : Result.success([_track]);

  @override
  Future<Result<List<Playlist>>> getUserPlaylists() async =>
      const Result.success([]);

  @override
  Future<Result<Playlist>> getPlaylistById(String id) async =>
      const Result.failure('not found');
}

// ---------------------------------------------------------------------------
// Result<T> tests
// ---------------------------------------------------------------------------

void main() {
  group('Result<T>', () {
    test('success holds value', () {
      const r = Result.success(42);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.valueOrNull, 42);
      expect(r.errorMessage, isNull);
    });

    test('failure holds message', () {
      const r = Result<int>.failure('oops');
      expect(r.isSuccess, isFalse);
      expect(r.isFailure, isTrue);
      expect(r.valueOrNull, isNull);
      expect(r.errorMessage, 'oops');
    });

    test('map transforms success', () {
      const r = Result.success(2);
      final mapped = r.map((v) => v * 3);
      expect(mapped.valueOrNull, 6);
    });

    test('map propagates failure', () {
      const r = Result<int>.failure('bad');
      final mapped = r.map((v) => v * 3);
      expect(mapped.isFailure, isTrue);
      expect(mapped.errorMessage, 'bad');
    });

    test('flatMap chains successes', () {
      const r = Result.success(5);
      final chained = r.flatMap((v) => Result.success(v + 1));
      expect(chained.valueOrNull, 6);
    });

    test('getOrElse returns fallback on failure', () {
      const r = Result<int>.failure('err');
      expect(r.getOrElse(99), 99);
    });
  });

  // ---------------------------------------------------------------------------
  // AppError hierarchy tests
  // ---------------------------------------------------------------------------

  group('AppError', () {
    test('NetworkError has message and statusCode', () {
      const e = NetworkError('timeout', statusCode: 504);
      expect(e.message, 'timeout');
      expect(e.statusCode, 504);
    });

    test('NotFoundError toString includes class name', () {
      const e = NotFoundError('missing resource');
      expect(e.toString(), contains('NotFoundError'));
    });
  });

  // ---------------------------------------------------------------------------
  // ProviderRegistry tests
  // ---------------------------------------------------------------------------

  group('ProviderRegistry', () {
    late ProviderRegistry registry;

    setUp(() => registry = ProviderRegistry());

    test('registers provider and sets it as active', () {
      final p = FakeProvider(id: 'fake');
      final result = registry.register(p);
      expect(result.isSuccess, isTrue);
      expect(registry.activeProvider?.id, 'fake');
    });

    test('rejects duplicate registration', () {
      final p = FakeProvider(id: 'fake');
      registry.register(p);
      final r2 = registry.register(FakeProvider(id: 'fake'));
      expect(r2.isFailure, isTrue);
    });

    test('setActiveProvider switches provider', () {
      registry.register(FakeProvider(id: 'a'));
      registry.register(FakeProvider(id: 'b'));
      registry.setActiveProvider('b');
      expect(registry.activeProvider?.id, 'b');
    });

    test('setActiveProvider fails for unknown id', () {
      final r = registry.setActiveProvider('unknown');
      expect(r.isFailure, isTrue);
    });

    test('providersWithCapability returns matching providers', () {
      registry.register(FakeProvider(id: 'a', hasLyrics: true));
      registry.register(FakeProvider(id: 'b', hasLyrics: false));
      final lyricProviders =
          registry.providersWithCapability(ProviderCapability.lyrics);
      expect(lyricProviders.length, 1);
      expect(lyricProviders.first.id, 'a');
    });

    test('byId returns correct provider', () {
      final p = FakeProvider(id: 'tidal');
      registry.register(p);
      expect(registry.byId('tidal'), same(p));
      expect(registry.byId('other'), isNull);
    });

    test('initializeAll succeeds when all providers succeed', () async {
      registry.register(FakeProvider(id: 'a'));
      registry.register(FakeProvider(id: 'b'));
      final r = await registry.initializeAll();
      expect(r.isSuccess, isTrue);
    });

    test('initializeAll fails fast on first provider failure', () async {
      registry.register(FakeProvider(id: 'bad', shouldFail: true));
      registry.register(FakeProvider(id: 'good'));
      final r = await registry.initializeAll();
      expect(r.isFailure, isTrue);
      expect(r.errorMessage, contains('bad'));
    });
  });

  // ---------------------------------------------------------------------------
  // UnifiedMusicRepository tests
  // ---------------------------------------------------------------------------

  group('UnifiedMusicRepository', () {
    late ProviderRegistry registry;
    late UnifiedMusicRepository repo;

    setUp(() {
      registry = ProviderRegistry()..register(FakeProvider(id: 'fake'));
      repo = UnifiedMusicRepository(registry);
    });

    test('search delegates to active provider', () async {
      final r = await repo.search('test');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, isNotEmpty);
    });

    test('returns failure when no active provider', () async {
      final emptyRegistry = ProviderRegistry();
      final emptyRepo = UnifiedMusicRepository(emptyRegistry);
      final r = await emptyRepo.search('test');
      expect(r.isFailure, isTrue);
    });

    test('getLyricsBestEffort returns lyrics from active provider', () async {
      final r = await repo.getLyricsBestEffort('1');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull?.plainText, 'Test lyrics');
    });

    test('getLyricsBestEffort falls back to secondary lyrics provider',
        () async {
      final failRegistry = ProviderRegistry()
        ..register(FakeProvider(id: 'main', shouldFail: true, hasLyrics: true))
        ..register(FakeProvider(id: 'fallback', hasLyrics: true));
      failRegistry.setActiveProvider('main');
      final failRepo = UnifiedMusicRepository(failRegistry);

      final r = await failRepo.getLyricsBestEffort('1');
      expect(r.isSuccess, isTrue);
    });

    test('getLyricsBestEffort fails when no lyrics provider available',
        () async {
      final noLyricsRegistry = ProviderRegistry()
        ..register(FakeProvider(id: 'nolyr', hasLyrics: false));
      final noLyricsRepo = UnifiedMusicRepository(noLyricsRegistry);

      final r = await noLyricsRepo.getLyricsBestEffort('1');
      expect(r.isFailure, isTrue);
    });

    test('getStreamInfo delegates and returns AudioStreamInfo', () async {
      final r = await repo.getStreamInfo('1');
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull?.trackId, '1');
    });
  });

  // ---------------------------------------------------------------------------
  // Model equality tests
  // ---------------------------------------------------------------------------

  group('Domain models equality', () {
    test('Track equality by id', () {
      const artist = Artist(id: 'a1', name: 'Artist');
      final album = Album(id: 'al1', title: 'Album', artist: artist);
      final t1 = Track(
          id: 't1', title: 'A', durationMs: 100, artist: artist, album: album);
      final t2 = Track(
          id: 't1', title: 'B', durationMs: 200, artist: artist, album: album);
      expect(t1, t2);
      expect(t1.hashCode, t2.hashCode);
    });

    test('AudioQuality roundtrip via tidalValue', () {
      for (final q in AudioQuality.values) {
        expect(AudioQuality.fromTidalValue(q.tidalValue), q);
      }
    });

    test('Track.duration converts ms to Duration', () {
      const artist = Artist(id: 'a', name: 'A');
      final album = Album(id: 'al', title: 'Al', artist: artist);
      final track =
          Track(id: 't', title: 'T', durationMs: 60000, artist: artist, album: album);
      expect(track.duration, const Duration(minutes: 1));
    });
  });
}
