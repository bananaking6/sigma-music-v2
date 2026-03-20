import 'track.dart';

/// Represents a user-created or provider-generated playlist.
class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.coverUrl,
    this.tracks = const [],
    this.providerId,
  });

  final String id;
  final String title;
  final String? description;
  final String? coverUrl;
  final List<Track> tracks;
  final String? providerId;

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    String? coverUrl,
    List<Track>? tracks,
    String? providerId,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      tracks: tracks ?? this.tracks,
      providerId: providerId ?? this.providerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Playlist && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, title: $title)';
}
