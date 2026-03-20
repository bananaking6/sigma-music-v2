import 'album.dart';
import 'artist.dart';

/// Represents a single music track.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.durationMs,
    required this.artist,
    required this.album,
    this.trackNumber,
    this.discNumber,
    this.audioQuality,
    this.coverUrl,
    this.isrc,
    this.providerId,
  });

  final String id;
  final String title;

  /// Duration in milliseconds.
  final int durationMs;
  final Artist artist;
  final Album album;
  final int? trackNumber;
  final int? discNumber;
  final AudioQuality? audioQuality;
  final String? coverUrl;

  /// International Standard Recording Code.
  final String? isrc;

  /// The provider that this track came from (e.g. "tidal", "local").
  final String? providerId;

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({
    String? id,
    String? title,
    int? durationMs,
    Artist? artist,
    Album? album,
    int? trackNumber,
    int? discNumber,
    AudioQuality? audioQuality,
    String? coverUrl,
    String? isrc,
    String? providerId,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      durationMs: durationMs ?? this.durationMs,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      audioQuality: audioQuality ?? this.audioQuality,
      coverUrl: coverUrl ?? this.coverUrl,
      isrc: isrc ?? this.isrc,
      providerId: providerId ?? this.providerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Track(id: $id, title: $title)';
}

/// Describes the quality tier of an audio stream.
enum AudioQuality {
  low,
  high,
  lossless,
  hiResLossless;

  /// Returns the TIDAL API quality string for this quality tier.
  String get tidalValue => switch (this) {
        AudioQuality.low => 'LOW',
        AudioQuality.high => 'HIGH',
        AudioQuality.lossless => 'LOSSLESS',
        AudioQuality.hiResLossless => 'HI_RES_LOSSLESS',
      };

  static AudioQuality fromTidalValue(String value) => switch (value) {
        'LOW' => AudioQuality.low,
        'HIGH' => AudioQuality.high,
        'LOSSLESS' => AudioQuality.lossless,
        'HI_RES_LOSSLESS' => AudioQuality.hiResLossless,
        _ => AudioQuality.lossless,
      };
}
