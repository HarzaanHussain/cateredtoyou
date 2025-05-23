// import dart:async for timer and asynchronous operations
import 'dart:async';

// import our custom services and packages
import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart'; // Import DeliveryRouteService for delivery route-related operations
import 'package:cateredtoyou/services/event_service.dart'; // Import EventService for event-related operations
import 'package:cateredtoyou/services/location_service.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/menu_item_service.dart'; // manages menu item operations
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:cateredtoyou/services/task_automation_service.dart'; // handles task automation operations
import 'package:cateredtoyou/services/task_service.dart'; // manages task operations
import 'package:firebase_auth/firebase_auth.dart'; // for firebase authentication
import 'package:firebase_core/firebase_core.dart'; // for firebase initialization
import 'package:flutter/material.dart'; // for flutter ui components
import 'package:provider/provider.dart'; // for state management using provider
import 'package:cateredtoyou/models/auth_model.dart'; // authentication model
import 'package:cateredtoyou/routes/app_router.dart'; // app navigation
import 'package:cateredtoyou/services/firebase_service.dart'; // firebase service initialization
import 'package:cateredtoyou/services/organization_service.dart'; // handles organization operations
import 'package:cateredtoyou/services/staff_service.dart'; // manages staff operations
import 'package:cateredtoyou/services/role_permissions.dart'; // handles role-based permissions
import 'package:cateredtoyou/services/inventory_service.dart'; // manages inventory operations
import 'package:cateredtoyou/services/customer_service.dart'; // handles customer operations
import 'package:cateredtoyou/services/vehicle_service.dart'; // manages vehicle operations
import 'package:cateredtoyou/services/theme_manager.dart'; // provides dark mode toggle

// this class handles secondary firebase app initialization
class FirebaseSecondary {
  static late FirebaseApp secondaryApp; // secondary firebase app instance
  static late FirebaseAuth secondaryAuth; // secondary firebase auth instance

  // initialize the secondary firebase app
  static Future<void> initializeSecondary() async {
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary',
        options: Firebase.app().options,
      );
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    } catch (e) {
      // if already initialized, get the existing instance
      secondaryApp = Firebase.app('secondary');
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    }
  }
}

void setupRecurringNotificationsCheck() {
  NotificationService().processRecurringNotifications();

  // Set up periodic checking of recurring notifications
  Timer.periodic(const Duration(hours: 1), (timer) {
    NotificationService().processRecurringNotifications();
  });
}

void main() async {
  // ensure flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  // initialize firebase services
  await FirebaseService.initialize();
  // initialize secondary firebase app
  await FirebaseSecondary.initializeSecondary();
  // initialize notifications
  await NotificationService().initNotification();

  // run the app widget
  runApp(const MyApp());
}

// main app widget
class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor for MyApp

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // provide all necessary services to the widget tree
      providers: [
        ChangeNotifierProvider(create: (_) => OrganizationService()),
        Provider<AuthService>(create: (_) => AuthService()),
        // Role permissions service
        ChangeNotifierProvider(create: (_) => RolePermissions()),
        // Staff service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) =>
              StaffService(context.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ManifestService(context.read<OrganizationService>()),
        ),
        // inventory service depends on organization service
        ChangeNotifierProvider(
          create: (context) =>
              InventoryService(context.read<OrganizationService>()),
        ),
        // vehicle service depends on organization service
        ChangeNotifierProvider(
          create: (context) =>
              VehicleService(context.read<OrganizationService>()),
        ),
        // Delivery route service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => DeliveryRouteService(
            context.read<OrganizationService>(),
            context.read<RolePermissions>(),
          ),
        ),
        // LocationService depends on DeliveryRouteService, so it must come AFTER
        ChangeNotifierProvider(
          create: (context) => LocationService(
            context.read<DeliveryRouteService>(),
          ),
        ),


        // Auth model should be last as it might depend on other services
        ChangeNotifierProvider(create: (_) => AuthModel()),
        // task service depends on organization service
        ChangeNotifierProvider(
          create: (context) => TaskService(context.read<OrganizationService>()),
        ),
        Provider(
          create: (context) => TaskAutomationService(
            context.read<TaskService>(),
            context.read<OrganizationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => EventService(
            context.read<OrganizationService>(),
            context.read<TaskAutomationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              MenuItemService(context.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CustomerService(context.read<OrganizationService>()),
        ),
        // add theme manager so dark mode toggle works
        ChangeNotifierProvider(create: (_) => ThemeManager()),
      ],
      child: Builder(
        builder: (context) {
          final authModel =
          context.watch<AuthModel>(); // Watch AuthModel for changes
          final appRouter =
          AppRouter(authModel); // Create AppRouter instance with AuthModel

          return MaterialApp.router(
            title: 'CateredToYou',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              // Define a custom ColorScheme
              colorScheme: const ColorScheme(
                brightness: Brightness.light,
                primary: Color(0xFFFFC30B), // honey yellow
                onPrimary: Colors.white,
                secondary: Color(0xFFFFC30B),
                onSecondary: Colors.black,
                error: Colors.red,
                onError: Colors.white,
                surface: Color(0xFFFFFFFF), // pure white
                onSurface: Colors.black87,
              ),
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFFFC30B), // appbar uses honey yellow
                foregroundColor: Colors.white,
                elevation: 4,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFFFFC30B), // honey yellow button background
                  foregroundColor: Colors.black, // Button text color
                  minimumSize: const Size.fromHeight(48),
                  padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
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
                  borderSide: const BorderSide(color: Color(0xFFFFC30B)),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              cardTheme: CardTheme(
                color: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(8),
              ),
              textTheme: TextTheme(
                headlineSmall: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                titleMedium: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                bodyLarge: const TextStyle(fontSize: 16, color: Colors.black87),
                bodyMedium:
                const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: MaterialStateProperty.resolveWith((states) {
                  return states.contains(MaterialState.selected)
                      ? Colors.white     // Thumb when ON
                      : Colors.black;     // Thumb when OFF
                }),
                trackColor: MaterialStateProperty.resolveWith((states) {
                  return states.contains(MaterialState.selected)
                      ? Color(0xFFD4AF37) // Track when ON (gold)
                      : Colors.white;       // Track when OFF
                }),
              ),
            ),
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}