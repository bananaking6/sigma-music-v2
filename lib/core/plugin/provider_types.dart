/// Broad category of a [MusicProviderPlugin].
enum ProviderType {
  /// Streams audio from a remote cloud service (e.g. TIDAL).
  cloud,

  /// Reads audio files stored locally on the device.
  local,

  /// A mix of cloud metadata and local file management.
  hybrid,
}
