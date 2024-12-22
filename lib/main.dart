// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/routes/app_router.dart';
import 'package:cateredtoyou/services/firebase_service.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/services/inventory_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await FirebaseService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Organization service should be first as other services depend on it
        ChangeNotifierProvider(
          create: (_) => OrganizationService(),
        ),
        
        // Staff service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => StaffService(
            context.read<OrganizationService>(),
          ),
        ),
        
        // Inventory service depends on OrganizationService
        ChangeNotifierProvider(
          create: (context) => InventoryService(
            context.read<OrganizationService>(),
          ),
        ),
        
        ChangeNotifierProvider(
          create: (_) => RolePermissions(),
        ),
        
        // Auth model should be last as it might depend on other services
        ChangeNotifierProvider(
          create: (_) => AuthModel(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authModel = context.watch<AuthModel>();
          final appRouter = AppRouter(authModel);
          
          return MaterialApp.router(
            title: 'CateredToYou',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              cardTheme: CardTheme(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
              listTileTheme: const ListTileThemeData(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}