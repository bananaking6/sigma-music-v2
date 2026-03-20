import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/models/track.dart';
import 'playback_queue.dart';

/// Audio handler for audio_service integration.
/// 
/// This service provides Android system media controls and manages
/// the media session for the music player.
class SigmaAudioHandler extends BaseAudioHandler {
  SigmaAudioHandler({
    required AudioPlayer audioPlayer,
    required PlaybackQueue queue,
  })  : _audioPlayer = audioPlayer,
        _queue = queue;

  final AudioPlayer _audioPlayer;
  final PlaybackQueue _queue;

  Future<void> initialize() async {
    // Listen to audio player state changes and update playback state
    _audioPlayer.playerStateStream.listen((state) {
      _updatePlaybackState();
    });

    _audioPlayer.positionStream.listen((_) {
      _updatePlaybackState();
    });

    _updateQueue();
  }

  /// Updates the media session queue based on the playback queue.
  void _updateQueue() {
    mediaItem.add(_trackToMediaItem(_queue.currentTrack));
    
    queue.add(
      List<MediaItem>.from(
        _queue.tracks.map(_trackToMediaItem),
      ),
    );
    
    queueIndex.add(_queue.currentIndex);
  }

  /// Converts a Track to a MediaItem for display in Android's media controls.
  MediaItem _trackToMediaItem(Track? track) {
    if (track == null) {
      return MediaItem(
        id: '',
        title: 'No track',
        artist: '',
      );
    }

    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist.name,
      album: track.album.title,
      artworkUrl: track.coverUrl,
      duration: Duration(milliseconds: track.durationMs),
    );
  }

  /// Updates the current playback state based on with audio player state.
  void _updatePlaybackState() {
    final playerState = _audioPlayer.playerState;
    final position = _audioPlayer.position;
    final duration = _audioPlayer.duration ?? Duration.zero;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playerState.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        playing: playerState.playing,
        position: position,
        updatePosition: position,
        bufferedPosition: position,
        speed: _audioPlayer.speed,
        processingState: _mapProcessingState(playerState.processingState),
      ),
    );
  }

  /// Maps just_audio ProcessingState to audio_service ProcessingState.
  static ProcessingState _mapProcessingState(
    ProcessingState audioProcessingState,
  ) {
    switch (audioProcessingState) {
      case ProcessingState.idle:
        return ProcessingState.idle;
      case ProcessingState.loading:
        return ProcessingState.loading;
      case ProcessingState.buffering:
        return ProcessingState.buffering;
      case ProcessingState.ready:
        return ProcessingState.ready;
      case ProcessingState.completed:
        return ProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _audioPlayer.play();

  @override
  Future<void> pause() => _audioPlayer.pause();

  @override
  Future<void> stop() => _audioPlayer.stop();

  @override
  Future<void> skipToNext() async {
    final nextTrack = _queue.next();
    if (nextTrack != null) {
      mediaItem.add(_trackToMediaItem(nextTrack));
      queueIndex.add(_queue.currentIndex);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final previousTrack = _queue.previous();
    if (previousTrack != null) {
      mediaItem.add(_trackToMediaItem(previousTrack));
      queueIndex.add(_queue.currentIndex);
    }
  }

  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  @override
  Future<void> skipToQueueItem(int index) async {
    final track = _queue.jumpTo(index);
    if (track != null) {
      mediaItem.add(_trackToMediaItem(track));
      queueIndex.add(_queue.currentIndex);
    }
  }
}
