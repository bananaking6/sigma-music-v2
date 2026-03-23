import 'dart:convert';

/// Discovers and selects the healthiest available API endpoint.
///
/// The discovery service at [_discoveryUrl] returns a JSON payload with
/// `api` and `streaming` arrays.  [TidalEndpointResolver] fetches that list,
/// sorts by version (highest first), and caches the result so the API client
/// can rotate through healthy endpoints automatically.
///
/// Example discovery response:
/// ```json
/// {
///   "lastUpdated": "2026-03-15T00:00:00Z",
///   "api": [
///     { "url": "https://triton.squid.wtf", "version": "2.6" },
///     { "url": "https://api.monochrome.tf", "version": "2.5" }
///   ],
///   "streaming": [
///     { "url": "https://triton.squid.wtf", "version": "2.6" }
///   ]
/// }
/// ```
class TidalEndpointResolver {
  TidalEndpointResolver({
    this.discoveryUrl =
        'https://tidal-uptime.jiffy-puffs-1j.workers.dev/',
    this.defaultMetadataUrl = 'https://api.monochrome.tf',
    required this.httpGet,
  });

  final String discoveryUrl;
  final String defaultMetadataUrl;

  /// Injectable HTTP GET function; signature: `(url) async => responseBody`.
  /// Inject a real `dio.get` or `http.get` implementation.
  final Future<String> Function(String url) httpGet;

  List<_EndpointEntry> _metadataEndpoints = [];
  List<_EndpointEntry> _streamingEndpoints = [];
  int _metadataIndex = 0;
  int _streamingIndex = 0;
  DateTime? _lastFetched;

  static const _cacheDuration = Duration(minutes: 30);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the currently preferred metadata base URL.
  ///
  /// Falls back to [defaultMetadataUrl] if discovery has not been run yet.
  String get metadataBaseUrl {
    if (_metadataEndpoints.isEmpty) return defaultMetadataUrl;
    return _metadataEndpoints[_metadataIndex].url;
  }

  /// Returns the currently preferred streaming base URL.
  String get streamingBaseUrl {
    if (_streamingEndpoints.isEmpty) return defaultMetadataUrl;
    return _streamingEndpoints[_streamingIndex].url;
  }

  /// Fetches the endpoint list and populates the internal ranked lists.
  ///
  /// Safe to call multiple times; re-fetches only when the cache is stale.
  Future<void> refresh({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastFetched != null &&
        now.difference(_lastFetched!) < _cacheDuration) {
      return;
    }

    try {
      final body = await httpGet(discoveryUrl);
      final json = jsonDecode(body) as Map<String, dynamic>;

      _metadataEndpoints = _parseEndpoints(json['api']);
      _streamingEndpoints = _parseEndpoints(json['streaming']);
      _metadataIndex = 0;
      _streamingIndex = 0;
      _lastFetched = now;
    } catch (_) {
      // Silently fall back to defaults; the API client will use
      // [defaultMetadataUrl] and can call [rotateMetadata] on failure.
    }
  }

  /// Rotates to the next metadata endpoint after a failure.
  ///
  /// Returns `true` if there are more endpoints to try.
  bool rotateMetadata() {
    if (_metadataEndpoints.isEmpty) return false;
    _metadataIndex = (_metadataIndex + 1) % _metadataEndpoints.length;
    return _metadataIndex != 0;
  }

  /// Rotates to the next streaming endpoint after a failure.
  ///
  /// Returns `true` if there are more endpoints to try.
  bool rotateStreaming() {
    if (_streamingEndpoints.isEmpty) return false;
    _streamingIndex = (_streamingIndex + 1) % _streamingEndpoints.length;
    return _streamingIndex != 0;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<_EndpointEntry> _parseEndpoints(dynamic raw) {
    if (raw is! List) return [];
    final entries = raw
        .whereType<Map<String, dynamic>>()
        .map(_EndpointEntry.fromJson)
        .toList()
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return entries;
  }
}

class _EndpointEntry {
  const _EndpointEntry({required this.url, required this.version});

  factory _EndpointEntry.fromJson(Map<String, dynamic> json) {
    return _EndpointEntry(
      url: (json['url'] as String).trimRight().replaceAll(RegExp(r'/$'), ''),
      version: json['version'] as String? ?? '0.0',
    );
  }

  final String url;
  final String version;

  /// Parses the semantic-version string into a comparable double.
  double get versionNumber {
    final parts = version.split('.');
    if (parts.isEmpty) return 0.0;
    final major = double.tryParse(parts[0]) ?? 0.0;
    final minor =
        parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.0) / 10.0 : 0.0;
    return major + minor;
  }
}
