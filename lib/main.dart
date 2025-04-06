import 'dart:async';

import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:cateredtoyou/services/task_automation_service.dart';
import 'package:cateredtoyou/services/task_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/routes/app_router.dart';
import 'package:cateredtoyou/services/firebase_service.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/services/inventory_service.dart';
import 'package:cateredtoyou/services/customer_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
// Import the ThemeManager service and themes
import 'package:cateredtoyou/services/theme_manager.dart';

/// Class to handle secondary Firebase app initialization
class FirebaseSecondary {
  static late FirebaseApp secondaryApp;
  static late FirebaseAuth secondaryAuth;

  static Future<void> initializeSecondary() async {
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'Secondary',
        options: Firebase.app().options,
      );
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    } catch (e) {
      secondaryApp = Firebase.app('Secondary');
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    }
  }
}

void setupRecurringNotificationsCheck() {
  NotificationService().processRecurringNotifications();
  Timer.periodic(const Duration(hours: 1), (timer) {
    NotificationService().processRecurringNotifications();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await FirebaseSecondary.initializeSecondary();
  await NotificationService().initNotification();
  setupRecurringNotificationsCheck();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Organization service should be first as other services depend on it
        ChangeNotifierProvider(create: (_) => OrganizationService()),
        Provider<AuthService>(create: (_) => AuthService()),
        // Staff service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => StaffService(context.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => ManifestService(context.read<OrganizationService>()),
        ),
        // Inventory service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => InventoryService(context.read<OrganizationService>()),
        ),
        // Vehicle service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => VehicleService(context.read<OrganizationService>()),
        ),
        // Delivery route service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => DeliveryRouteService(context.read<OrganizationService>()),
        ),
        // Role permissions service
        ChangeNotifierProvider(create: (_) => RolePermissions()),
        // Auth model should be last as it might depend on other services
        ChangeNotifierProvider(create: (_) => AuthModel()),
        // Task service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => TaskService(context.read<OrganizationService>()),
        ),
        // Task automation service depends on TaskService
        Provider(
          create: (context) => TaskAutomationService(
            context.read<TaskService>(),
            context.read<OrganizationService>(),
          ),
        ),
        // Event service depends on OrganizationService and TaskAutomationService
        ChangeNotifierProvider(
          create: (context) => EventService(
            context.read<OrganizationService>(),
            context.read<TaskAutomationService>(),
          ),
        ),
        // Menu item service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => MenuItemService(context.read<OrganizationService>()),
        ),
        // Customer service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => CustomerService(context.read<OrganizationService>()),
        ),
        // Add ThemeManager to enable dark mode toggling
        ChangeNotifierProvider(create: (_) => ThemeManager()),
      ],
      child: Builder(
        builder: (context) {
          final authModel = context.watch<AuthModel>();
          final themeManager = context.watch<ThemeManager>();
          final appRouter = AppRouter(authModel);

          return MaterialApp.router(
            title: 'CateredToYou',
            debugShowCheckedModeBanner: false,
            // Use the themes from theme_manager.dart
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeManager.themeMode,
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
