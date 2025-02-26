import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.orange[700],
            ),
            child: const Text(
              'CateredToYou Menu',
              style: TextStyle(fontSize: 24, color: Colors.white),
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
            title: const Text('Menu Items'),
            onTap: () => context.go('/menu-items'),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping),
            title: const Text('Fleet Management'),
            onTap: () => context.go('/vehicles'),
          ),
          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('My Deliveries'),
            onTap: () => context.go('/driver-deliveries'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => Navigator.pop(context), // Closes drawer
          ),
        ],
      ),
    );
  }
}
