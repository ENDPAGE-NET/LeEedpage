class AttendanceRecord {
  final String id;
  final String userId;
  final String? userName;
  final String recordDate;
  final String recordType;
  final bool faceVerified;
  final double? faceScore;
  final bool? locationVerified;
  final double? latitude;
  final double? longitude;
  final double? distanceM;
  final bool isLate;
  final bool isEarlyLeave;
  final String? deviceInfo;
  final String recordedAt;

  AttendanceRecord({
    required this.id,
    required this.userId,
    this.userName,
    required this.recordDate,
    required this.recordType,
    required this.faceVerified,
    this.faceScore,
    this.locationVerified,
    this.latitude,
    this.longitude,
    this.distanceM,
    required this.isLate,
    required this.isEarlyLeave,
    this.deviceInfo,
    required this.recordedAt,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      recordDate: json['record_date'],
      recordType: json['record_type'],
      faceVerified: json['face_verified'] ?? false,
      faceScore: json['face_score']?.toDouble(),
      locationVerified: json['location_verified'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      distanceM: json['distance_m']?.toDouble(),
      isLate: json['is_late'] ?? false,
      isEarlyLeave: json['is_early_leave'] ?? false,
      deviceInfo: json['device_info'],
      recordedAt: json['recorded_at'],
    );
  }

  String get typeLabel => recordType == 'checkin' ? '签到' : '签退';

  String get statusLabel {
    if (isLate) return '迟到';
    if (isEarlyLeave) return '早退';
    return '正常';
  }
}
