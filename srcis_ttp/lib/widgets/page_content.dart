import 'package:flutter/material.dart';

class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.icon,
    required this.heading,
    required this.subtitle,
  });

  final IconData icon;
  final String heading;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64),
          const SizedBox(height: 12),
          Text(heading, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
