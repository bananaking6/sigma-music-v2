import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'app/app_bootstrap.dart';
import 'core/models/search_result.dart';
import 'core/models/track.dart';
import 'core/result/result.dart';
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

  Future<void> _playTrack(Track track) async {
    setState(() {
      _isLoadingPlayback = true;
      _playbackError = null;
    });

    final streamInfoResult = await widget.repository.getStreamInfo(
      track.id,
      quality: AudioQuality.high,
    );

    if (!mounted) return;

    if (streamInfoResult is Failure) {
      setState(() {
        _isLoadingPlayback = false;
        _playbackError = streamInfoResult.message;
      });
      return;
    }

    final info = streamInfoResult.valueOrNull;
    final streamUrl = info?.streamUrl;
    if (streamUrl == null || streamUrl.isEmpty) {
      setState(() {
        _isLoadingPlayback = false;
        _playbackError =
            'Stream URL unavailable for this track. Manifest playback is not wired yet.';
      });
      return;
    }

    try {
      final playableUri = _parsePlayableStreamUri(streamUrl);
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
      appBar: AppBar(title: const Text('Sigma Music')),
      body: IndexedStack(index: _selectedTabIndex, children: pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_nowPlaying != null)
            _NowPlayingBar(
              track: _nowPlaying!,
              player: _audioPlayer,
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
                            subtitle: Text('${album.artist.name} • details coming soon'),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Album details are coming soon. Tap a track result to play.',
                                  ),
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
                            subtitle: const Text('Artist details coming soon'),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Artist details are coming soon. Tap a track result to play.',
                                  ),
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
    required this.onStop,
  });

  final Track track;
  final AudioPlayer player;
  final Future<void> Function() onStop;

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
