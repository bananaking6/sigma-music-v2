import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'app/app_bootstrap.dart';
import 'core/models/album.dart';
import 'core/models/artist.dart';
import 'core/models/lyrics.dart';
import 'core/models/search_result.dart';
import 'core/models/track.dart';
import 'core/result/result.dart';
import 'features/playback/lyrics_display.dart';
import 'features/playback/playback_queue.dart';
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
      home: _HomeShell(repository: repository),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.repository});

  final UnifiedMusicRepository repository;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final PlaybackQueue _queue = PlaybackQueue();

  int _selectedTabIndex = 0;
  Track? _nowPlaying;
  bool _isLoadingPlayback = false;
  String? _playbackError;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Uri? _parsePlayableStreamUri(String streamUrl) {
    if (streamUrl.startsWith('/')) {
      return Uri.file(streamUrl);
    }

    final uri = Uri.tryParse(streamUrl);
    if (uri == null) return null;
    if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'file') {
      return uri;
    }
    return null;
  }

  String? _extractPlayableUrlFromManifest(String manifestBase64) {
    String decoded;
    try {
      decoded = utf8.decode(base64Decode(manifestBase64));
    } catch (_) {
      return null;
    }

    try {
      final dynamic json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        final urls = json['urls'];
        if (urls is List) {
          for (final url in urls) {
            if (url is String && url.isNotEmpty) return url;
          }
        }
        for (final key in ['url', 'manifestUrl']) {
          final value = json[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } catch (_) {
      // Not JSON; try XML-like manifests below.
    }

    final baseUrlMatch = RegExp(
      r'<BaseURL>\s*(https?://[^<\s]+)\s*</BaseURL>',
      caseSensitive: false,
    ).firstMatch(decoded);
    return baseUrlMatch?.group(1);
  }

  Future<void> _skipToNext() async {
    final nextTrack = _queue.next();
    if (nextTrack != null) {
      await _playTrackFromQueue(nextTrack);
    }
  }

  Future<void> _skipToPrevious() async {
    final previousTrack = _queue.previous();
    if (previousTrack != null) {
      await _playTrackFromQueue(previousTrack);
    }
  }

  /// Play a track and add it to the queue (from search/home)
  Future<void> _playTrack(Track track) async {
    // Add track to queue
    _queue.add(track);
    
    // Jump to this track in the queue
    _queue.jumpTo(_queue.length - 1);
    
    await _playTrackFromQueue(track);
  }

  /// Internal method to play the given track without modifying queue
  Future<void> _playTrackFromQueue(Track track) async {
    setState(() {
      _isLoadingPlayback = true;
      _playbackError = null;
    });

    final streamInfoResult = await widget.repository.getStreamInfo(
      track.id,
      quality: AudioQuality.low,
    );

    if (!mounted) return;

    if (streamInfoResult is Failure) {
      setState(() {
        _isLoadingPlayback = false;
        _playbackError = streamInfoResult.errorMessage ?? 'Unknown error';
      });
      return;
    }

    final info = streamInfoResult.valueOrNull;
    final streamUrl = info?.streamUrl?.trim();
    final manifestUrl = (info?.manifestBase64 != null &&
            info!.manifestBase64!.isNotEmpty)
        ? _extractPlayableUrlFromManifest(info.manifestBase64!)
        : null;
    final resolvedStreamUrl = (streamUrl != null && streamUrl.isNotEmpty)
        ? streamUrl
        : manifestUrl;

    if (resolvedStreamUrl == null || resolvedStreamUrl.isEmpty) {
      setState(() {
        _isLoadingPlayback = false;
        _playbackError = 'Unable to play this track. Please try another one.';
      });
      return;
    }

    try {
      final playableUri = _parsePlayableStreamUri(resolvedStreamUrl);
      if (playableUri == null) {
        setState(() {
          _isLoadingPlayback = false;
          _playbackError = 'Invalid stream URL returned for this track.';
        });
        return;
      }

      if (playableUri.scheme == 'file') {
        await _audioPlayer.setFilePath(playableUri.toFilePath());
      } else {
        await _audioPlayer.setUrl(playableUri.toString());
      }
      await _audioPlayer.play();
      if (!mounted) return;
      setState(() {
        _isLoadingPlayback = false;
        _nowPlaying = track;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPlayback = false;
        _playbackError = 'Failed to start playback: $e';
      });
    }
  }

  void _showQueueDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _QueueDialog(
        queue: _queue,
        currentTrackId: _nowPlaying?.id,
        onTrackSelected: (track) {
          Navigator.pop(context);
          _playTrack(track);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        repository: widget.repository,
        nowPlaying: _nowPlaying,
        playbackError: _playbackError,
      ),
      _SearchTab(
        repository: widget.repository,
        onTrackPlayRequested: _playTrack,
        playingTrackId: _nowPlaying?.id,
        isLoadingPlayback: _isLoadingPlayback,
      ),
      const _LibraryTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sigma Music'),
        actions: [
          if (_queue.length > 0)
            Semantics(
              button: true,
              label: 'Show queue',
              child: IconButton(
                onPressed: _showQueueDialog,
                icon: const Icon(Icons.playlist_play),
                tooltip: 'Queue (${_queue.length})',
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _selectedTabIndex, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_nowPlaying != null)
            _NowPlayingBar(
              track: _nowPlaying!,
              player: _audioPlayer,
              repository: widget.repository,
              onSkipNext: _queue.hasNext ? _skipToNext : null,
              onSkipPrevious: _queue.hasPrevious ? _skipToPrevious : null,
              hasNext: _queue.hasNext,
              hasPrevious: _queue.hasPrevious,
              onStop: () async {
                try {
                  await _audioPlayer.stop();
                  if (mounted) {
                    setState(() {
                      _nowPlaying = null;
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      _playbackError = 'Failed to stop playback: $e';
                    });
                  }
                }
              },
            ),
          NavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: 'Library',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.repository,
    required this.nowPlaying,
    required this.playbackError,
  });

  final UnifiedMusicRepository repository;
  final Track? nowPlaying;
  final String? playbackError;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('Active provider'),
            subtitle: Text(repository.activeProviderName ?? 'None'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Now playing'),
            subtitle: Text(
              nowPlaying == null
                  ? 'Use Search to find and play a track'
                  : '${nowPlaying!.title} • ${nowPlaying!.artist.name}',
            ),
          ),
        ),
        if (playbackError != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              title: Text(
                'Playback error',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              subtitle: Text(
                playbackError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchTab extends StatefulWidget {
  const _SearchTab({
    required this.repository,
    required this.onTrackPlayRequested,
    required this.playingTrackId,
    required this.isLoadingPlayback,
  });

  final UnifiedMusicRepository repository;
  final Future<void> Function(Track track) onTrackPlayRequested;
  final String? playingTrackId;
  final bool isLoadingPlayback;

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final TextEditingController _controller = TextEditingController();

  bool _isSearching = false;
  String? _searchError;
  List<SearchResultItem> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final result = await widget.repository.search(query, limit: 30);
    if (!mounted) return;

    if (result is Success<List<SearchResultItem>>) {
      setState(() {
        _isSearching = false;
        _results = result.value;
      });
      return;
    }

    if (result is Failure<List<SearchResultItem>>) {
      setState(() {
        _isSearching = false;
        _results = const [];
        _searchError = result.message;
      });
      return;
    }
    setState(() {
      _isSearching = false;
      _results = const [];
      _searchError = 'Search failed. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: const InputDecoration(
                    hintText: 'Search tracks, artists, albums',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSearching ? null : _runSearch,
                child: const Text('Go'),
              ),
            ],
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(minHeight: 2),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _searchError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Run a search to load results.\nTap a track to play it.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return switch (item) {
                      TrackResult(:final track) => Semantics(
                          button: true,
                          label: widget.playingTrackId == track.id
                              ? 'Currently playing track ${track.title}'
                              : 'Play track ${track.title}',
                          child: ListTile(
                            leading: const Icon(Icons.music_note),
                            title: Text(track.title),
                            subtitle:
                                Text('${track.artist.name} • ${track.album.title}'),
                            trailing: Icon(
                              widget.playingTrackId == track.id
                                  ? Icons.equalizer
                                  : Icons.play_arrow,
                            ),
                            onTap: widget.isLoadingPlayback
                                ? null
                                : () => widget.onTrackPlayRequested(track),
                          ),
                        ),
                      AlbumResult(:final album) => Semantics(
                          button: true,
                          label: 'View album details for ${album.title}',
                          child: ListTile(
                            leading: const Icon(Icons.album_outlined),
                            title: Text(album.title),
                            subtitle: Text(album.artist.name),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _AlbumDetailsPage(album: album),
                                ),
                              );
                            },
                          ),
                        ),
                      ArtistResult(:final artist) => Semantics(
                          button: true,
                          label: 'View artist details for ${artist.name}',
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(artist.name),
                            subtitle: const Text('Artist information'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _ArtistDetailsPage(artist: artist),
                                ),
                              );
                            },
                          ),
                        ),
                    };
                  },
                ),
        ),
      ],
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({
    required this.track,
    required this.player,
    required this.repository,
    required this.onStop,
    this.onSkipNext,
    this.onSkipPrevious,
    this.hasNext = false,
    this.hasPrevious = false,
  });

  final Track track;
  final AudioPlayer player;
  final UnifiedMusicRepository repository;
  final Future<void> Function() onStop;
  final Future<void> Function()? onSkipNext;
  final Future<void> Function()? onSkipPrevious;
  final bool hasNext;
  final bool hasPrevious;

  Future<void> _showLyrics(BuildContext context) async {
    final result = await repository.getLyricsBestEffort(track.id);
    
    if (!context.mounted) return;
    
    final lyrics = result is Success ? result.valueOrNull : null;
    
    showDialog(
      context: context,
      builder: (context) => LyricsDisplay(
        lyrics: lyrics,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        bottom: false,
        child: StreamBuilder<bool>(
          stream: player.playingStream,
          initialData: player.playing,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data ?? false;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.graphic_eq),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                track.artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    button: true,
                    label: 'View lyrics',
                    child: IconButton(
                      onPressed: () => _showLyrics(context),
                      icon: const Icon(Icons.lyrics),
                    ),
                  ),
                  if (onSkipPrevious != null)
                    Semantics(
                      button: true,
                      label: 'Previous track',
                      child: IconButton(
                        onPressed: hasPrevious
                            ? () async {
                                try {
                                  await onSkipPrevious!();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Skip failed: $e')),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.skip_previous),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: isPlaying ? 'Pause playback' : 'Resume playback',
                    child: IconButton(
                      onPressed: () async {
                        try {
                          if (isPlaying) {
                            await player.pause();
                          } else {
                            await player.play();
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Playback control failed: $e')),
                          );
                        }
                      },
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                  ),
                  if (onSkipNext != null)
                    Semantics(
                      button: true,
                      label: 'Next track',
                      child: IconButton(
                        onPressed: hasNext
                            ? () async {
                                try {
                                  await onSkipNext!();
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Skip failed: $e')),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: 'Stop playback',
                    child: IconButton(
                      onPressed: onStop,
                      icon: const Icon(Icons.stop),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Library UI scaffold\n\n'
          'Local and cloud library screens will appear here once indexing and '
          'playlists are fully connected.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _QueueDialog extends StatelessWidget {
  const _QueueDialog({
    required this.queue,
    required this.currentTrackId,
    required this.onTrackSelected,
  });

  final PlaybackQueue queue;
  final String? currentTrackId;
  final Function(Track) onTrackSelected;

  @override
  Widget build(BuildContext context) {
    final tracks = queue.tracks;
    
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Queue (${tracks.length})',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tracks.isEmpty
                  ? Center(
                      child: Text(
                        'Queue is empty',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        final isCurrentTrack = track.id == currentTrackId;
                        
                        return ListTile(
                          selected: isCurrentTrack,
                          leading: isCurrentTrack
                              ? const Icon(Icons.music_note)
                              : Text('${index + 1}'),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrentTrack
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            track.artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onTrackSelected(track),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _AlbumDetailsPage extends StatelessWidget {
  const _AlbumDetailsPage({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Album')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.album),
              title: Text(album.title),
              subtitle: Text(album.artist.name),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('Tracks'),
              subtitle: Text(
                album.tracks.isEmpty
                    ? 'Track list unavailable'
                    : '${album.tracks.length} tracks',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistDetailsPage extends StatelessWidget {
  const _ArtistDetailsPage({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text(artist.name),
              subtitle: Text(
                artist.popularity == null
                    ? 'Popularity unavailable'
                    : 'Popularity: ${artist.popularity}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.music_note_outlined),
              title: Text('Top tracks'),
              subtitle: Text('Coming next: top tracks and discography'),
            ),
          ),
        ],
      ),
    );
  }
}
