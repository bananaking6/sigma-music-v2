import 'package:sigma_music/core/models/album.dart';
import 'package:sigma_music/core/models/artist.dart';
import 'package:sigma_music/core/models/track.dart';

/// Discriminated union representing one item in a search result list.
sealed class SearchResultItem {
  const SearchResultItem();
}

class TrackResult extends SearchResultItem {
  const TrackResult(this.track);
  final Track track;
}

class AlbumResult extends SearchResultItem {
  const AlbumResult(this.album);
  final Album album;
}

class ArtistResult extends SearchResultItem {
  const ArtistResult(this.artist);
  final Artist artist;
}
