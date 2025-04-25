import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class BottomToolbar extends StatefulWidget {
  const BottomToolbar({super.key});

  @override
  State<BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends State<BottomToolbar> {
  bool hasUnreadNotifications = false;

  bool _hasEventPermission       = true;
  bool _hasDeliveryPermission    = true;
  bool _hasNotificationPermission= true;
  bool _isInitialized            = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    // TODO: hook up NotificationService → hasUnreadNotifications
  }

  Future<void> _loadPermissions() async {
    final role = context.read<RolePermissions>();
    final eventPerm  = await role.hasPermission('manage_events');
    final delivPerm  = await role.hasPermission('view_deliveries');
    final notifPerm  = await role.hasPermission('manage_events');

    if (!mounted) return;
    setState(() {
      _hasEventPermission        = eventPerm;
      _hasDeliveryPermission     = delivPerm;
      _hasNotificationPermission = notifPerm;
      _isInitialized             = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BottomAppBar(
      color: scheme.primary,                // ← palette aware
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Events
          _buildPermittedNav(
            hasPerm : _hasEventPermission,
            context : context,
            icon    : Icons.event_available,
            label   : 'Events',
            onTap   : () => context.push('/events'),
          ),

          // Calendar (always allowed)
          _buildNavItem(
            context : context,
            icon    : Icons.calendar_today,
            label   : 'Calendar',
            onPressed: () => context.push('/calendar'),
          ),

          // Home – floating circle
          _buildHomeButton(context, scheme.primary),

          // Deliveries
          _buildPermittedNav(
            hasPerm : _hasDeliveryPermission,
            context : context,
            icon    : Icons.route,
            label   : 'Deliveries',
            onTap   : () => context.push('/driver-deliveries'),
          ),

          // Notifications (show red dot if unread)
          _buildPermittedNav(
            hasPerm : _hasNotificationPermission,
            context : context,
            icon    : Icons.notifications,
            label   : 'Notifications',
            onTap   : () => context.push('/notifications'),
            hasNotification: hasUnreadNotifications,
          ),
        ],
      ),
    );
  }

  // Convenience wrapper to grey-out if no permission
  Widget _buildPermittedNav({
    required bool hasPerm,
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool hasNotification = false,
  }) {
    return hasPerm
        ? _buildNavItem(
            context: context,
            icon: icon,
            label: label,
            onPressed: onTap,
            hasNotification: hasNotification,
          )
        : Opacity(
            opacity: .3,
            child: _buildNavItem(
              context: context,
              icon: icon,
              label: label,
              onPressed: () {},                 // disabled
            ),
          );
  }

  // Generic item
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
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: Colors.white),
                if (hasNotification)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Central Home FAB-style button
  Widget _buildHomeButton(BuildContext context, Color bg) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: bg,                            // ← palette aware
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.2),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.white.withOpacity(.3),
          highlightColor: Colors.white.withOpacity(.1),
          onTap: () {
            while (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            context.go('/home');
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.home, color: Colors.white, size: 20),
              SizedBox(height: 1),
              Text('Home',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
