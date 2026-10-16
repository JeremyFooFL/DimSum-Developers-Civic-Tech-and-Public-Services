import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/train_graph.dart';
import '../widgets/app_scaffold.dart';
import 'capacity_page.dart';
import 'home_page.dart';

class CapacityTestPage extends StatefulWidget {
  const CapacityTestPage({
    super.key,
    this.showBackToHome = false,
    required this.routePlan,
    required this.stationsById,
  });

  final bool showBackToHome;
  final RoutePlan routePlan;
  final Map<String, StationNode> stationsById;

  @override
  State<CapacityTestPage> createState() => _CapacityTestPageState();
}

class _CapacityTestPageState extends State<CapacityTestPage> {
  static const int _capacityStep = 25;

  Timer? _backendPollTimer;
  late final TextEditingController _backendUrlController;
  late String _backendBaseUrl;
  bool _syncWithBackend = false;
  bool _isBackendBusy = false;
  int _testCapacityPercent = 0;
  String _backendStatus = 'Local simulation mode';

  @override
  void initState() {
    super.initState();
    _backendBaseUrl = _defaultBackendUrl();
    _backendUrlController = TextEditingController(text: _backendBaseUrl);
    _backendPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_syncWithBackend) {
        _fetchBackendCapacity();
      }
    });
  }

  @override
  void dispose() {
    _backendPollTimer?.cancel();
    _backendUrlController.dispose();
    super.dispose();
  }

  String _defaultBackendUrl() {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }

    return 'http://127.0.0.1:5000';
  }

  void _applyBackendUrl() {
    final next = _backendUrlController.text.trim();
    if (next.isEmpty) {
      return;
    }

    setState(() {
      _backendBaseUrl = next;
      _backendStatus = _syncWithBackend
          ? 'Connecting to $_backendBaseUrl'
          : 'Local simulation mode';
    });

    if (_syncWithBackend) {
      _fetchBackendCapacity();
    }
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

  Widget _buildCapacityCard(int percent, Color color) {
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
                  'COACH 1',
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
                  _capacityLabel(percent),
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
                '$percent%',
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

  Widget _buildCoachRow(int percent) {
    final color = _loadColor(context, percent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
      ),
      child: Row(
        children: [
          _buildCarriageVisual(color: color, isLead: true),
          const SizedBox(width: 12),
          Expanded(child: _buildCapacityCard(percent, color)),
        ],
      ),
    );
  }

  Future<void> _fetchBackendCapacity() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendBaseUrl/capacity'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != 200) {
        if (!mounted) {
          return;
        }

        setState(() {
          _backendStatus = 'Backend unavailable (${response.statusCode})';
          _syncWithBackend = false;
        });
        return;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final percent = (payload['capacityPercent'] as num?)?.toInt() ?? 0;

      if (!mounted) {
        return;
      }

      setState(() {
        _testCapacityPercent = percent < 0 ? 0 : percent;
        _backendStatus = 'Connected to YOLO backend';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _backendStatus = 'Unable to reach backend at $_backendBaseUrl';
        _syncWithBackend = false;
      });
    }
  }

  Future<void> _sendBackendEvent(String event) async {
    if (!_syncWithBackend) {
      return;
    }

    setState(() {
      _isBackendBusy = true;
    });

    try {
      final response = await http
          .post(Uri.parse('$_backendBaseUrl/event/$event'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        await _fetchBackendCapacity();
      } else if (mounted) {
        setState(() {
          _backendStatus = 'Backend event failed (${response.statusCode})';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _backendStatus = 'Unable to send $event event to backend';
          _syncWithBackend = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackendBusy = false;
        });
      }
    }
  }

  Future<void> _incrementTestCapacity() async {
    setState(() {
      _testCapacityPercent += _capacityStep;
    });
    await _sendBackendEvent('enter');
  }

  Future<void> _decrementTestCapacity() async {
    setState(() {
      final next = _testCapacityPercent - _capacityStep;
      _testCapacityPercent = next < 0 ? 0 : next;
    });
    await _sendBackendEvent('exit');
  }

  Future<void> _resetTestCapacity() async {
    setState(() {
      _testCapacityPercent = 0;
    });

    if (!_syncWithBackend) {
      return;
    }

    try {
      await http
          .post(Uri.parse('$_backendBaseUrl/reset'))
          .timeout(const Duration(seconds: 2));
      await _fetchBackendCapacity();
    } catch (_) {
      if (mounted) {
        setState(() {
          _backendStatus = 'Unable to reset backend counter';
          _syncWithBackend = false;
        });
      }
    }
  }

  void _goToApplicationView() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CapacityPage(
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
            'Test',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Switch(
            value: true,
            onChanged: (value) {
              if (!value) {
                _goToApplicationView();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0,
      title: 'Capacity Test View',
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
                  _buildSectionHeader(
                    context,
                    title: 'Capacity Test Controls',
                    subtitle: 'Proof of concept: each pass in is +25%, each pass out is -25%.',
                  ),
                  const SizedBox(height: 10),
                  _buildPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Capacity',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildCoachRow(_testCapacityPercent),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: _isBackendBusy ? null : _incrementTestCapacity,
                              icon: const Icon(Icons.login),
                              label: const Text('Pass In (+25%)'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: _isBackendBusy ? null : _decrementTestCapacity,
                              icon: const Icon(Icons.logout),
                              label: const Text('Pass Out (-25%)'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isBackendBusy ? null : _resetTestCapacity,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset to 0%'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Sync with YOLO backend'),
                          subtitle: Text(_backendStatus),
                          value: _syncWithBackend,
                          onChanged: (enabled) {
                            setState(() {
                              _syncWithBackend = enabled;
                              _backendStatus = enabled
                                  ? 'Connecting to $_backendBaseUrl'
                                  : 'Local simulation mode';
                            });

                            if (enabled) {
                              _fetchBackendCapacity();
                            }
                          },
                        ),
                        Text(
                          'Backend URL: $_backendBaseUrl',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _backendUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Backend URL',
                            hintText: 'http://10.0.2.2:5000',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _applyBackendUrl(),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _applyBackendUrl,
                            icon: const Icon(Icons.link),
                            label: const Text('Apply URL'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tip: Android emulator uses 10.0.2.2. Physical devices use your PC LAN IP.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
