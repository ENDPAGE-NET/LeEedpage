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

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
