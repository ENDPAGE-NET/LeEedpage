import 'dart:async';
import 'dart:html' as html;

import 'location_service.dart';

Future<LocationResult?> getBrowserLocation() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 12),
      maximumAge: Duration.zero,
    );

    final latitude = position.coords?.latitude?.toDouble();
    final longitude = position.coords?.longitude?.toDouble();
    if (latitude == null || longitude == null) {
      throw LocationServiceError('浏览器返回了空的定位结果');
    }

    return LocationResult(
      latitude: latitude,
      longitude: longitude,
      accuracy: position.coords?.accuracy?.toDouble(),
      provider: 'Browser Geolocation',
    );
  } catch (error) {
    throw LocationServiceError(error.toString());
  }
}
