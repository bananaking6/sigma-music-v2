/// The capabilities that a [MusicProviderPlugin] may advertise.
///
/// The registry and unified repository use these to route requests to the
/// right provider (e.g. lyrics fallback across all lyrics-capable providers).
enum ProviderCapability {
  /// Provider can search tracks, albums, and artists.
  search,

  /// Provider can return streaming URLs / manifests.
  streaming,

  /// Provider can return lyrics for tracks.
  lyrics,

  /// Provider can return recommendations for a track.
  recommendations,

  /// Provider can list and retrieve playlists.
  playlists,

  /// Provider supports downloading tracks for offline playback.
  downloads,

  /// Provider reads local audio files from the device.
  localFiles,

  /// Provider guarantees gapless-ready stream delivery.
  gaplessReady,
}
