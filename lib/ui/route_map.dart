import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models.dart';

/// Free greyscale basemap (CARTO Positron / Dark Matter, OpenStreetMap data).
/// No API key needed.
Widget mapTiles(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return TileLayer(
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/${dark ? 'dark_all' : 'light_all'}/{z}/{x}/{y}{r}.png',
    subdomains: const ['a', 'b', 'c', 'd'],
    retinaMode: RetinaMode.isHighDensity(context),
    userAgentPackageName: 'com.yash.walkfit',
    maxNativeZoom: 20,
    tileProvider: NetworkTileProvider(
      cachingProvider: const DisabledMapCachingProvider(),
    ),
  );
}

Widget mapAttribution() => const SimpleAttributionWidget(
      source: Text('OpenStreetMap · CARTO'),
    );

/// One polyline per segment so paused gaps are not joined.
List<Polyline> routeLines(List<TrackPoint> pts, Color color, Color border) {
  final bySeg = <int, List<LatLng>>{};
  for (final p in pts) {
    bySeg.putIfAbsent(p.seg, () => []).add(LatLng(p.lat, p.lng));
  }
  return [
    for (final seg in bySeg.values)
      if (seg.length >= 2)
        Polyline(
          points: seg,
          strokeWidth: 5,
          color: color,
          borderStrokeWidth: 2,
          borderColor: border,
        ),
  ];
}

/// Current-position dot: solid centre with a soft halo.
Marker meMarker(BuildContext context, LatLng at) {
  final cs = Theme.of(context).colorScheme;
  return Marker(
    point: at,
    width: 44,
    height: 44,
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.onSurface.withValues(alpha: 0.14),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: cs.onSurface,
          shape: BoxShape.circle,
          border: Border.all(color: cs.surface, width: 3),
        ),
      ),
    ),
  );
}

/// Start (hollow) and finish (solid) markers.
Marker endMarker(BuildContext context, LatLng at, {required bool start}) {
  final cs = Theme.of(context).colorScheme;
  return Marker(
    point: at,
    width: 16,
    height: 16,
    child: Container(
      decoration: BoxDecoration(
        color: start ? cs.surface : cs.onSurface,
        shape: BoxShape.circle,
        border: Border.all(color: start ? cs.onSurface : cs.surface, width: 3),
      ),
    ),
  );
}

/// Map of a finished walk, zoomed to fit the route.
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
    final b = LatLngBounds.fromPoints(ll);
    final fit = ll.length >= 2 && b.northEast != b.southWest;
    return FlutterMap(
      options: MapOptions(
        initialCenter: ll.first,
        initialZoom: 16,
        initialCameraFit: fit
            ? CameraFit.bounds(
                bounds: b,
                padding: const EdgeInsets.all(40),
                maxZoom: 18,
              )
            : null,
        backgroundColor: cs.surfaceContainerHighest,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        mapTiles(context),
        PolylineLayer(polylines: routeLines(points, cs.onSurface, cs.surface)),
        MarkerLayer(markers: [
          endMarker(context, ll.first, start: true),
          if (ll.length > 1) endMarker(context, ll.last, start: false),
        ]),
        mapAttribution(),
      ],
    );
  }
}
