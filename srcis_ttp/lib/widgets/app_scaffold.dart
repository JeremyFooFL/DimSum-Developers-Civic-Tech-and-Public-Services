import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/announcements_page.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.title,
    required this.body,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.showBottomNavigation = true,
    this.actions,
  });

  final int currentIndex;
  final String title;
  final Widget body;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool showBottomNavigation;
  final List<Widget>? actions;

  static const String _appBarLogoAssetPath = 'assets/images/srcis_logo.png';

  void _goToPage(BuildContext context, int index) {
    if (index == currentIndex) {
      return;
    }

    final page = switch (index) {
      0 => const HomePage(),
      1 => const AnnouncementsPage(),
      _ => const HomePage(),
    };

    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }

  Widget _buildLeading() {
    if (leading == null) {
      return Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            _appBarLogoAssetPath,
            width: 94,
            height: 94,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.train),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Image.asset(
            _appBarLogoAssetPath,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.train, size: 20),
          ),
          const SizedBox(width: 4),
          Flexible(child: leading!),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leadingWidth: leading == null ? 68 : 118,
        leading: _buildLeading(),
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: showBottomNavigation
          ? Theme(
              data: Theme.of(context).copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  backgroundColor: navBlue,
                  indicatorColor: Colors.white,
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      color: selected ? navBlue : Colors.white,
                    );
                  }),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.message_outlined),
                    selectedIcon: Icon(Icons.message),
                    label: 'Announcements',
                  ),
                ],
                onDestinationSelected: (index) => _goToPage(context, index),
              ),
            )
          : null,
    );
  }
}
