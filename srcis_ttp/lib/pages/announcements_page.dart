import 'package:flutter/material.dart';
import '../widgets/app_scaffold.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final Set<int> _expandedCards = <int>{};

  static const List<({String title, String body})> _announcements = [
    (
      title: 'Service Delay Notice',
      body:
          'Trains on the Blue Line are currently delayed by 10-15 minutes due to signal maintenance near Central Junction. Please allow extra travel time and watch for platform updates in the station.',
    ),
    (
      title: 'Weekend Schedule Update',
      body:
          'Starting this Saturday, Route 4 will run every 20 minutes from 7:00 AM to 10:00 PM. Late-night trips after 10:00 PM will continue hourly. Check station boards for exact departure times.',
    ),
    (
      title: 'New Accessibility Feature',
      body:
          'Elevator status alerts are now available in the app. You can quickly view outages, estimated repair times, and suggested alternative paths before starting your trip.',
    ),
    (
      title: 'Safety Reminder',
      body:
          'Please stand behind the yellow line until the train comes to a complete stop. Keep aisles clear and report suspicious activity to station staff or using the in-app help section.',
    ),
  ];

  void _toggleCard(int index) {
    setState(() {
      if (_expandedCards.contains(index)) {
        _expandedCards.remove(index);
      } else {
        _expandedCards.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
    currentIndex: 1,
      title: 'Announcements',
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        itemCount: _announcements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final announcement = _announcements[index];
          final isExpanded = _expandedCards.contains(index);

          return Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _toggleCard(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.surface,
                      Theme.of(context).colorScheme.surfaceContainerLow,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(Icons.expand_more),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      announcement.body,
                      maxLines: isExpanded ? null : 3,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
