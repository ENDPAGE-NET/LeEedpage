import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.deleteAll();
        }
        return handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    final data = res.data;
    await _storage.write(key: 'access_token', value: data['access_token']);
    await _storage.write(key: 'refresh_token', value: data['refresh_token']);
    return data;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final res = await _dio.get('/users/me');
    return res.data;
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _dio.post('/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  // 使用 XFile（兼容 Web 和原生平台）
  Future<void> registerFace(List<XFile> images, {String? deviceInfo}) async {
    final formData = FormData();
    for (final img in images) {
      final bytes = await img.readAsBytes();
      formData.files.add(MapEntry(
        'images',
        MultipartFile.fromBytes(bytes, filename: img.name.isNotEmpty ? img.name : 'face.jpg'),
      ));
    }
    if (deviceInfo != null && deviceInfo.isNotEmpty) {
      formData.fields.add(MapEntry('device_info', deviceInfo));
    }
    await _dio.post('/face/register', data: formData);
  }

  Future<void> completeActivation() async {
    await _dio.post('/activation/complete');
  }

  Future<Map<String, dynamic>?> getMyRule() async {
    final res = await _dio.get('/rules/me');
    return res.data;
  }

  Future<Map<String, dynamic>> checkin({
    required XFile faceImage,
    double? latitude,
    double? longitude,
    String? deviceInfo,
  }) async {
    final bytes = await faceImage.readAsBytes();
    final formData = FormData.fromMap({
      'face_image': MultipartFile.fromBytes(bytes, filename: 'checkin.jpg'),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (deviceInfo != null) 'device_info': deviceInfo,
    });
    final res = await _dio.post('/attendance/checkin', data: formData);
    return res.data;
  }

  Future<Map<String, dynamic>> checkout({
    required XFile faceImage,
    double? latitude,
    double? longitude,
    String? deviceInfo,
  }) async {
    final bytes = await faceImage.readAsBytes();
    final formData = FormData.fromMap({
      'face_image': MultipartFile.fromBytes(bytes, filename: 'checkout.jpg'),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (deviceInfo != null) 'device_info': deviceInfo,
    });
    final res = await _dio.post('/attendance/checkout', data: formData);
    return res.data;
  }

  /// 获取今日打卡状态
  Future<Map<String, dynamic>> getTodayStatus() async {
    final res = await _dio.get('/attendance/today');
    return res.data;
  }

  // ===== 请假 =====
  Future<Map<String, dynamic>> createLeaveRequest({
    required String leaveType,
    required String startDate,
    required String endDate,
    required double days,
    required String reason,
  }) async {
    final res = await _dio.post('/leave/request', data: {
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'days': days,
      'reason': reason,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getMyLeaveRequests({int page = 1, String status = ''}) async {
    final res = await _dio.get('/leave/my', queryParameters: {
      'page': page,
      'page_size': 20,
      if (status.isNotEmpty) 'status': status,
    });
    return res.data;
  }

  Future<void> cancelLeaveRequest(String id) async {
    await _dio.post('/leave/$id/cancel');
  }

  Future<List<dynamic>> getMyLeaveBalance({int year = 0}) async {
    final res = await _dio.get('/leave/balance', queryParameters: {
      if (year > 0) 'year': year,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> getMyAttendance({
    int page = 1,
    int pageSize = 20,
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _dio.get('/attendance/me', queryParameters: {
      'page': page,
      'page_size': pageSize,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    });
    return res.data;
  }
}
