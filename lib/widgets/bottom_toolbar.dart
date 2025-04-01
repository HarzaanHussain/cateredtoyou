import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/widgets/permission_widget.dart';
// You'll likely want to import your notification service
// import 'package:cateredtoyou/services/notification_service.dart';

class BottomToolbar extends StatefulWidget {
  const BottomToolbar({super.key});

  @override
  State<BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends State<BottomToolbar> {
  // This can be updated when notification status changes
  bool hasUnreadNotifications = false;
  
  // You might want to add this when you implement the notification feature
  // late final NotificationService _notificationService;
  
  @override
  void initState() {
    super.initState();
    // Setup notification listeners here later
    // Example:
    // _notificationService = NotificationService();
    // _notificationService.unreadNotificationsStream.listen((hasUnread) {
    //   setState(() {
    //     hasUnreadNotifications = hasUnread;
    //   });
    // });
  }
  
  @override
  void dispose() {
    // Clean up any listeners when disposed
    // Example:
    // _notificationService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 68, // Further reduced from 70 to 68
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Events button
          PermissionWidget(
            permissionId: 'manage_events',
            child: _buildNavItem(
              context: context,
              icon: Icons.event_available,
              label: 'Events',
              onPressed: () => context.push('/events'),
            ),
          ),
          
          // Calendar button
          _buildNavItem(
            context: context,
            icon: Icons.calendar_today,
            label: 'Calendar',
            onPressed: () => context.push('/calendar'),
          ),
          
          // Home button (center, elevated)
          _buildHomeButton(context),
          
          // Deliveries button
          PermissionWidget(
            permissionId: 'view_deliveries',
            child: _buildNavItem(
              context: context,
              icon: Icons.route,
              label: 'Deliveries',
              onPressed: () => context.push('/driver-deliveries'),
            ),
          ),
          
          // Notifications button
          PermissionWidget(
            permissionId: 'manage_menu',
            child: _buildNavItem(
              context: context,
              icon: Icons.notifications,
              label: 'Notifications',
              hasNotification: hasUnreadNotifications, // Using the state variable
              onPressed: () => context.push('/notifications'),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build navigation items with icon and text
  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool hasNotification = false,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 60, // Further reduced from 65
        padding: const EdgeInsets.symmetric(vertical: 4), // Further reduced padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20), // Further reduced from 22
                if (hasNotification)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 8, // Further reduced notification dot
                      height: 8, // Further reduced notification dot
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1.0, // Reduced border width
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1), // Further reduced spacing
            Text(
              label,
              style: const TextStyle(fontSize: 9), // Further reduced from 10
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
  
  // Special home button with different styling
  Widget _buildHomeButton(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/home'),
      child: Container(
        width: 54, // Further reduced from 58
        height: 54, // Further reduced from 58
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home,
              color: Colors.white,
              size: 20, // Further reduced from 22
            ),
            const SizedBox(height: 1), // Further reduced spacing
            Text(
              'Home',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8, // Further reduced from 9
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}