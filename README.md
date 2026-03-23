# Sigma Music v2

A cross-platform Flutter music player for Android and iOS built on a **plugin-based provider architecture** — adding a new music source is as simple as implementing one interface.

---

## Architecture overview

```
lib/
├── app/
│   └── app_bootstrap.dart       # Wires providers + exposes UnifiedMusicRepository
├── core/
│   ├── plugin/
│   │   ├── music_provider_plugin.dart   # Provider contract (interface)
│   │   ├── provider_capabilities.dart   # ProviderCapability enum
│   │   ├── provider_registry.dart       # Registry + lifecycle manager
│   │   └── provider_types.dart          # ProviderType enum
│   ├── models/
│   │   ├── track.dart           # Track + AudioQuality enum
│   │   ├── album.dart
│   │   ├── artist.dart
│   │   ├── playlist.dart
│   │   ├── lyrics.dart          # Lyrics + LyricsLine (synced)
│   │   ├── search_result.dart   # Sealed SearchResultItem hierarchy
│   │   └── audio_stream_info.dart
│   ├── errors/
│   │   └── app_error.dart       # Typed error hierarchy
│   └── result/
│       └── result.dart          # Generic Result<T> (Success / Failure)
├── providers/
│   ├── tidal/
│   │   ├── tidal_provider_plugin.dart   # TIDAL plugin (no auth)
│   │   ├── tidal_api_client.dart        # Raw API client
│   │   ├── tidal_endpoint_resolver.dart # Endpoint discovery + rotation
│   │   └── tidal_mapper.dart            # JSON → domain model mappers
│   └── local/
│       ├── local_provider_plugin.dart   # Local files plugin
│       └── local_indexer_service.dart   # In-memory media index scaffold
├── features/
│   └── playback/
│       └── unified_music_repository.dart  # Provider-agnostic app API
└── main.dart                    # Entry point
```

---

## Provider plugin concept

Every music source implements `MusicProviderPlugin`:

```dart
abstract interface class MusicProviderPlugin {
  String get id;           // unique machine id, e.g. "tidal"
  String get displayName;  // shown in UI
  ProviderType get type;   // cloud / local / hybrid
  Set<ProviderCapability> get capabilities;

  Future<Result<void>> initialize();
  Future<Result<List<SearchResultItem>>> search(String query, {int limit});
  Future<Result<Track>> getTrackById(String id);
  Future<Result<AudioStreamInfo>> getStreamInfo(String trackId, {AudioQuality quality});
  Future<Result<Lyrics>> getLyrics(String trackId);
  // ... see music_provider_plugin.dart for full contract
}
```

Features never depend on concrete providers.  They only use `UnifiedMusicRepository`, which delegates to whichever provider is currently active.

---

## How to add a new provider

1. **Create a plugin class** inside `lib/providers/<name>/`:

```dart
class SpotifyProviderPlugin implements MusicProviderPlugin {
  @override String get id => 'spotify';
  @override ProviderType get type => ProviderType.cloud;
  @override Set<ProviderCapability> get capabilities => {
    ProviderCapability.search,
    ProviderCapability.streaming,
  };

  @override Future<Result<void>> initialize() async { /* … */ }
  // implement remaining methods …
}
```

2. **Register** the plugin in `AppBootstrap.initialize()`:

```dart
_registry.register(SpotifyProviderPlugin());
```

3. **Done.**  The rest of the app discovers capabilities automatically.

---

## Current providers

| Provider | Status | Capabilities |
|---|---|---|
| **TIDAL** (no-auth) | ✅ Functional scaffold | search, streaming, lyrics, recommendations, playlists*, gapless-ready |
| **Local Files** | 🔧 Scaffold | search, streaming (file://), local-files, downloads |

\* TIDAL playlists require auth — not yet implemented.

---

## Endpoint fallback behaviour

`TidalEndpointResolver` fetches a live list of healthy API servers from:

```
https://tidal-uptime.jiffy-puffs-1j.workers.dev/
```

The response contains `api[]` and `streaming[]` arrays with `url` and `version` fields.  The resolver:

1. Sorts endpoints by version (highest first).
2. Caches the ranked list for 30 minutes.
3. On network failure, `rotateMetadata()` / `rotateStreaming()` advances to the next endpoint.
4. Falls back to `https://api.monochrome.tf` if discovery is unavailable.

---

## Result type

All provider and repository methods return `Result<T>`:

```dart
final result = await repo.search('Radiohead');
switch (result) {
  case Success(:final value): print('Found ${value.length} results');
  case Failure(:final message): print('Error: $message');
}
```

---

## Next recommended steps

- **Player engine** — integrate `just_audio` + `audio_service` in `PlaybackController`; wire up `UnifiedMusicRepository.getStreamInfo` to produce `AudioSource` objects.
- **Downloads / offline** — use `background_downloader`; implement `downloadTrack` in TIDAL plugin with license manifest handling.
- **Lyrics sync UI** — stream playback position against `Lyrics.syncedLines` to highlight the current line.
- **Playlist transfer** — port the JS Apple Music / Spotify → TIDAL ISRC-matching logic to Dart services.
- **Auth for TIDAL** — add OAuth2 flow and unlock `getUserPlaylists` / user library endpoints.
- **Real local indexer** — replace `LocalIndexerService` scaffold with `on_audio_query` integration.