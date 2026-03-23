/// Represents a music artist.
class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.pictureUrl,
    this.popularity,
    this.providerId,
  });

  final String id;
  final String name;
  final String? pictureUrl;
  final int? popularity;
  final String? providerId;

  Artist copyWith({
    String? id,
    String? name,
    String? pictureUrl,
    int? popularity,
    String? providerId,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      pictureUrl: pictureUrl ?? this.pictureUrl,
      popularity: popularity ?? this.popularity,
      providerId: providerId ?? this.providerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Artist && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Artist(id: $id, name: $name)';
}
