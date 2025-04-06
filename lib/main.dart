// import dart:async for timer and asynchronous operations
import 'dart:async';

// import our custom services and packages
import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart'; // handles delivery route operations
import 'package:cateredtoyou/services/event_service.dart'; // manages event operations
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

// main function to initialize app and run it
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
  const MyApp({super.key}); // constructor

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      // provide all necessary services to the widget tree
      providers: [
        ChangeNotifierProvider(create: (_) => OrganizationService()),
        Provider<AuthService>(create: (_) => AuthService()),
        // staff service depends on organization service
        ChangeNotifierProvider(
          create: (context) => StaffService(context.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => ManifestService(context.read<OrganizationService>()),
        ),
        // inventory service depends on organization service
        ChangeNotifierProvider(
          create: (context) => InventoryService(context.read<OrganizationService>()),
        ),
        // vehicle service depends on organization service
        ChangeNotifierProvider(
          create: (context) => VehicleService(context.read<OrganizationService>()),
        ),
        // delivery route service depends on organization service
        ChangeNotifierProvider(
          create: (context) => DeliveryRouteService(context.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(create: (_) => RolePermissions()),
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
          create: (context) => MenuItemService(context.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => CustomerService(context.read<OrganizationService>()),
        ),
        // add theme manager so dark mode toggle works
        ChangeNotifierProvider(create: (_) => ThemeManager()),
      ],
      child: Builder(builder: (context) {
        // get auth model from provider
        final authModel = context.watch<AuthModel>();
        // get theme manager to control dark/light mode
        final themeManager = context.watch<ThemeManager>();
        // create app router for navigation
        final appRouter = AppRouter(authModel);

        return MaterialApp.router(
          title: 'cateredtouyou', // app title
          debugShowCheckedModeBanner: false, // hide debug banner
          
          
          
          
          // light theme
          theme: ThemeData(
            useMaterial3: true,
            // custom color scheme for light theme
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
            scaffoldBackgroundColor: Colors.white, // background is white
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFFC30B), // appbar uses honey yellow
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC30B), // button background is honey yellow
                foregroundColor: Colors.black, // text color for button
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white, // input field fill is white
              border: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFBDC3C7)),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFFFFC30B)),
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
            // tabbar theme to ensure tab text is visible on yellow background
            tabBarTheme: const TabBarTheme(
              labelColor: Color(0xFF2C3E50), // dark text for selected tabs
              unselectedLabelColor: Color.fromARGB(255, 253, 253, 253), // light text for unselected tabs
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: Color(0xFF2C3E50), width: 2),
              ),
            ),
          ),


          
          // dark theme configuration
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
              bodyMedium: TextStyle(fontSize: 14, color: Color.fromARGB(153, 0, 0, 0)),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color>(
                (states) => Colors.white,
              ),
              trackColor: WidgetStateProperty.all(const Color(0xFFCBA135)),
              overlayColor: WidgetStateProperty.all(const Color(0xFFCBA135)),
            ),
          ),
          // use theme manager to switch themes based on toggle in settings
          themeMode: themeManager.themeMode,
          routerConfig: appRouter.router,
        );
      }),
    );
  }
}
