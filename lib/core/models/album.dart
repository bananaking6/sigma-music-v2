import 'package:sigma_music/core/models/artist.dart';
import 'package:sigma_music/core/models/track.dart';

/// Represents a music album.
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl,
    this.releaseDate,
    this.tracks = const [],
    this.providerId,
  });

  final String id;
  final String title;
  final Artist artist;
  final String? coverUrl;
  final DateTime? releaseDate;
  final List<Track> tracks;
  final String? providerId;

  Album copyWith({
    String? id,
    String? title,
    Artist? artist,
    String? coverUrl,
    DateTime? releaseDate,
    List<Track>? tracks,
    String? providerId,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverUrl: coverUrl ?? this.coverUrl,
      releaseDate: releaseDate ?? this.releaseDate,
      tracks: tracks ?? this.tracks,
      providerId: providerId ?? this.providerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Album(id: $id, title: $title)';
}
