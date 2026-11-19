import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';

/// OpenStreetMap base layer (free, no API key).
Widget osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.yash.walkfit',
      maxNativeZoom: 19,
    );

Widget osmAttribution() => const SimpleAttributionWidget(
      source: Text('OpenStreetMap contributors'),
    );

/// One polyline per segment so paused gaps are not joined.
List<Polyline> routeLines(List<TrackPoint> pts, Color color) {
  final bySeg = <int, List<LatLng>>{};
  for (final p in pts) {
    bySeg.putIfAbsent(p.seg, () => []).add(LatLng(p.lat, p.lng));
  }
  return [
    for (final seg in bySeg.values)
      if (seg.length >= 2)
        Polyline(
          points: seg,
          strokeWidth: 6,
          color: color,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
  ];
}

Marker dotMarker(LatLng at, Color color, {double size = 20}) => Marker(
      point: at,
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
      ),
    );

/// Static map of a finished walk, zoomed to fit the route.
class RoutePreview extends StatelessWidget {
  final List<TrackPoint> points;
  final bool interactive;
  const RoutePreview({super.key, required this.points, this.interactive = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ll = points.map((p) => LatLng(p.lat, p.lng)).toList();
    if (ll.isEmpty) {
      return Container(
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Text('No GPS route recorded',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    final fit = ll.length >= 2 &&
        LatLngBounds.fromPoints(ll).northEast != LatLngBounds.fromPoints(ll).southWest;
    return FlutterMap(
      options: MapOptions(
        initialCenter: ll.first,
        initialZoom: 16,
        initialCameraFit: fit
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(ll),
                padding: const EdgeInsets.all(36),
                maxZoom: 18,
              )
            : null,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        osmTiles(),
        PolylineLayer(polylines: routeLines(points, cs.primary)),
        MarkerLayer(markers: [
          dotMarker(ll.first, Colors.green.shade600, size: 16),
          if (ll.length > 1) dotMarker(ll.last, Colors.red.shade600, size: 16),
        ]),
        osmAttribution(),
      ],
    );
  }
}
