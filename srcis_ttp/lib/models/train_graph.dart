import 'dart:convert';

class StationNode {
  const StationNode({
    required this.id,
    required this.name,
    required this.line,
  });

  final String id;
  final String name;
  final String line;
}

class RouteSegment {
  const RouteSegment({
    required this.fromId,
    required this.toId,
    required this.minutes,
    required this.isInterchange,
    this.interchangeStation,
  });

  final String fromId;
  final String toId;
  final int minutes;
  final bool isInterchange;
  final String? interchangeStation;
}

class RoutePlan {
  const RoutePlan({
    required this.originId,
    required this.destinationId,
    required this.totalMinutes,
    required this.stationPath,
    required this.segments,
    required this.interchangeStations,
  });

  final String originId;
  final String destinationId;
  final int totalMinutes;
  final List<String> stationPath;
  final List<RouteSegment> segments;
  final List<String> interchangeStations;
}

class TrainGraph {
  TrainGraph({required this.stationsById}) {
    for (final id in stationsById.keys) {
      _adjacency[id] = <_GraphEdge>[];
    }
  }

  final Map<String, StationNode> stationsById;
  final Map<String, List<_GraphEdge>> _adjacency = {};
  final Set<String> _edgeKeys = {};

  static TrainGraph fromJsonString(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Graph JSON root must be an object.');
    }

    final rawStations = decoded['stations'];
    if (rawStations is! Map<String, dynamic>) {
      throw const FormatException('stations must be a map of line names.');
    }

    final stationsById = <String, StationNode>{};
    final stationsByLine = <String, List<StationNode>>{};

