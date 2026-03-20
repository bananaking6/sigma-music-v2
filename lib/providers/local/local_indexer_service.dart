import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/playlist.dart';
import '../../core/models/track.dart';

/// Scaffold service that indexes local audio files.
///
/// A real implementation would:
/// - Use `on_audio_query` or `flutter_media_metadata` to scan device storage.
/// - Parse ID3 / VorbisComment tags.
/// - Persist the index to a local database (e.g. Drift).
///
/// For now this provides a compile-ready, in-memory scaffold with empty
/// collections that can be swapped for a real indexer without changing the
/// plugin interface.
class LocalIndexerService {
  final Map<String, Track> _tracks = {};
  final Map<String, Album> _albums = {};
  final Map<String, Artist> _artists = {};
  final Map<String, Playlist> _playlists = {};
  final Map<String, String> _filePaths = {};

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Scans the device library and populates the in-memory index.
  ///
  /// TODO: implement real media store scan using `on_audio_query`.
  Future<void> scanLibrary() async {
    // Placeholder: no-op in scaffold.
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  Track? trackById(String id) => _tracks[id];
  Album? albumById(String id) => _albums[id];
  Artist? artistById(String id) => _artists[id];
  Playlist? playlistById(String id) => _playlists[id];

  /// Returns the absolute file-system path for the given track ID, or `null`.
  String? filePathForTrack(String id) => _filePaths[id];

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Simple case-insensitive title / artist search over the in-memory index.
  List<Track> search(String query, {int limit = 25}) {
    final q = query.toLowerCase();
    return _tracks.values
        .where(
          (t) =>
              t.title.toLowerCase().contains(q) ||
              t.artist.name.toLowerCase().contains(q),
        )
        .take(limit)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  List<Track> get allTracks => _tracks.values.toList();
  List<Album> get allAlbums => _albums.values.toList();
  List<Artist> get allArtists => _artists.values.toList();
  List<Playlist> get playlists => _playlists.values.toList();

  // ---------------------------------------------------------------------------
  // Mutations (used when integrating a real media store scanner)
  // ---------------------------------------------------------------------------

  void addTrack(Track track, {String? filePath}) {
    _tracks[track.id] = track;
    if (filePath != null) _filePaths[track.id] = filePath;
  }

  void addAlbum(Album album) => _albums[album.id] = album;
  void addArtist(Artist artist) => _artists[artist.id] = artist;
  void addPlaylist(Playlist playlist) => _playlists[playlist.id] = playlist;
}
