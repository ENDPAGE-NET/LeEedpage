import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/location_service.dart';

class LocationMapCard extends StatelessWidget {
  final LocationResult? currentLocation;
  final bool loading;
  final String? error;
  final Map<String, dynamic>? ruleInfo;
  final VoidCallback onRefresh;

  const LocationMapCard({
    super.key,
    required this.currentLocation,
    required this.loading,
    required this.error,
    required this.ruleInfo,
    required this.onRefresh,
  });

  double? get _targetLatitude => (ruleInfo?['latitude'] as num?)?.toDouble();
  double? get _targetLongitude => (ruleInfo?['longitude'] as num?)?.toDouble();
  double? get _radiusMeters => (ruleInfo?['allowed_radius_m'] as num?)?.toDouble();

  double _degreesToRadians(double value) => value * math.pi / 180;

  double? _calculateDistanceMeters() {
    final current = currentLocation;
    if (current == null || _targetLatitude == null || _targetLongitude == null) {
      return null;
    }

    const earthRadius = 6371000.0;
    final dLat = _degreesToRadians(_targetLatitude! - current.latitude);
    final dLon = _degreesToRadians(_targetLongitude! - current.longitude);
    final lat1 = _degreesToRadians(current.latitude);
    final lat2 = _degreesToRadians(_targetLatitude!);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  String _formatDistance(double? distance) {
    if (distance == null) {
      return '未设置规则地点';
    }
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(2)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  String _formatCoordinate(double value) => value.toStringAsFixed(6);

  Uri _buildMapUri({
    required double latitude,
    required double longitude,
    String? label,
  }) {
    if (kIsWeb) {
      return Uri.parse(
        'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=17/$latitude/$longitude',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Uri.parse(
        'https://maps.apple.com/?ll=$latitude,$longitude&q=${Uri.encodeComponent(label ?? '$latitude,$longitude')}',
      );
    }

    return Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude(${Uri.encodeComponent(label ?? '打卡点')})',
    );
  }

  Future<void> _openMap(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final uri = _buildMapUri(latitude: latitude, longitude: longitude, label: label);
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开系统地图，请检查设备地图能力')),
      );
    }
  }

