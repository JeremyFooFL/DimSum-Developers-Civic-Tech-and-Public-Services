import 'dart:math';

import 'package:flutter/material.dart';

import '../models/train_graph.dart';
import '../widgets/app_scaffold.dart';
import 'capacity_test_page.dart';
import 'home_page.dart';

class CapacityPage extends StatefulWidget {
  const CapacityPage({
    super.key,
    this.showBackToHome = false,
    required this.routePlan,
    required this.stationsById,
  });

  final bool showBackToHome;
  final RoutePlan routePlan;
  final Map<String, StationNode> stationsById;

  @override
  State<CapacityPage> createState() => _CapacityPageState();
}

class _CapacityPageState extends State<CapacityPage> {
  final Random _random = Random();

  late List<_JourneyProjection> _journeyOptions;
  int _selectedTrainIndex = 0;
  int _selectedLegIndex = 0;

  @override
  void initState() {
    super.initState();
    _journeyOptions = _buildJourneyOptions();
  }

  _JourneyProjection get _selectedJourney => _journeyOptions[_selectedTrainIndex];

  _LegProjection get _selectedLeg {
    final legs = _selectedJourney.legs;
    if (legs.isEmpty) {
      return _LegProjection.empty();
    }

    final index = _selectedLegIndex.clamp(0, legs.length - 1);
    return legs[index];
  }

  String _stationName(String stationId) {
    return widget.stationsById[stationId]?.name ?? stationId;
  }

  List<_RideLegPlan> _buildRideLegPlans() {
    if (widget.routePlan.segments.isEmpty) {
      return const [];
    }

    final plans = <_RideLegPlan>[];
    String? currentFrom;
    String? currentTo;
    String? currentLine;
    var currentMinutes = 0;
    String? boardingLabel;

    void flushCurrent() {
      if (currentFrom == null || currentTo == null || currentMinutes <= 0) {
        return;
      }

      plans.add(
        _RideLegPlan(
          fromId: currentFrom,
          toId: currentTo,
          line: currentLine ?? widget.stationsById[currentFrom]?.line ?? 'Line',
          rideMinutes: currentMinutes,
          boardingLabel: boardingLabel ?? 'Board at ${_stationName(currentFrom)}',
        ),
      );
    }

    for (final segment in widget.routePlan.segments) {
      if (segment.isInterchange) {
        flushCurrent();

        currentFrom = null;
        currentTo = null;
        currentLine = null;
        currentMinutes = 0;

        final label = segment.interchangeStation ?? _stationName(segment.fromId);
        boardingLabel = 'Interchange at $label';
        continue;
      }

      if (currentFrom == null) {
        currentFrom = segment.fromId;
        currentLine = widget.stationsById[segment.fromId]?.line;
      }

      currentTo = segment.toId;
      currentMinutes += segment.minutes;
    }

    flushCurrent();
    return plans;
  }

  List<_JourneyProjection> _buildJourneyOptions() {
    final legPlans = _buildRideLegPlans();
    if (legPlans.isEmpty) {
      return [
        _JourneyProjection(
          trainLabel: _trainOrdinalLabel(1),
          totalEtaMinutes: 0,
          legs: [_LegProjection.empty()],
        ),
      ];
    }

    final options = <_JourneyProjection>[];

    for (var trainIndex = 0; trainIndex < 3; trainIndex++) {
      final legs = <_LegProjection>[];
      final baseWait = 2 + (trainIndex * 4);
      var elapsed = baseWait;
      var segmentCursor = 0;

      for (var legIndex = 0; legIndex < legPlans.length; legIndex++) {
        final leg = legPlans[legIndex];
        final etaToBoard = elapsed;

        final carriages = _buildCarriages(
          seed: (trainIndex + 1) * 1000 + (legIndex + 1) * 97 + _random.nextInt(90),
        );

        elapsed += leg.rideMinutes;

        legs.add(
          _LegProjection(
            legLabel: leg.boardingLabel,
            fromId: leg.fromId,
            toId: leg.toId,
            line: leg.line,
            etaToBoardMinutes: etaToBoard,
            etaToArriveMinutes: elapsed,
            carriages: carriages,
          ),
        );

        while (segmentCursor < widget.routePlan.segments.length &&
            !widget.routePlan.segments[segmentCursor].isInterchange) {
          segmentCursor++;
        }

        if (segmentCursor < widget.routePlan.segments.length &&
            widget.routePlan.segments[segmentCursor].isInterchange) {
          elapsed += widget.routePlan.segments[segmentCursor].minutes;
          segmentCursor++;
        }
      }

      options.add(
        _JourneyProjection(
          trainLabel: _trainOrdinalLabel(trainIndex + 1),
          totalEtaMinutes: elapsed,
          legs: legs,
        ),
      );
    }

    return options;
  }

