import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:cateredtoyou/services/task_automation_service.dart';
import 'package:cateredtoyou/services/task_service.dart';
import 'package:flutter/material.dart'; // Import Flutter material package for UI components
import 'package:provider/provider.dart'; // Import provider package for state management
import 'package:cateredtoyou/models/auth_model.dart'; // Import AuthModel for authentication state
import 'package:cateredtoyou/routes/app_router.dart'; // Import AppRouter for navigation
import 'package:cateredtoyou/services/firebase_service.dart'; // Import FirebaseService for Firebase initialization
import 'package:cateredtoyou/services/organization_service.dart'; // Import OrganizationService for organization-related operations
import 'package:cateredtoyou/services/staff_service.dart'; // Import StaffService for staff-related operations
import 'package:cateredtoyou/services/role_permissions.dart'; // Import RolePermissions for role-based permissions
import 'package:cateredtoyou/services/inventory_service.dart'; // Import InventoryService for inventory-related operations
import 'package:cateredtoyou/services/customer_service.dart'; // Import CustomerService for customer-related operations

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensure Flutter binding is initialized before running the app
  await FirebaseService.initialize(); // Initialize Firebase services
  runApp(const MyApp()); // Run the MyApp widget
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor for MyApp

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Organization service should be first as other services depend on it
        ChangeNotifierProvider(
          create: (_) =>
              OrganizationService(), // Provide OrganizationService instance
        ),

        // Staff service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => StaffService(
            context.read<
                OrganizationService>(), // Provide StaffService instance with OrganizationService dependency
          ),
        ),

        // Inventory service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => InventoryService(
            context.read<
                OrganizationService>(), // Provide InventoryService instance with OrganizationService dependency
          ),
        ),

        ChangeNotifierProvider(
          create: (_) => RolePermissions(), // Provide RolePermissions instance
        ),

        // Auth model should be last as it might depend on other services
        ChangeNotifierProvider(
          create: (_) => AuthModel(), // Provide AuthModel instance
        ),

        /// Event service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => EventService(
            // Provide EventService instance with OrganizationService dependency
            context.read<OrganizationService>(),
          ),
        ),
        /// Menu item service depends on OrganizationService
        ChangeNotifierProvider( // Provide MenuItemService instance
          create: (context) => MenuItemService( // Create MenuItemService instance
            context.read<OrganizationService>(), // Provide OrganizationService dependency
          ),
        ),

        /// Customer service depends on OrganizationService
         ChangeNotifierProvider( // Provide CustomerService instance
          create: (context) => CustomerService( // Create CustomerService instance
            context.read<OrganizationService>(), // Provide OrganizationService dependency
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => TaskService( // Provide TaskService instance
            context.read<OrganizationService>(), // Provide OrganizationService dependency
            
          ),
        ),
        Provider(
      create: (context) => TaskAutomationService(
        context.read<TaskService>(),
      ),
    ),
      ],
      child: Builder(
        builder: (context) {
          final authModel =
              context.watch<AuthModel>(); // Watch AuthModel for changes
          final appRouter =
              AppRouter(authModel); // Create AppRouter instance with AuthModel

          return MaterialApp.router(
            title: 'CateredToYou', // Set the title of the app
            debugShowCheckedModeBanner: false, // Disable debug banner
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue, // Set primary color to blue
                brightness: Brightness.light, // Set brightness to light mode
              ),
              useMaterial3: true, // Use Material 3 design
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                      8), // Set border radius for input fields
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ), // Set padding for input fields
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                      48), // Set minimum height for buttons
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        8), // Set border radius for buttons
                  ),
                ),
              ),
              cardTheme: CardTheme(
                elevation: 2, // Set elevation for cards
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12), // Set border radius for cards
                ),
                margin: const EdgeInsets.symmetric(
                    vertical: 8), // Set margin for cards
              ),
              listTileTheme: const ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ), // Set padding for list tiles
              ),
            ),
            routerConfig: appRouter.router, // Set router configuration
          );
        },
      ),
    );
  }
}
