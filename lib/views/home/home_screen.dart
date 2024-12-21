import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();
    final UserModel? user = authModel.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CateredToYou'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authModel.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, ${user?.fullName ?? 'User'}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Role: ${user?.role ?? 'N/A'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (user?.role == 'admin' || user?.role == 'client' || user?.role == 'manager')
                ElevatedButton(
                  onPressed: () => context.push('/staff'),
                  child: const Text('Manage Staff'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
