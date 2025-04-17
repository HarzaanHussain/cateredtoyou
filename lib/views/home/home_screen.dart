import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/widgets/custom_app_bar.dart';
import 'package:cateredtoyou/widgets/custom_drawer.dart';
import 'package:cateredtoyou/widgets/urgent_tasks_widget.dart';
import 'package:cateredtoyou/widgets/urgent_events_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authModel = context.watch<AuthModel>();
    final UserModel? user = authModel.user;
    final rolePermissions = context.read<RolePermissions>();

    return Scaffold(
      backgroundColor: Color(0xFFFAF9F6), // Set background color to orange
      appBar: const CustomAppBar(title: 'CateredToYou'),
      drawer: const CustomDrawer(),
      bottomNavigationBar: const BottomToolbar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Welcome, ${user?.fullName ?? 'User'}!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Role: ${user?.role.toUpperCase() ?? 'N/A'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),


              // Urgent Events Widget
              const UrgentEventsWidget(),

              const SizedBox(height: 24),

              // Urgent Tasks Widget - Added here
              const UrgentTasksWidget(),

              const SizedBox(height: 24),

              // Vehicle and Delivery Section
              FutureBuilder<bool>(
                future: Future.wait([
                  rolePermissions.hasPermission('manage_vehicles'),
                  rolePermissions.hasPermission('manage_deliveries')
                ]).then((permissions) => permissions.any((p) => p)),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Vehicles & Deliveries',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          children: [
                            PermissionWidget(
                              permissionId: 'manage_deliveries',
                              child: ListTile(
                                leading: const Icon(Icons.map),
                                title: const Text('Delivery Routes'),
                                subtitle: const Text('Manage and track delivery routes'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () => context.push('/add-delivery'),
                                    ),
                                    const Icon(Icons.arrow_forward_ios),
                                  ],
                                ),
                                onTap: () => context.push('/deliveries'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}