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
// Import the ThemeManager service
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
            // Light theme
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: const ColorScheme(
                brightness: Brightness.light,
                primary: Color(0xFF2C3E50),
                onPrimary: Colors.white,
                secondary: Color(0xFFD4AF37),
                onSecondary: Colors.black,
                error: Colors.red,
                onError: Colors.white,
                surface: Color(0xFFFCF8F2),
                onSurface: Colors.black87,
              ),
              scaffoldBackgroundColor: const Color(0xFFFCF8F2),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2C3E50),
                foregroundColor: Colors.white,
                elevation: 4,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFBDC3C7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              cardTheme: CardTheme(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(8),
              ),
              textTheme: const TextTheme(
                headlineSmall: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                titleMedium: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
                bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => Colors.white,
                ),
                trackColor: WidgetStateProperty.all(const Color(0xFFD4AF37)),
                overlayColor: WidgetStateProperty.all(const Color(0xFFD4AF37)),
              ),
            ),
            // Dark theme: Adjust these values as desired
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: const ColorScheme(
                brightness: Brightness.dark,
                primary: Color(0xFF1A252F),
                onPrimary: Colors.white,
                secondary: Color(0xFFCBA135),
                onSecondary: Colors.white,
                error: Colors.red,
                onError: Colors.black,
                surface: Color(0xFF121212),
                onSurface: Colors.white70,
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1A252F),
                foregroundColor: Colors.white,
                elevation: 4,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCBA135),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFCBA135)),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              cardTheme: CardTheme(
                color: const Color(0xFF1E1E1E),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(8),
              ),
              textTheme: const TextTheme(
                headlineSmall: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                titleMedium: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
                bodyMedium: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color>(
                  (states) => Colors.white,
                ),
                trackColor: WidgetStateProperty.all(const Color(0xFFCBA135)),
                overlayColor: WidgetStateProperty.all(const Color(0xFFCBA135)),
              ),
            ),
            // Use the current theme mode from ThemeManager
            themeMode: themeManager.themeMode,
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
