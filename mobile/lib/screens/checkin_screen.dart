import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/location_map_card.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  bool _loading = false;
  bool _statusLoading = true;
  bool _locationLoading = false;

  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();

  Timer? _clockTimer;
  String _currentTime = '';
  String _currentDate = '';

  bool _checkinDone = false;
  bool _checkoutDone = false;
  String? _checkinTime;
  String? _checkoutTime;
  bool? _isLate;
  bool? _isEarlyLeave;
  bool _isWorkDay = true;

  Map<String, dynamic>? _ruleInfo;
  LocationResult? _currentLocation;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    unawaited(_refreshAll());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await _loadTodayStatus();
    await _refreshLocation();
  }

  void _updateClock() {
    final now = DateTime.now();
    if (!mounted) {
      return;
    }

    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _currentDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} 星期${weekdays[now.weekday - 1]}';
    });
  }

  Future<void> _loadTodayStatus() async {
    setState(() => _statusLoading = true);
    try {
      final status = await ApiService().getTodayStatus();
      if (!mounted) {
        return;
      }

      setState(() {
        _checkinDone = status['checkin']['done'] == true;
        _checkoutDone = status['checkout']['done'] == true;
        _checkinTime = status['checkin']['time']?.toString();
        _checkoutTime = status['checkout']['time']?.toString();
        _isLate = status['checkin']['is_late'] == true;
        _isEarlyLeave = status['checkout']['is_early_leave'] == true;
        _isWorkDay = status['is_work_day'] != false;
        _ruleInfo = (status['rule'] as Map?)?.cast<String, dynamic>();
      });
    } catch (_) {
      // Keep the home screen resilient; the user can pull to refresh.
    } finally {
      if (mounted) {
        setState(() => _statusLoading = false);
      }
    }
  }

  Future<void> _refreshLocation({bool showError = false}) async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });

    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = location;
        _locationError = null;
      });
    } catch (error) {
      final message = _extractError(error);
      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = null;
        _locationError = message;
      });

      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _locationLoading = false);
      }
    }
  }

  String _extractError(Object error) {
    if (error is DioException && error.response?.data is Map) {
      final detail = error.response?.data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }

    if (error is LocationServiceError) {
      return error.message;
    }

    final message = error.toString().toLowerCase();
    if (message.contains('connection')) {
      return '网络连接失败';
    }
    if (message.contains('timeout')) {
      return '请求超时，请稍后重试';
    }
    return '操作失败，请稍后重试';
  }

  String _buildDeviceInfo() {
    if (kIsWeb) {
      return 'Web/Test Upload';
    }
    return '${defaultTargetPlatform.name}/SystemMap';
  }

  Future<XFile?> _pickFaceImage() {
    return _picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
      maxWidth: 1024,
    );
  }

  Future<void> _doAttendance(String type) async {
    final xFile = await _pickFaceImage();
    if (xFile == null) {
      return;
    }

    setState(() => _loading = true);
    try {
      final locationRequired = _ruleInfo?['location_required'] == true;
      var location = _currentLocation;

      if (locationRequired && location == null) {
        await _refreshLocation(showError: true);
        location = _currentLocation;
      }

      if (locationRequired && location == null) {
        throw LocationServiceError('当前位置获取失败，请确认定位权限和浏览器/系统定位开关后重试');
      }

      final api = ApiService();
      if (type == 'checkin') {
        await api.checkin(
          faceImage: xFile,
          latitude: location?.latitude,
          longitude: location?.longitude,
          deviceInfo: _buildDeviceInfo(),
        );
      } else {
        await api.checkout(
          faceImage: xFile,
          latitude: location?.latitude,
          longitude: location?.longitude,
          deviceInfo: _buildDeviceInfo(),
        );
      }

      await _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'checkin' ? '签到成功' : '签退成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_extractError(error)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null) {
      return '未打卡';
    }

    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  Widget _buildUserAvatar(String name, String? avatarUrl) {
    final resolvedUrl = AppConfig.resolveMediaUrl(avatarUrl);
    if (resolvedUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(resolvedUrl),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildActionArea(ThemeData theme) {
    if (_loading) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _checkinDone ? null : () => _doAttendance('checkin'),
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _checkinDone
                  ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                    ),
              boxShadow: _checkinDone
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_checkinDone ? Icons.check : Icons.fingerprint, size: 44, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  _checkinDone ? '已签到' : (kIsWeb ? '上传签到图' : '签到'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: (!_checkinDone || _checkoutDone) ? null : () => _doAttendance('checkout'),
          icon: Icon(_checkoutDone ? Icons.check_circle : Icons.logout, size: 18),
          label: Text(_checkoutDone ? '已签退' : (kIsWeb ? '上传签退图' : '申请签退')),
          style: TextButton.styleFrom(
            foregroundColor: _checkoutDone ? Colors.grey : theme.colorScheme.primary,
          ),
        ),
        if (_checkinDone && _checkoutDone)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text('今日打卡已完成', style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final displayName = user?.fullName ?? '';
    final avatarUrl = user?.avatarUrl ?? user?.faceImageUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('打卡'),
        centerTitle: true,
        actions: [
          if (!_isWorkDay)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '休息日',
                style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildUserAvatar(displayName, avatarUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  user?.username ?? '',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '工号 ${user?.username ?? ''}',
                              style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _statusLoading
                          ? const SizedBox(
                              height: 60,
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildStatusCol(
                                    icon: Icons.login,
                                    label: '签到',
                                    done: _checkinDone,
                                    time: _fmtTime(_checkinTime),
                                    tag: _isLate == true ? '迟到' : null,
                                    tagColor: Colors.orange,
                                  ),
                                ),
                                Container(width: 1, height: 50, color: Colors.grey.shade200),
                                Expanded(
                                  child: _buildStatusCol(
                                    icon: Icons.logout,
                                    label: '签退',
                                    done: _checkoutDone,
                                    time: _fmtTime(_checkoutTime),
                                    tag: _isEarlyLeave == true ? '早退' : null,
                                    tagColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _currentTime,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(_currentDate, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    '当前为 Web 测试模式，可上传图片模拟人脸采集；位置通过浏览器原生定位获取，小地图用于测试当前点与规则点关系。',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              _buildActionArea(theme),
              const SizedBox(height: 20),
              LocationMapCard(
                currentLocation: _currentLocation,
                loading: _locationLoading,
                error: _locationError,
                ruleInfo: _ruleInfo,
                onRefresh: () => unawaited(_refreshLocation(showError: true)),
              ),
              if (_ruleInfo != null && _ruleInfo!['has_rule'] == true) ...[
                const SizedBox(height: 24),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(
                              '今日考勤规则',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_ruleInfo!['time_required'] == true) ...[
                          _buildRuleRow(
                            Icons.access_time,
                            '标准工时',
                            '${_ruleInfo!['checkin_start'] ?? '-'} - ${_ruleInfo!['checkout_start'] ?? '-'}',
                          ),
                          if (_ruleInfo!['checkin_end'] != null)
                            _buildRuleRow(Icons.timer_off, '最晚签到', _ruleInfo!['checkin_end'].toString()),
                        ],
                        if (_ruleInfo!['location_required'] == true) ...[
                          _buildRuleRow(
                            Icons.location_on,
                            '打卡地点',
                            _ruleInfo!['location_name']?.toString() ?? '需在指定范围内',
                          ),
                          if ((_ruleInfo!['location_address']?.toString() ?? '').isNotEmpty)
                            _buildRuleRow(Icons.place, '地点说明', _ruleInfo!['location_address'].toString()),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCol({
    required IconData icon,
    required String label,
    required bool done,
    required String time,
    String? tag,
    Color? tagColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: done ? Colors.green : Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: done ? Colors.black87 : Colors.grey.shade400,
          ),
        ),
        if (tag != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor?.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tag,
              style: TextStyle(fontSize: 10, color: tagColor, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildRuleRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade300),
          const SizedBox(width: 6),
          Text('$label  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