  String _trainOrdinalLabel(int position) {
    switch (position) {
      case 1:
        return '1st Train';
      case 2:
        return '2nd Train';
      case 3:
        return '3rd Train';
      default:
        return '${position}th Train';
    }
  }

  List<_CarriageLoad> _buildCarriages({required int seed}) {
    final random = Random(seed);
    final carriageCount = 4 + random.nextInt(3);
    final midpoint = (carriageCount - 1) / 2;

    return List<_CarriageLoad>.generate(carriageCount, (index) {
      final distanceFromMiddle = (index - midpoint).abs();
      final normalizedDistance = midpoint == 0 ? 0.0 : distanceFromMiddle / midpoint;
      final middleBias = ((1 - normalizedDistance) * 38).round();
      final base = 24 + random.nextInt(34);
      final loadPercent = (base + middleBias).clamp(12, 98);

      return _CarriageLoad(number: index + 1, percent: loadPercent);
    });
  }

  Color _loadColor(BuildContext context, int percent) {
    if (percent >= 75) {
      return Theme.of(context).colorScheme.error;
    }

    if (percent >= 50) {
      return Colors.amber.shade700;
    }

    return Colors.green.shade600;
  }

  void _refreshLoads() {
    setState(() {
      _journeyOptions = _buildJourneyOptions();
    });
  }

