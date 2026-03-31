class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static String resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) {
      return '';
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final apiRoot = apiBaseUrl.endsWith('/api/v1')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - '/api/v1'.length)
        : apiBaseUrl;
    if (path.startsWith('/')) {
      return '$apiRoot$path';
    }
    return '$apiRoot/$path';
  }

  static String buildStaticMapUrl({
    required double centerLatitude,
    required double centerLongitude,
    required double currentLatitude,
    required double currentLongitude,
    double? targetLatitude,
    double? targetLongitude,
  }) {
    final markers = <String>[
      '$currentLatitude,$currentLongitude,lightblue1',
      if (targetLatitude != null && targetLongitude != null) '$targetLatitude,$targetLongitude,orange1',
    ].join('|');

    return Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
      'center': '$centerLatitude,$centerLongitude',
      'zoom': '15',
      'size': '750x360',
      'markers': markers,
    }).toString();
  }
}
