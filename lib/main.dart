// 🌟 main.dart – with switchable “Honey Yellow” & “Royal Blue” themes
// ───────────────────────────────────────────────────────────────────


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// local packages
import 'package:cateredtoyou/models/auth_model.dart';
import 'package:cateredtoyou/routes/app_router.dart';
import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/notification_service.dart';
import 'package:cateredtoyou/services/firebase_service.dart';
import 'package:cateredtoyou/services/organization_service.dart';
import 'package:cateredtoyou/services/role_permissions.dart';
import 'package:cateredtoyou/services/staff_service.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/inventory_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/services/delivery_route_service.dart';
import 'package:cateredtoyou/services/location_service.dart';
import 'package:cateredtoyou/services/task_service.dart';
import 'package:cateredtoyou/services/task_automation_service.dart';
import 'package:cateredtoyou/services/event_service.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';
import 'package:cateredtoyou/services/customer_service.dart';
import 'package:cateredtoyou/services/theme_manager.dart';   // ← single source of truth
import 'package:cateredtoyou/widgets/themed_app_bar.dart';

// ─── secondary Firebase init (unchanged) ───────────────────────────
class FirebaseSecondary {
  static late FirebaseApp secondaryApp;
  static late FirebaseAuth secondaryAuth;

  static Future<void> initializeSecondary() async {
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondary',
        options: Firebase.app().options,
      );
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    } catch (_) {
      secondaryApp = Firebase.app('secondary');
      secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    }
  }
}

// ─── recurring-notification timer ──────────────────────────────────
void setupRecurringNotificationsCheck() {
  NotificationService().processRecurringNotifications();
  Timer.periodic(const Duration(hours: 1),
      (_) => NotificationService().processRecurringNotifications());
}

// ─── entry point ───────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await FirebaseSecondary.initializeSecondary();
  await NotificationService().initNotification();
  setupRecurringNotificationsCheck();                       // ← start timer
  runApp(const MyApp());
}

// ─── 🎨  theme presets ─────────────────────────────────────────────
final ThemeData honeyYellowTheme = ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFFFC30B),
    onPrimary: Colors.white,
    secondary: Color(0xFFFFC30B),
    onSecondary: Colors.black,
    error: Colors.red,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black87,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFFFC30B),
    foregroundColor: Colors.white,
    elevation: 4,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFFFC30B),
      foregroundColor: Colors.black,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  inputDecorationTheme: _honeyInputDecoration,
  cardTheme: _defaultCardTheme,
  
);
final ThemeData royalBlueTheme = ThemeData(
  useMaterial3: true,

  // ── Core palette ───────────────────────────────────────
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1565C0),
    brightness: Brightness.light,
  ),

  // airy page background
  scaffoldBackgroundColor: const Color(0xFFF7F9FC),

  // gradient header is supplied by GradientAppBar, so keep transparent here
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
  ),

 inputDecorationTheme: _royalInputDecoration,
  // nav bar matches palette
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1565C0),
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.white70,
    selectedIconTheme: IconThemeData(size: 26),
    unselectedIconTheme: IconThemeData(size: 22),
    type: BottomNavigationBarType.fixed,
  ),

  // cards hover above the pale background nicely
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 3,
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    shadowColor: Colors.black.withOpacity(.06),
  ),

  // list tiles feel like pills when tapped
  listTileTheme: const ListTileThemeData(
    dense: true,
    shape: StadiumBorder(),
    tileColor: Colors.transparent,
    selectedTileColor: Colors.white24,
    selectedColor: Colors.white,
    horizontalTitleGap: 12,
  ),

  // chips (e.g. task tags) get an outlined royal-blue style
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF1565C0).withOpacity(.08),
    labelStyle: const TextStyle(fontWeight: FontWeight.w500),
    selectedColor: const Color(0xFF1565C0),
    secondarySelectedColor: const Color(0xFF1565C0),
    shape: StadiumBorder(
      side: BorderSide(color: const Color(0xFF1565C0).withOpacity(.4)),
    ),
  ),
);


// shared sub-themes
final _honeyInputDecoration = InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFBDC3C7)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFFFC30B)),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
);

final _royalInputDecoration = InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFF90CAF9)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
  ),
);

final _defaultCardTheme = CardTheme(
  color: Colors.white,
  elevation: 3,
  margin: const EdgeInsets.all(8),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

// ─── app root ───────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // core services
        ChangeNotifierProvider(create: (_) => OrganizationService()),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => RolePermissions()),

        ChangeNotifierProvider(
          create: (ctx) => StaffService(ctx.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ManifestService(ctx.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => InventoryService(ctx.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => VehicleService(ctx.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => DeliveryRouteService(
            ctx.read<OrganizationService>(),
            ctx.read<RolePermissions>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              LocationService(ctx.read<DeliveryRouteService>()),
        ),
        // business logic
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(
          create: (ctx) => TaskService(ctx.read<OrganizationService>()),
        ),
        Provider(
          create: (ctx) => TaskAutomationService(
            ctx.read<TaskService>(),
            ctx.read<OrganizationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => EventService(
            ctx.read<OrganizationService>(),
            ctx.read<TaskAutomationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MenuItemService(ctx.read<OrganizationService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => CustomerService(ctx.read<OrganizationService>()),
        ),
        // theme
        ChangeNotifierProvider(create: (_) => ThemeManager()),
      ],
      child: Builder(
        builder: (context) {
          final authModel = context.watch<AuthModel>();
          final tm        = context.watch<ThemeManager>();
          final router    = AppRouter(authModel);

          return MaterialApp.router(
            title: 'CateredToYou',
            debugShowCheckedModeBanner: false,
            theme: tm.preset == ThemePreset.royalBlue
                ? royalBlueTheme
                : honeyYellowTheme,
            routerConfig: router.router,
          );
        },
      ),
    );
  }
}
