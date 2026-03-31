import 'location_service.dart';

Future<LocationResult?> getBrowserLocation() async {
  throw LocationServiceError('当前环境不支持浏览器原生定位');
}
