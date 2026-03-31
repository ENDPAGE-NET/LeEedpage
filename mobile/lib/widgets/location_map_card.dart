import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../services/location_service.dart';
import 'osm_embed_stub.dart' if (dart.library.html) 'osm_embed_web.dart';

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
    required BuildContext context,
    required double currentLatitude,
    required double currentLongitude,
    required double centerLatitude,
    required double centerLongitude,
  }) {
    if (kIsWeb) {
      return OsmEmbedView(
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        targetLatitude: _targetLatitude,
        targetLongitude: _targetLongitude,
      );
    }

    final staticMapUrl = AppConfig.buildStaticMapUrl(
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
      currentLatitude: currentLatitude,
      currentLongitude: currentLongitude,
      targetLatitude: _targetLatitude,
      targetLongitude: _targetLongitude,
    );

    return Image.network(
      staticMapUrl,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = currentLocation;
    final distance = _calculateDistanceMeters();
    final hasTarget = _targetLatitude != null && _targetLongitude != null;
    final inRange = distance != null && _radiusMeters != null && distance <= _radiusMeters!;

    final centerLatitude = current == null
        ? _targetLatitude
        : hasTarget
            ? (current.latitude + _targetLatitude!) / 2
            : current.latitude;
    final centerLongitude = current == null
        ? _targetLongitude
        : hasTarget
            ? (current.longitude + _targetLongitude!) / 2
            : current.longitude;

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
                    '当前位置',
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
              if (centerLatitude != null && centerLongitude != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 2.1,
                    child: _buildMapPreview(
                      context: context,
                      currentLatitude: current.latitude,
                      currentLongitude: current.longitude,
                      centerLatitude: centerLatitude,
                      centerLongitude: centerLongitude,
                    ),
                  ),
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