    for (final lineEntry in rawStations.entries) {
      final lineLabel = lineEntry.key;
      final lineStations = lineEntry.value;
      if (lineStations is! List) {
        continue;
      }

      final parsedLineStations = <StationNode>[];
      for (final item in lineStations) {
        if (item is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString();
        final name = map['name']?.toString();
        final stationLine = map['line']?.toString() ?? lineLabel;

        if (id == null || name == null) {
          continue;
        }

        final station = StationNode(id: id, name: name, line: stationLine);
        stationsById[id] = station;
        parsedLineStations.add(station);
      }

      if (parsedLineStations.isNotEmpty) {
        stationsByLine[lineLabel] = parsedLineStations;
      }
    }

    final graph = TrainGraph(stationsById: stationsById);

    // Build in-line station connections from station ordering.
    for (final lineStations in stationsByLine.values) {
      for (var i = 0; i < lineStations.length - 1; i++) {
        graph._addEdge(
          from: lineStations[i].id,
          to: lineStations[i + 1].id,
          minutes: 6,
          isInterchange: false,
        );
      }
    }

    final rawEdges = decoded['edges'];
    if (rawEdges is Map<String, dynamic>) {
      for (final lineEdges in rawEdges.values) {
        if (lineEdges is! List) {
          continue;
        }

        for (final edge in lineEdges) {
          if (edge is! Map) {
            continue;
          }

          final map = Map<String, dynamic>.from(edge);
          final from = map['from']?.toString();
          final to = map['to']?.toString();
          if (from == null || to == null) {
            continue;
          }

          graph._addEdge(
            from: from,
            to: to,
            minutes: 6,
            isInterchange: false,
          );
        }
      }
    }

    final rawInterchanges = decoded['interchanges'];
    if (rawInterchanges is List) {
      for (final interchange in rawInterchanges) {
        if (interchange is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(interchange);
        final from = map['from']?.toString();
        final to = map['to']?.toString();
        final stationName = map['station']?.toString();
        if (from == null || to == null) {
          continue;
        }

        graph._addEdge(
          from: from,
          to: to,
          minutes: 2,
          isInterchange: true,
          interchangeStation: stationName,
        );
      }
    }

    return graph;
  }

  void _addEdge({
    required String from,
    required String to,
    required int minutes,
    required bool isInterchange,
    String? interchangeStation,
  }) {
    if (!stationsById.containsKey(from) || !stationsById.containsKey(to)) {
      return;
    }

    final keyA = '$from|$to|$minutes|$isInterchange|${interchangeStation ?? ''}';
    final keyB = '$to|$from|$minutes|$isInterchange|${interchangeStation ?? ''}';

    if (_edgeKeys.contains(keyA) || _edgeKeys.contains(keyB)) {
      return;
    }

    _edgeKeys.add(keyA);
    _edgeKeys.add(keyB);

    _adjacency[from]!.add(
      _GraphEdge(
        to: to,
        minutes: minutes,
        isInterchange: isInterchange,
        interchangeStation: interchangeStation,
      ),
    );

    _adjacency[to]!.add(
      _GraphEdge(
        to: from,
        minutes: minutes,
        isInterchange: isInterchange,
        interchangeStation: interchangeStation,
      ),
    );
  }

  RoutePlan? findFastestRoute({
    required String originId,
    required String destinationId,
  }) {
    if (!stationsById.containsKey(originId) ||
        !stationsById.containsKey(destinationId)) {
      return null;
    }

    if (originId == destinationId) {
      return RoutePlan(
        originId: originId,
        destinationId: destinationId,
        totalMinutes: 0,
        stationPath: [originId],
        segments: const [],
        interchangeStations: const [],
      );
    }

    final distances = <String, int>{
      for (final id in stationsById.keys) id: 1 << 30,
    };
    final visited = <String>{};
    final previousNode = <String, String>{};
    final previousEdge = <String, _GraphEdge>{};

    distances[originId] = 0;

    while (visited.length < stationsById.length) {
      String? current;
      var currentDistance = 1 << 30;

      for (final id in stationsById.keys) {
        final distance = distances[id]!;
        if (!visited.contains(id) && distance < currentDistance) {
          current = id;
          currentDistance = distance;
        }
      }

      if (current == null || currentDistance == 1 << 30) {
        break;
      }

      if (current == destinationId) {
        break;
      }

      visited.add(current);

      for (final edge in _adjacency[current] ?? const <_GraphEdge>[]) {
        if (visited.contains(edge.to)) {
          continue;
        }

        final candidate = currentDistance + edge.minutes;
        if (candidate < distances[edge.to]!) {
          distances[edge.to] = candidate;
          previousNode[edge.to] = current;
          previousEdge[edge.to] = edge;
        }
      }
    }

    if (distances[destinationId] == null || distances[destinationId] == 1 << 30) {
      return null;
    }

    final reversedPath = <String>[destinationId];
    final reversedSegments = <RouteSegment>[];
    final interchangeStations = <String>[];

    var current = destinationId;
    while (current != originId) {
      final prev = previousNode[current];
      final edge = previousEdge[current];
      if (prev == null || edge == null) {
        return null;
      }

      reversedPath.add(prev);
      reversedSegments.add(
        RouteSegment(
          fromId: prev,
          toId: current,
          minutes: edge.minutes,
          isInterchange: edge.isInterchange,
          interchangeStation: edge.interchangeStation,
        ),
      );

      if (edge.isInterchange) {
        final interchangeName = edge.interchangeStation ?? stationsById[prev]?.name;
        if (interchangeName != null && !interchangeStations.contains(interchangeName)) {
          interchangeStations.add(interchangeName);
        }
      }

      current = prev;
    }

    final stationPath = reversedPath.reversed.toList(growable: false);
    final segments = reversedSegments.reversed.toList(growable: false);

    return RoutePlan(
      originId: originId,
      destinationId: destinationId,
      totalMinutes: distances[destinationId]!,
      stationPath: stationPath,
      segments: segments,
      interchangeStations: interchangeStations,
    );
  }
}

class _GraphEdge {
  const _GraphEdge({
    required this.to,
    required this.minutes,
    required this.isInterchange,
    this.interchangeStation,
  });

  final String to;
  final int minutes;
  final bool isInterchange;
  final String? interchangeStation;
}
