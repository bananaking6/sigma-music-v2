import 'package:just_audio/just_audio.dart';

import 'package:sigma_music/core/models/track.dart';
import 'package:sigma_music/features/playback/playback_queue.dart';

/// Audio handler for playback queue management.
/// 
/// This class manages the playback queue and integrates with just_audio
/// for media playback control.
class SigmaAudioHandler {
  SigmaAudioHandler({
    required AudioPlayer audioPlayer,
    required PlaybackQueue queue,
  })  : _audioPlayer = audioPlayer,
        _queue = queue;

  final AudioPlayer _audioPlayer;
  final PlaybackQueue _queue;

  Future<void> initialize() async {
    // Listen to audio player state changes
    _audioPlayer.playerStateStream.listen((state) {
      // Handle state changes here
    });

    _audioPlayer.positionStream.listen((_) {
      // Handle position changes here
    });
  }

  /// Returns the current track in the queue.
  Track? get currentTrack => _queue.currentTrack;

  /// Returns all tracks in the queue.
  List<Track> get queueTracks => _queue.tracks;

  /// Returns current position in queue.
  int get currentQueueIndex => _queue.currentIndex;

  /// Synchronizes the queue with new tracks.
  void updateQueue(List<Track> tracks, int currentIndex) {
    _queue.replace(tracks, startIndex: currentIndex);
  }

  /// Converts a Track to a display name.
  String trackDisplayName(Track track) => '${track.title} • ${track.artist.name}';

  /// Play/pause control.
  Future<void> playPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  /// Skip to next track.
  Future<void> skipToNext() async {
    final nextTrack = _queue.next();
    if (nextTrack != null) {
      // Caller should handle playback of next track
    }
  }

  /// Skip to previous track.
  Future<void> skipToPrevious() async {
    final previousTrack = _queue.previous();
    if (previousTrack != null) {
      // Caller should handle playback of previous track
    }
  }

  /// Seek to position.
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  /// Jump to specific queue item.
  Future<void> jumpToQueueItem(int index) async {
    final track = _queue.jumpTo(index);
    if (track != null) {
      // Caller should handle playback of track at index
    }
  }
}