  Widget _buildMapPreview({
    required double currentLatitude,
    required double currentLongitude,
  }) {
    if (kIsWeb) {
      return _WebMiniMap(
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        targetLatitude: _targetLatitude,
        targetLongitude: _targetLongitude,
        radiusMeters: _radiusMeters,
      );
    }

    final centerLatitude = _targetLatitude == null
        ? currentLatitude
        : (currentLatitude + _targetLatitude!) / 2;
    final centerLongitude = _targetLongitude == null
        ? currentLongitude
        : (currentLongitude + _targetLongitude!) / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        AppConfig.buildStaticMapUrl(
          centerLatitude: centerLatitude,
          centerLongitude: centerLongitude,
          currentLatitude: currentLatitude,
          currentLongitude: currentLongitude,
          targetLatitude: _targetLatitude,
          targetLongitude: _targetLongitude,
        ),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              '地图预览加载失败，请使用下方按钮打开系统地图查看位置',
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = currentLocation;
    final distance = _calculateDistanceMeters();
    final hasTarget = _targetLatitude != null && _targetLongitude != null;
    final inRange = distance != null && _radiusMeters != null && distance <= _radiusMeters!;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '位置与小地图',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: '重新定位',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(error!, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
              )
            else if (current == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('正在等待当前位置...', style: TextStyle(fontSize: 12)),
              )
            else ...[
              Text(
                kIsWeb ? '测试小地图' : '位置预览',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 2.1,
                child: _buildMapPreview(
                  currentLatitude: current.latitude,
                  currentLongitude: current.longitude,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.my_location,
                    label: '${_formatCoordinate(current.latitude)}, ${_formatCoordinate(current.longitude)}',
                  ),
                  _InfoChip(
                    icon: Icons.gps_fixed,
                    label: current.accuracy == null
                        ? current.provider
                        : '${current.provider} · ±${current.accuracy!.toStringAsFixed(0)}m',
                  ),
                  if (hasTarget)
                    _InfoChip(
                      icon: inRange ? Icons.check_circle : Icons.near_me,
                      label: '距规则点 ${_formatDistance(distance)}',
                      color: inRange ? Colors.green : Colors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openMap(
                      context,
                      latitude: current.latitude,
                      longitude: current.longitude,
                      label: '当前位置',
                    ),
                    icon: const Icon(Icons.navigation_outlined),
                    label: Text(kIsWeb ? '在浏览器打开位置' : '打开系统地图'),
                  ),
                  if (hasTarget)
                    OutlinedButton.icon(
                      onPressed: () => _openMap(
                        context,
                        latitude: _targetLatitude!,
                        longitude: _targetLongitude!,
                        label: ruleInfo?['location_name']?.toString() ?? '规则地点',
                      ),
                      icon: const Icon(Icons.place_outlined),
                      label: const Text('打开规则地点'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (hasTarget)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ruleInfo?['location_name']?.toString() ?? '规则地点',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if ((ruleInfo?['location_address']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            ruleInfo!['location_address'].toString(),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '规则坐标: ${_formatCoordinate(_targetLatitude!)}, ${_formatCoordinate(_targetLongitude!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      if (_radiusMeters != null)
                        Text(
                          '允许范围: ${_radiusMeters!.toStringAsFixed(0)} m'
                          '${distance == null ? '' : ' · 当前${inRange ? '在' : '不在'}范围内'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: inRange ? Colors.green.shade700 : Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _WebMiniMap extends StatelessWidget {
  final double currentLatitude;
  final double currentLongitude;
  final double? targetLatitude;
  final double? targetLongitude;
  final double? radiusMeters;

  const _WebMiniMap({
    required this.currentLatitude,
    required this.currentLongitude,
    required this.targetLatitude,
    required this.targetLongitude,
    required this.radiusMeters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6DFEB)),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9F4E6), Color(0xFFF8FBFF)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WebMiniMapPainter(
                  currentLatitude: currentLatitude,
                  currentLongitude: currentLongitude,
                  targetLatitude: targetLatitude,
                  targetLongitude: targetLongitude,
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '测试小地图',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '蓝点: 当前位置',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                      ),
                      if (targetLatitude != null && targetLongitude != null)
                        Text(
                          '橙点: 规则地点${radiusMeters == null ? '' : ' · ${radiusMeters!.toStringAsFixed(0)}m'}',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebMiniMapPainter extends CustomPainter {
  final double currentLatitude;
  final double currentLongitude;
  final double? targetLatitude;
  final double? targetLongitude;

  const _WebMiniMapPainter({
    required this.currentLatitude,
    required this.currentLongitude,
    required this.targetLatitude,
    required this.targetLongitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawLandBlocks(canvas, size);
    _drawRoads(canvas, size);
    _drawCompass(canvas);

    final current = Offset(size.width * 0.42, size.height * 0.55);
    _drawMarker(
      canvas,
      current,
      const Color(0xFF1677FF),
      '当前位置',
      const Color(0xFF0F5FD6),
    );

    if (targetLatitude == null || targetLongitude == null) {
      return;
    }

    final latDiff = targetLatitude! - currentLatitude;
    final lonDiff = targetLongitude! - currentLongitude;
    const scale = 80000.0;
    final rawDx = lonDiff * scale;
    final rawDy = -latDiff * scale;
    final clampedDx = rawDx.clamp(-size.width * 0.24, size.width * 0.24);
    final clampedDy = rawDy.clamp(-size.height * 0.24, size.height * 0.24);
    final target = Offset(current.dx + clampedDx, current.dy + clampedDy);

    final guidePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(current, target, guidePaint);

    _drawMarker(
      canvas,
      target,
      const Color(0xFFFF9F1A),
      '规则地点',
      const Color(0xFFB85D00),
    );
  }

  void _drawLandBlocks(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = const Color(0xFFDDEAD7);
    final blocks = [
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06, size.height * 0.12, size.width * 0.26, size.height * 0.18),
        const Radius.circular(18),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.18, size.width * 0.18, size.height * 0.13),
        const Radius.circular(14),
      ),
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.72, size.width * 0.22, size.height * 0.12),
        const Radius.circular(14),
      ),
    ];

    for (final block in blocks) {
      canvas.drawRRect(block, blockPaint);
    }
  }

  void _drawRoads(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final roadBorder = Paint()
      ..color = const Color(0xFFCAD4E4)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final roads = [
      [Offset(size.width * 0.08, size.height * 0.34), Offset(size.width * 0.92, size.height * 0.34)],
      [Offset(size.width * 0.18, size.height * 0.1), Offset(size.width * 0.18, size.height * 0.9)],
      [Offset(size.width * 0.48, size.height * 0.16), Offset(size.width * 0.82, size.height * 0.78)],
    ];

    for (final road in roads) {
      canvas.drawLine(road[0], road[1], roadBorder);
      canvas.drawLine(road[0], road[1], roadPaint);
    }
  }

  void _drawCompass(Canvas canvas) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFF334155),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(14, 10));
  }

  void _drawMarker(Canvas canvas, Offset center, Color color, String label, Color textColor) {
    final haloPaint = Paint()..color = color.withValues(alpha: 0.14);
    canvas.drawCircle(center, 18, haloPaint);

    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.08);
    canvas.drawCircle(center + const Offset(0, 3), 12, shadowPaint);

    final circlePaint = Paint()..color = color;
    canvas.drawCircle(center, 12, circlePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 12, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 90);

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + 16,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _WebMiniMapPainter oldDelegate) {
    return currentLatitude != oldDelegate.currentLatitude ||
        currentLongitude != oldDelegate.currentLongitude ||
        targetLatitude != oldDelegate.targetLatitude ||
        targetLongitude != oldDelegate.targetLongitude;
  }
}
