import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';

class BottomToolbar extends StatelessWidget {
  const BottomToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          PermissionWidget(
            permissionId: 'manage_events',
            child: IconButton(
              icon: const Icon(Icons.event_available, size: 32),
              tooltip: 'Events',
              onPressed: () => context.push('/events'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 32),
            tooltip: 'Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          PermissionWidget(
            permissionId: 'view_deliveries',
            child: IconButton(
              icon: const Icon(Icons.route, size: 32),
              tooltip: 'My Deliveries',
              onPressed: () => context.push('/driver-deliveries'),
            ),
          ),
          PermissionWidget(
            // Need to create a notifications permission id, using placeholder now
            permissionId: 'manage_menu',
            child: IconButton(
              icon: const Icon(Icons.notifications, size: 32),
              tooltip: 'Notifications',
              onPressed: () => context.push('/notifications'),
            ),
          ),
        ],
      ),
    );
  }
}