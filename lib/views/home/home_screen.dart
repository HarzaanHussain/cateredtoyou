import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart';
import 'package:cateredtoyou/widgets/themed_app_bar.dart'; 
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
    //  backgroundColor: Color(0xFFFAF9F6), // Set background color to orange
      //appBar: const CustomAppBar(title: 'CateredToYou'),
      appBar: const ThemedAppBar('CateredToYou'),
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

              // Urgent Tasks Widget - Added here
              const UrgentTasksWidget(),
            ],
          ),
        ),
      ),
    );
  }
}