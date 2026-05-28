import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'haversine.dart';

class AStarNode {
  final LatLng position;
  final double gCost;
  final double hCost;
  final AStarNode? parent;

  const AStarNode({
    required this.position,
    required this.gCost,
    required this.hCost,
    required this.parent,
  });

  double get fCost => gCost + hCost;
}

/// A* pathfinding for offline fallback routing on a simple road graph.
///
/// In production you should prefer Directions API / backend routing; this is
/// only meant as a last-resort fallback when you have an offline graph.
class AStarRouter {
  List<LatLng> findPath({
    required LatLng start,
    required LatLng goal,
    required List<List<LatLng>> roadGraph,
    double goalReachedMeters = 20,
    double neighborRadiusMeters = 500,
  }) {
    final open = PriorityQueue<AStarNode>((a, b) {
      final c = a.fCost.compareTo(b.fCost);
      return c != 0 ? c : a.hCost.compareTo(b.hCost);
    });
    final closed = <String>{};

    open.add(
      AStarNode(
        position: start,
        gCost: 0,
        hCost: Haversine.distanceMeters(start, goal),
        parent: null,
      ),
    );

    while (open.isNotEmpty) {
      final current = open.removeFirst();
      final key = _key(current.position);
      if (closed.contains(key)) continue;
      closed.add(key);

      if (Haversine.distanceMeters(current.position, goal) <= goalReachedMeters) {
        return _reconstructPath(current);
      }

      final neighbors = _getNeighbors(
        current.position,
        roadGraph,
        radiusMeters: neighborRadiusMeters,
      );
      for (final n in neighbors) {
        final nk = _key(n);
        if (closed.contains(nk)) continue;

        final g = current.gCost + Haversine.distanceMeters(current.position, n);
        final h = Haversine.distanceMeters(n, goal);
        open.add(
          AStarNode(position: n, gCost: g, hCost: h, parent: current),
        );
      }
    }

    return <LatLng>[start, goal];
  }

  List<LatLng> _reconstructPath(AStarNode node) {
    final path = <LatLng>[];
    AStarNode? cur = node;
    while (cur != null) {
      path.insert(0, cur.position);
      cur = cur.parent;
    }
    return path;
  }

  List<LatLng> _getNeighbors(
    LatLng pos,
    List<List<LatLng>> graph, {
    required double radiusMeters,
  }) {
    // Simple fallback: scan nodes and pick near ones. For large graphs, index
    // nodes by geohash or grid for performance.
    final out = <LatLng>[];
    for (final segment in graph) {
      for (final node in segment) {
        if (Haversine.distanceMeters(pos, node) <= radiusMeters) {
          out.add(node);
        }
      }
    }

    // Keep only nearest few to reduce branching factor.
    out.sort((a, b) {
      final da = Haversine.distanceMeters(pos, a);
      final db = Haversine.distanceMeters(pos, b);
      return da.compareTo(db);
    });
    return out.take(math.min(24, out.length)).toList();
  }

  String _key(LatLng p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
}

