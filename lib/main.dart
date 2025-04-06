import 'dart:async';

import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart'; // DeliveryRouteService for delivery route-related operations
import 'package:cateredtoyou/services/event_service.dart'; // EventService for event-related operations
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/menu_item_service.dart'; // MenuItemService for menu item-related operations
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:cateredtoyou/services/task_automation_service.dart'; // TaskAutomationService for task automation operations
import 'package:cateredtoyou/services/task_service.dart'; // TaskService for task-related operations
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth package for Firebase authentication
import 'package:firebase_core/firebase_core.dart'; // Firebase core package for Firebase initialization
import 'package:flutter/material.dart'; // Flutter material package for UI components
import 'package:provider/provider.dart'; // Provider package for state management
import 'package:cateredtoyou/models/auth_model.dart'; // AuthModel for authentication state
import 'package:cateredtoyou/routes/app_router.dart'; // AppRouter for navigation
import 'package:cateredtoyou/services/firebase_service.dart'; // FirebaseService for Firebase initialization
import 'package:cateredtoyou/services/organization_service.dart'; // OrganizationService for organization-related operations
import 'package:cateredtoyou/services/staff_service.dart'; // StaffService for staff-related operations
import 'package:cateredtoyou/services/role_permissions.dart'; // RolePermissions for role-based permissions
import 'package:cateredtoyou/services/inventory_service.dart'; // InventoryService for inventory-related operations
import 'package:cateredtoyou/services/customer_service.dart'; // CustomerService for customer-related operations
import 'package:cateredtoyou/services/vehicle_service.dart'; // VehicleService for vehicle-related operations
import 'package:cateredtoyou/services/theme_manager.dart'; // ThemeManager service (provides light & dark themes) if we want to use later

/// Class to handle secondary Firebase app initialization
class FirebaseSecondary {
  static late FirebaseApp secondaryApp; // Secondary Firebase app instance
  static late FirebaseAuth secondaryAuth; // Secondary FirebaseAuth instance

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized before running the app
  await FirebaseService.initialize(); // Initialize Firebase services
  await FirebaseSecondary.initializeSecondary(); // Initialize secondary Firebase app
  await NotificationService().initNotification();

  runApp(const MyApp()); // Run the MyApp widget
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor for MyApp

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
        // **Add ThemeManager so that settings page and other screens can access it**
        ChangeNotifierProvider(create: (_) => ThemeManager()),
      ],
      child: Builder(
        builder: (context) {
          final authModel = context.watch<AuthModel>(); // Watch AuthModel for changes
          final themeManager = context.watch<ThemeManager>(); // will incorporate for future dark mode implementation
          final appRouter = AppRouter(authModel); // Create AppRouter instance with AuthModel

          return MaterialApp.router(
            title: 'CateredToYou', // Set the title of the app
            debugShowCheckedModeBanner: false, // Disable debug banner
            // Inline light theme configuration (color-wise)
            theme: ThemeData(
              useMaterial3: true,
              // Define a custom ColorScheme
              colorScheme: const ColorScheme(
                brightness: Brightness.light,
                primary: Color(0xFFFFC30B),  // Using Honey Yellow as primary 
                onPrimary: Colors.white,
                secondary: Color(0xFFFFC30B), // Honey Yellow for secondary as well
                onSecondary: Colors.black,
                error: Colors.red,
                onError: Colors.white,
                surface: Color(0xFFFFFFFF),   // Pure white
                onSurface: Colors.black87,
              ),
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFFFC30B), // Honey Yellow for AppBar
                foregroundColor: Colors.white,
                elevation: 4,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC30B), // Honey Yellow button background
                  foregroundColor: Colors.black, // Button text color
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
                  borderSide: const BorderSide(color: Color(0xFFFFC30B)), // Honey Yellow
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
            
            
            // Dark theme setup, will work on implementation again.
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
            // use the current theme mode (right here its forced to light; but we can adjust as needed)
            themeMode: ThemeMode.light,  // theme mode (lightweight unlike before)
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
