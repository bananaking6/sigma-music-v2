import '../../core/models/track.dart';

/// Manages a queue of tracks for playback.
class PlaybackQueue {
  PlaybackQueue({
    List<Track>? tracks,
    int currentIndex = 0,
  })  : _tracks = tracks ?? [],
        _currentIndex = currentIndex;

  final List<Track> _tracks;
  int _currentIndex;

  /// Returns all tracks in the queue.
  List<Track> get tracks => List.unmodifiable(_tracks);

  /// Returns the currently playing track, or null if queue is empty.
  Track? get currentTrack =>
      _currentIndex >= 0 && _currentIndex < _tracks.length
          ? _tracks[_currentIndex]
          : null;

  /// Returns the current position in the queue (0-indexed).
  int get currentIndex => _currentIndex;

  /// Returns the total number of tracks in the queue.
  int get length => _tracks.length;

  /// Returns true if there's a next track available.
  bool get hasNext => _currentIndex < _tracks.length - 1;

  /// Returns true if there's a previous track available.
  bool get hasPrevious => _currentIndex > 0;

  /// Returns the next track without changing the current position.
  Track? get nextTrack => hasNext ? _tracks[_currentIndex + 1] : null;

  /// Returns the previous track without changing the current position.
  Track? get previousTrack => hasPrevious ? _tracks[_currentIndex - 1] : null;

  /// Adds a track to the end of the queue.
  void add(Track track) {
    _tracks.add(track);
  }

  /// Adds multiple tracks to the end of the queue.
  void addAll(List<Track> tracks) {
    _tracks.addAll(tracks);
  }

  /// Clears the queue and resets the current index.
  void clear() {
    _tracks.clear();
    _currentIndex = 0;
  }

  /// Moves to the next track. Returns the next track or null if at the end.
  Track? next() {
    if (hasNext) {
      _currentIndex++;
      return currentTrack;
    }
    return null;
  }

  /// Moves to the previous track. Returns the previous track or null if at start.
  Track? previous() {
    if (hasPrevious) {
      _currentIndex--;
      return currentTrack;
    }
    return null;
  }

  /// Jumps to a specific track index.
  Track? jumpTo(int index) {
    if (index >= 0 && index < _tracks.length) {
      _currentIndex = index;
      return currentTrack;
    }
    return null;
  }

  /// Removes a track at the specified index.
  void removeAt(int index) {
    if (index >= 0 && index < _tracks.length) {
      _tracks.removeAt(index);
      // Adjust current index if necessary
      if (_currentIndex >= _tracks.length) {
        _currentIndex = (_tracks.length - 1).clamp(0, _tracks.length - 1);
      }
    }
  }

  /// Replaces the entire queue with new tracks, optionally starting at a track.
  void replace(List<Track> newTracks, {int startIndex = 0}) {
    _tracks.clear();
    _tracks.addAll(newTracks);
    _currentIndex = startIndex.clamp(0, (_tracks.length - 1).clamp(0, 0));
  }
}
