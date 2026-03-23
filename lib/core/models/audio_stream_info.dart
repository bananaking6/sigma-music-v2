import 'package:sigma_music/core/models/track.dart';

/// Contains everything needed to start streaming or playing a track.
class AudioStreamInfo {
  const AudioStreamInfo({
    required this.trackId,
    required this.audioQuality,
    required this.mimeType,
    this.streamUrl,
    this.manifestBase64,
    this.bitDepth,
    this.sampleRate,
    this.codec,
  });

  final String trackId;
  final AudioQuality audioQuality;

  /// e.g. "audio/flac", "audio/mp4", "application/dash+xml"
  final String mimeType;

  /// Direct playback URL when available (non-manifest streams).
  final String? streamUrl;

  /// Base64-encoded manifest (DASH MPD or BTS JSON).
  final String? manifestBase64;

  final int? bitDepth;
  final int? sampleRate;

  /// e.g. "flac", "aac", "mqa"
  final String? codec;

  bool get isManifestBased => manifestBase64 != null;

  @override
  String toString() =>
      'AudioStreamInfo(trackId: $trackId, quality: $audioQuality, mime: $mimeType)';
}
