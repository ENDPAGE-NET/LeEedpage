import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class OsmEmbedView extends StatelessWidget {
  final double currentLatitude;
  final double currentLongitude;
  final double? targetLatitude;
  final double? targetLongitude;

  const OsmEmbedView({
    super.key,
    required this.currentLatitude,
    required this.currentLongitude,
    this.targetLatitude,
    this.targetLongitude,
  });

  static final Set<String> _registeredViewTypes = <String>{};

  static String _formatCoordinate(double value) => value.toStringAsFixed(6);

  String _buildViewType() {
    final parts = [
      _formatCoordinate(currentLatitude),
      _formatCoordinate(currentLongitude),
      targetLatitude == null ? 'none' : _formatCoordinate(targetLatitude!),
      targetLongitude == null ? 'none' : _formatCoordinate(targetLongitude!),
    ];
    return 'osm-embed-${parts.join('-')}';
  }

  ({double minLat, double maxLat, double minLon, double maxLon}) _buildBounds() {
    final points = <({double lat, double lon})>[
      (lat: currentLatitude, lon: currentLongitude),
      if (targetLatitude != null && targetLongitude != null)
        (lat: targetLatitude!, lon: targetLongitude!),
    ];

    final minLat = points.map((point) => point.lat).reduce(math.min);
    final maxLat = points.map((point) => point.lat).reduce(math.max);
    final minLon = points.map((point) => point.lon).reduce(math.min);
    final maxLon = points.map((point) => point.lon).reduce(math.max);

    const padding = 0.008;
    return (
      minLat: minLat - padding,
      maxLat: maxLat + padding,
      minLon: minLon - padding,
      maxLon: maxLon + padding,
    );
  }

  String _buildEmbedUrl() {
    final bounds = _buildBounds();
    final markerParams = <String>[
      'marker=${Uri.encodeQueryComponent('$currentLatitude,$currentLongitude')}',
      if (targetLatitude != null && targetLongitude != null)
        'marker=${Uri.encodeQueryComponent('$targetLatitude,$targetLongitude')}',
    ].join('&');

    return 'https://www.openstreetmap.org/export/embed.html?bbox='
        '${bounds.minLon},${bounds.minLat},${bounds.maxLon},${bounds.maxLat}'
        '&layer=mapnik&$markerParams';
  }

  void _ensureRegistered(String viewType) {
    if (_registeredViewTypes.contains(viewType)) {
      return;
    }

    final embedUrl = _buildEmbedUrl();
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = embedUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '14px'
        ..style.backgroundColor = '#f5f5f5'
        ..allowFullscreen = true;
      return iframe;
    });

    _registeredViewTypes.add(viewType);
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _buildViewType();
    _ensureRegistered(viewType);
    return HtmlElementView(viewType: viewType);
  }
}
