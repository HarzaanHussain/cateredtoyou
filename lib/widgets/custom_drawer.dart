import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          SizedBox(
            height: 150, // Ensures proper header height
            width: double.infinity, // Stretches header across full width
            child: DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFFC533), // Your preferred header color
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CateredToYou',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => context.go('/home'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Staff Management'),
            onTap: () => context.go('/staff'),
          ),
          ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Menu Management'),
            onTap: () => context.go('/menu-items'),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Fleet Management'),
            onTap: () => context.go('/vehicles'),
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {}, // Handle logout logic
          ),
        ],
      ),
    );
  }
}
