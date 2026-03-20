/// A single timed subtitle line used for synced lyrics display.
class LyricsLine {
  const LyricsLine({required this.start, required this.text});

  /// The position at which this line should be highlighted.
  final Duration start;
  final String text;

  @override
  String toString() => 'LyricsLine(start: $start, text: $text)';
}

/// Lyrics for a track, including optional synced (timed) lines.
class Lyrics {
  const Lyrics({
    required this.trackId,
    this.plainText,
    this.syncedLines = const [],
    this.provider,
  });

  final String trackId;

  /// Plain-text lyrics without timing info.
  final String? plainText;

  /// Timed subtitle lines sorted by [LyricsLine.start].
  final List<LyricsLine> syncedLines;

  /// E.g. "MUSIXMATCH", "provider-local"
  final String? provider;

  bool get hasSyncedLyrics => syncedLines.isNotEmpty;

  @override
  String toString() =>
      'Lyrics(trackId: $trackId, synced: $hasSyncedLyrics, provider: $provider)';
}
