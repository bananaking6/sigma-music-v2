import '../../core/models/album.dart';
import '../../core/models/artist.dart';
import '../../core/models/audio_stream_info.dart';
import '../../core/models/lyrics.dart';
import '../../core/models/track.dart';

/// Maps raw JSON maps from the TIDAL API into domain model objects.
///
/// All methods are pure functions (no network I/O) and throw [FormatException]
/// when required fields are missing.
class TidalMapper {
  const TidalMapper();

  // ---------------------------------------------------------------------------
  // Track
  // ---------------------------------------------------------------------------

  Track trackFromJson(Map<String, dynamic> json) {
    final artistJson =
        json['artist'] as Map<String, dynamic>? ?? {'id': '0', 'name': ''};
    final albumJson =
        json['album'] as Map<String, dynamic>? ?? {'id': '0', 'title': ''};

    final artist = Artist(
      id: _str(artistJson['id']),
      name: _str(artistJson['name']),
      pictureUrl: artistJson['picture'] as String?,
      providerId: 'tidal',
    );

    final album = Album(
      id: _str(albumJson['id']),
      title: _str(albumJson['title']),
      artist: artist,
      coverUrl: albumJson['cover'] as String? ??
          _tidalCoverUrl(albumJson['id']?.toString()),
      providerId: 'tidal',
    );

    return Track(
      id: _str(json['id']),
      title: _str(json['title']),
      durationMs: ((json['duration'] as num? ?? 0) * 1000).round(),
      artist: artist,
      album: album,
      trackNumber: json['trackNumber'] as int?,
      discNumber: json['volumeNumber'] as int?,
      audioQuality: json['audioQuality'] != null
          ? AudioQuality.fromTidalValue(json['audioQuality'] as String)
          : null,
      coverUrl: json['cover'] as String? ??
          _tidalCoverUrl(albumJson['id']?.toString()),
      isrc: json['isrc'] as String?,
      providerId: 'tidal',
    );
  }

  // ---------------------------------------------------------------------------
  // Album
  // ---------------------------------------------------------------------------

  Album albumFromJson(Map<String, dynamic> json) {
    final artistJson =
        json['artist'] as Map<String, dynamic>? ?? {'id': '0', 'name': ''};

    final artist = Artist(
      id: _str(artistJson['id']),
      name: _str(artistJson['name']),
      pictureUrl: artistJson['picture'] as String?,
      providerId: 'tidal',
    );

    final rawTracks = json['tracks'] as List<dynamic>? ?? [];
    final tracks = rawTracks
        .whereType<Map<String, dynamic>>()
        .map(trackFromJson)
        .toList();

    return Album(
      id: _str(json['id']),
      title: _str(json['title']),
      artist: artist,
      coverUrl: json['cover'] as String? ??
          _tidalCoverUrl(json['id']?.toString()),
      releaseDate: json['releaseDate'] != null
          ? DateTime.tryParse(json['releaseDate'] as String)
          : null,
      tracks: tracks,
      providerId: 'tidal',
    );
  }

  // ---------------------------------------------------------------------------
  // Artist
  // ---------------------------------------------------------------------------

  Artist artistFromJson(Map<String, dynamic> json) {
    return Artist(
      id: _str(json['id']),
      name: _str(json['name']),
      pictureUrl: json['picture'] as String?,
      popularity: json['popularity'] as int?,
      providerId: 'tidal',
    );
  }

  // ---------------------------------------------------------------------------
  // Stream info
  // ---------------------------------------------------------------------------

  AudioStreamInfo streamInfoFromJson(Map<String, dynamic> json) {
    return AudioStreamInfo(
      trackId: _str(json['trackId']),
      audioQuality:
          AudioQuality.fromTidalValue(json['audioQuality'] as String? ?? ''),
      mimeType: json['mimeType'] as String? ?? 'audio/mp4',
      manifestBase64: json['manifest'] as String?,
      bitDepth: json['bitDepth'] as int?,
      sampleRate: json['sampleRate'] as int?,
    );
  }

  // ---------------------------------------------------------------------------
  // Lyrics
  // ---------------------------------------------------------------------------

  Lyrics lyricsFromJson(String trackId, Map<String, dynamic> json) {
    final rawSubtitles = json['subtitles'] as String?;
    final plainText = json['lyrics'] as String?;
    final provider = json['provider'] as String?;

    final syncedLines = rawSubtitles != null
        ? _parseLrc(rawSubtitles)
        : <LyricsLine>[];

    return Lyrics(
      trackId: trackId,
      plainText: plainText,
      syncedLines: syncedLines,
      provider: provider,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _str(dynamic value) => value?.toString() ?? '';

  String? _tidalCoverUrl(String? albumId) {
    if (albumId == null || albumId.isEmpty) return null;
    return 'https://resources.tidal.com/images/'
        '${albumId.replaceAll('-', '/')}/640x640.jpg';
  }

  /// Parses basic LRC-format timed lyrics into [LyricsLine] objects.
  ///
  /// Format: `[mm:ss.xx] lyric text`
  List<LyricsLine> _parseLrc(String lrc) {
    final lines = <LyricsLine>[];
    final pattern = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s*(.*)');

    for (final line in lrc.split('\n')) {
      final match = pattern.firstMatch(line.trim());
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final centiseconds = int.parse(match.group(3)!);
      final text = match.group(4) ?? '';

      lines.add(
        LyricsLine(
          start: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: centiseconds * 10,
          ),
          text: text,
        ),
      );
    }

    return lines;
  }
}
