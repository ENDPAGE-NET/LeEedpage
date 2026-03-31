import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import 'location_browser_stub.dart' if (dart.library.html) 'location_browser_web.dart' as browser_location;

class LocationServiceError implements Exception {
  final String message;

  LocationServiceError(this.message);

  @override
  String toString() => message;
}

class LocationResult {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String provider;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.provider,
  });
}

class LocationService {
  Future<LocationResult?> _getNativeLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceError('系统定位服务未开启，请先打开定位开关');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw LocationServiceError('定位权限未授权，请允许应用访问位置信息');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 12),
      ),
    );

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      provider: 'System Location',
    );
  }

  Future<LocationResult?> _getWebLocation() async {
    try {
      return await browser_location.getBrowserLocation();
    } on TimeoutException {
      throw LocationServiceError('浏览器定位超时，请确认系统定位已开启，并在地址栏允许此站点访问位置');
    } catch (error) {
      if (error is LocationServiceError) {
        final message = error.message;
        if (message.contains('Only secure origins are allowed') || message.contains('secure context')) {
          throw LocationServiceError('浏览器定位只支持 localhost 或 https 地址');
        }
        if (message.contains('User denied Geolocation') || message.contains('permission denied')) {
          throw LocationServiceError('浏览器定位权限未授权，请点击地址栏位置权限并选择“允许”');
        }
        if (message.contains('POSITION_UNAVAILABLE') || message.contains('unavailable')) {
          throw LocationServiceError('当前位置暂时不可用，请检查系统定位服务和网络后重试');
        }
        throw error;
      }
      throw LocationServiceError('浏览器定位失败: $error');
    }
  }

  Future<LocationResult?> getCurrentLocation() async {
    try {
      if (kIsWeb) {
        return await _getWebLocation();
      }
      return await _getNativeLocation();
    } on TimeoutException {
      throw LocationServiceError('定位超时，请检查网络、GPS 和系统定位权限');
    } catch (error) {
      if (error is LocationServiceError) {
        rethrow;
      }

      final message = error.toString();
      if (message.contains('MissingPluginException')) {
        throw LocationServiceError('定位插件未正常加载，请完整重启应用后重试');
      }
      throw LocationServiceError('定位失败: $message');
    }
  }
}
