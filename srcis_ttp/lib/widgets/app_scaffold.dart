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

  @override
  Widget build(BuildContext context) {
    final navBlue = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: leading,
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