  void _goToTestView() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CapacityTestPage(
          showBackToHome: widget.showBackToHome,
          routePlan: widget.routePlan,
          stationsById: widget.stationsById,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'App',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Switch(
            value: false,
            onChanged: (value) {
              if (value) {
                _goToTestView();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCarriageVisual({required Color color, required bool isLead}) {
    if (isLead) {
      return SizedBox(
        width: 88,
        height: 118,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 20,
                      child: Center(
                        child: CustomPaint(
                          size: const Size(double.infinity, 20),
                          painter: _RoundedNosePainter(color: color),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
                      child: Column(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.white.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 88,
      height: 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.95), color.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityCard(_CarriageLoad carriage, Color color) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.2),
        color: color.withValues(alpha: 0.08),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COACH ${carriage.number}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.1,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _capacityLabel(carriage.percent),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${carriage.percent}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capacityLabel(int percent) {
    if (percent >= 75) {
      return 'High crowding';
    }

    if (percent >= 50) {
      return 'Moderate crowding';
    }

    return 'Comfortable';
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPanel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildCoachRow(_CarriageLoad carriage, Color color) {
    final isLead = carriage.number == 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
      ),
      child: Row(
        children: [
          _buildCarriageVisual(color: color, isLead: isLead),
          const SizedBox(width: 12),
          Expanded(child: _buildCapacityCard(carriage, color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.routePlan;
    final originName = _stationName(route.originId);
    final destinationName = _stationName(route.destinationId);
    final selectedLeg = _selectedLeg;

    return AppScaffold(
      currentIndex: 0,
      title: 'Capacity Insights',
      actions: [_buildModeToggle()],
      automaticallyImplyLeading: !widget.showBackToHome,
      showBottomNavigation: false,
      leading: widget.showBackToHome
          ? IconButton(
              tooltip: 'Back to Home',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder<void>(
                    pageBuilder: (_, __, ___) => const HomePage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    transitionsBuilder: (_, __, ___, child) => child,
                  ),
                );
              },
            )
          : null,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$originName -> $destinationName',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Route travel time: ${route.totalMinutes} mins',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        if (route.interchangeStations.isEmpty)
                          Text(
                            'Route type: Direct service',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.interchangeStations.length == 1
                                    ? 'Interchange Station:'
                                    : 'Interchange Stations:',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: route.interchangeStations
                                    .map(
                                      (station) => Chip(
                                        avatar: const Icon(
                                          Icons.transfer_within_a_station,
                                          size: 18,
                                        ),
                                        label: Text(station),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    context,
                    title: '1. Select Train Arrival Timing',
                  ),
                  const SizedBox(height: 10),
                  _buildPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List<Widget>.generate(_journeyOptions.length, (index) {
                            final option = _journeyOptions[index];
                            final selected = index == _selectedTrainIndex;

                            return ChoiceChip(
                              selected: selected,
                              label: Text('${option.trainLabel} (${option.totalEtaMinutes} min)'),
                              onSelected: (_) {
                                setState(() {
                                  _selectedTrainIndex = index;
                                  _selectedLegIndex = 0;
                                });
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    context,
                    title: '2. Select Route Leg to View Coach Capacities',
                  ),
                  const SizedBox(height: 10),
                  _buildPanel(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(_selectedJourney.legs.length, (index) {
                        final leg = _selectedJourney.legs[index];
                        final selected = index == _selectedLegIndex;
                        final from = _stationName(leg.fromId);
                        final to = _stationName(leg.toId);

                        return ChoiceChip(
                          selected: selected,
                          label: Text('Leg ${index + 1}: $from -> $to'),
                          onSelected: (_) {
                            setState(() {
                              _selectedLegIndex = index;
                            });
                          },
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    context,
                    title: '3. Current Leg Summary',
                  ),
                  const SizedBox(height: 10),
                  _buildPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_stationName(selectedLeg.fromId)} -> ${_stationName(selectedLeg.toId)} (${selectedLeg.line})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Boarding ETA: ${selectedLeg.etaToBoardMinutes} min',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Arrival ETA: ${selectedLeg.etaToArriveMinutes} min',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionHeader(
                    context,
                    title: '4. Coach Capacity',
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: OutlinedButton.icon(
                      onPressed: _refreshLoads,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Capacity'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...selectedLeg.carriages.map((carriage) {
                    final color = _loadColor(context, carriage.percent);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCoachRow(carriage, color),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RideLegPlan {
  const _RideLegPlan({
    required this.fromId,
    required this.toId,
    required this.line,
    required this.rideMinutes,
    required this.boardingLabel,
  });

  final String fromId;
  final String toId;
  final String line;
  final int rideMinutes;
  final String boardingLabel;
}

class _JourneyProjection {
  const _JourneyProjection({
    required this.trainLabel,
    required this.totalEtaMinutes,
    required this.legs,
  });

  final String trainLabel;
  final int totalEtaMinutes;
  final List<_LegProjection> legs;
}

class _LegProjection {
  const _LegProjection({
    required this.legLabel,
    required this.fromId,
    required this.toId,
    required this.line,
    required this.etaToBoardMinutes,
    required this.etaToArriveMinutes,
    required this.carriages,
  });

  factory _LegProjection.empty() {
    return const _LegProjection(
      legLabel: 'No segment',
      fromId: '-',
      toId: '-',
      line: '-',
      etaToBoardMinutes: 0,
      etaToArriveMinutes: 0,
      carriages: [],
    );
  }

  final String legLabel;
  final String fromId;
  final String toId;
  final String line;
  final int etaToBoardMinutes;
  final int etaToArriveMinutes;
  final List<_CarriageLoad> carriages;
}

class _CarriageLoad {
  const _CarriageLoad({
    required this.number,
    required this.percent,
  });

  final int number;
  final int percent;
}

class _RoundedNosePainter extends CustomPainter {
  const _RoundedNosePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width / 4, size.height * 0.3, size.width / 2, 0)
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.3,
        size.width,
        size.height,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RoundedNosePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
