import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/train_graph.dart';
import 'capacity_page.dart';
import '../widgets/app_scaffold.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      currentIndex: 0,
      title: 'Smartrail Capacity Insight',
      body: _RouteSearchContent(),
    );
  }
}

class _RouteSearchContent extends StatefulWidget {
  const _RouteSearchContent();

  @override
  State<_RouteSearchContent> createState() => _RouteSearchContentState();
}

class _RouteSearchContentState extends State<_RouteSearchContent> {
  static const String _graphAssetPath = 'assets/data/train_graph.json';
  static const String _mapAssetPath = 'assets/images/train_map.png';
  static const double _dropdownMenuHeight = 320;

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  TrainGraph? _graph;
  List<_StationOption> _stations = const [];
  Map<String, _StationOption> _stationsById = const {};
  List<DropdownMenuEntry<String>> _originMenuEntries = const [];
  List<DropdownMenuEntry<String>> _destinationMenuEntries = const [];
  bool _isLoadingStations = true;
  String? _stationLoadError;

  String? _origin;
  String? _destination;

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  bool get _canSearch =>
      _origin != null && _destination != null && _origin != _destination;

  String? _stationNameById(String? id) {
    return id == null ? null : _stationsById[id]?.name;
  }

  void _syncDropdownText() {
    _originController.text = _stationNameById(_origin) ?? '';
    _destinationController.text = _stationNameById(_destination) ?? '';
  }

  void _swapLocations() {
    if (_origin == null && _destination == null) {
      return;
    }

    setState(() {
      final previousOrigin = _origin;
      _origin = _destination;
      _destination = previousOrigin;
      _rebuildMenuEntries();
    });

    _syncDropdownText();
  }

  List<DropdownMenuEntry<String>> _buildMenuEntries({String? excludedId}) {
    final entries = <DropdownMenuEntry<String>>[];

    for (final station in _stations) {
      if (station.id == excludedId) {
        continue;
      }

      entries.add(
        DropdownMenuEntry<String>(
          value: station.id,
          label: station.name,
          trailingIcon: _lineBadge(station.line),
        ),
      );
    }

    return entries;
  }

  void _rebuildMenuEntries() {
    _originMenuEntries = _buildMenuEntries(excludedId: _destination);
    _destinationMenuEntries = _buildMenuEntries(excludedId: _origin);
  }

  Future<void> _loadStations() async {
    try {
      final jsonText = await rootBundle.loadString(_graphAssetPath);
      final graph = TrainGraph.fromJsonString(jsonText);
      final parsed = graph.stationsById.values
          .map(
            (station) => _StationOption(
              id: station.id,
              name: station.name,
              line: station.line,
            ),
          )
          .toList(growable: false);

      parsed.sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (byName != 0) {
          return byName;
        }

        final byLine = a.line.toLowerCase().compareTo(b.line.toLowerCase());
        if (byLine != 0) {
          return byLine;
        }

        return a.id.compareTo(b.id);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _graph = graph;
        _stations = parsed;
        _stationsById = {for (final station in parsed) station.id: station};
        _isLoadingStations = false;
        _stationLoadError = null;

        if (_origin != null && !_stations.any((station) => station.id == _origin)) {
          _origin = null;
        }

        if (_destination != null &&
            !_stations.any((station) => station.id == _destination)) {
          _destination = null;
        }

        _rebuildMenuEntries();
      });

      _syncDropdownText();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _graph = null;
        _isLoadingStations = false;
        _stationLoadError =
            'Unable to load station data from assets/data/train_graph.json';
        _stationsById = const {};
        _originMenuEntries = const [];
        _destinationMenuEntries = const [];
      });
    }
  }

  Color _lineColor(String lineName) {
    final normalized = lineName.toLowerCase();

    if (normalized.contains('kelana jaya')) {
      return const Color(0xFFD81B60);
    }
    if (normalized.contains('ampang')) {
      return const Color(0xFFE67E22);
    }
    if (normalized.contains('sri petaling')) {
      return const Color(0xFF7B2638);
    }
    if (normalized.contains('putrajaya')) {
      return const Color(0xFFF1C40F);
    }
    if (normalized.contains('kajang')) {
      return const Color(0xFF0B8E4E);
    }
    if (normalized.contains('ktm')) {
      return const Color(0xFF1F5A93);
    }

    return Colors.blueGrey;
  }

  Widget _lineBadge(String lineName) {
    final lineColor = _lineColor(lineName);

    return Container(
      constraints: const BoxConstraints(maxWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lineColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        lineName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  void _showMapViewer() {
    showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Map Viewer',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      panEnabled: true,
                      child: Image.asset(
                        _mapAssetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Image not found. Add your map image at\nassets/images/campus_map.png',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close map',
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose Your Route',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                DropdownMenu<String>(
                  controller: _originController,
                  width: double.infinity,
                  menuHeight: _dropdownMenuHeight,
                  initialSelection: _origin,
                  enabled: !_isLoadingStations,
                  requestFocusOnTap: true,
                  enableFilter: true,
                  enableSearch: true,
                  label: Text(_isLoadingStations ? 'Origin (loading...)' : 'Origin'),
                  dropdownMenuEntries: _originMenuEntries,
                  onSelected: (value) {
                    setState(() {
                      _origin = value;
                      _rebuildMenuEntries();
                    });
                    _originController.text = _stationNameById(value) ?? '';
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: IconButton.filled(
                    onPressed: _swapLocations,
                    tooltip: 'Swap origin and destination',
                    icon: const Icon(Icons.swap_vert),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownMenu<String>(
                  controller: _destinationController,
                  width: double.infinity,
                  menuHeight: _dropdownMenuHeight,
                  initialSelection: _destination,
                  enabled: !_isLoadingStations,
                  requestFocusOnTap: true,
                  enableFilter: true,
                  enableSearch: true,
                  label: Text(
                    _isLoadingStations ? 'Destination (loading...)' : 'Destination',
                  ),
                  dropdownMenuEntries: _destinationMenuEntries,
                  onSelected: (value) {
                    setState(() {
                      _destination = value;
                      _rebuildMenuEntries();
                    });
                    _destinationController.text = _stationNameById(value) ?? '';
                  },
                ),
                const SizedBox(height: 20),
                if (_stationLoadError != null) ...[
                  Text(
                    _stationLoadError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: () {
                    if (!_canSearch) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Tip: Select different origin and destination for route search.',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      return;
                    }

                    final graph = _graph;
                    if (graph == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Train graph is still loading.'),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      return;
                    }

                    final route = graph.findFastestRoute(
                      originId: _origin!,
                      destinationId: _destination!,
                    );

                    if (route == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No available route was found between these stations.',
                          ),
                          duration: Duration(seconds: 3),
                        ),
                      );

                      return;
                    }

                    Navigator.pushReplacement(
                      context,
                      PageRouteBuilder<void>(
                        pageBuilder: (_, __, ___) =>
                            CapacityPage(
                              showBackToHome: true,
                              routePlan: route,
                              stationsById: graph.stationsById,
                            ),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                        transitionsBuilder: (_, __, ___, child) => child,
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Train Map',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to open, then pinch to zoom and drag to move around.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _showMapViewer,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              _mapAssetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Add your image at\nassets/images/train_map.png',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(Icons.zoom_in),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StationOption {
  const _StationOption({
    required this.id,
    required this.name,
    required this.line,
  });

  final String id;
  final String name;
  final String line;
}
