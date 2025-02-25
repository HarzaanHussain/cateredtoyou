import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';

// This class is used to place a bottom toolbar into any view easily by adding
  // 'bottomNavigationBar: const BottomToolbar()'
// onto the Scaffold portion of the view
// and using import:
  // 'import package:cateredtoyou/widgets/bottom_toolbar.dart;'

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
            permissionId: 'view_tasks',
            child: IconButton(
              icon: const Icon(Icons.task, size: 32),
              tooltip: 'Tasks',
              onPressed: () => context.push('/tasks'),
            ),
          ),
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
            permissionId: 'view_inventory',
            child: IconButton(
              icon: const Icon(Icons.inventory, size: 32),
              tooltip: 'Inventory',
              onPressed: () => context.push('/inventory'),
            ),
          ),
        ],
      ),
    );
  }
}
