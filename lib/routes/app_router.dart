import 'package:cateredtoyou/models/event_model.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/models/user_model.dart'; // Importing User model
import 'package:cateredtoyou/views/events/event_details_screen.dart';
import 'package:cateredtoyou/views/events/event_edit_screen.dart';
import 'package:cateredtoyou/views/events/event_list_screen.dart';
import 'package:cateredtoyou/views/inventory/inventory_edit_screen.dart'; // Importing InventoryEditScreen widget
import 'package:cateredtoyou/views/inventory/inventory_list_screen.dart'; // Importing InventoryListScreen widget
import 'package:cateredtoyou/views/menu_item/menu_item_edit_screen.dart';
import 'package:cateredtoyou/views/menu_item/menu_item_list_screen.dart';
import 'package:cateredtoyou/views/staff/add_staff_screen.dart'; // Importing AddStaffScreen widget
import 'package:cateredtoyou/views/staff/edit_staff_screen.dart'; // Importing EditStaffScreen widget
import 'package:cateredtoyou/views/staff/staff_list_screen.dart'; // Importing StaffListScreen widget
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:go_router/go_router.dart'; // Importing GoRouter package for routing
import 'package:cateredtoyou/models/auth_model.dart'; // Importing AuthModel for authentication state
import 'package:cateredtoyou/views/auth/login_screen.dart'; // Importing LoginScreen widget
import 'package:cateredtoyou/views/auth/register_screen.dart'; // Importing RegisterScreen widget
import 'package:cateredtoyou/views/home/home_screen.dart'; // Importing HomeScreen widget

class AppRouter {
  final AuthModel authModel; // Declaring a final variable for AuthModel

  AppRouter(this.authModel); // Constructor to initialize authModel

  late final GoRouter router = GoRouter(
    refreshListenable:
        authModel, // Listening to changes in authModel for refreshing routes
    debugLogDiagnostics: true, // Enabling debug logs for diagnostics
    initialLocation: '/login', // Setting initial route to '/login'
    routes: [
      GoRoute(
        path: '/login', // Path for login route
        name: 'login', // Name for login route
        builder: (context, state) =>
            const LoginScreen(), // Building LoginScreen widget
        redirect: (context, state) {
          if (authModel.isAuthenticated) {
            // If user is authenticated
            return '/home'; // Redirect to home
          }
          return null; // No redirection if not authenticated
        },
      ),
      GoRoute(
        path: '/register', // Path for register route
        name: 'register', // Name for register route
        builder: (context, state) =>
            const RegisterScreen(), // Building RegisterScreen widget
        redirect: (context, state) {
          if (authModel.isAuthenticated) {
            // If user is authenticated
            return '/home'; // Redirect to home
          }
          return null; // No redirection if not authenticated
        },
      ),
      GoRoute(
        path: '/home', // Path for home route
        name: 'home', // Name for home route
        builder: (context, state) =>
            const HomeScreen(), // Building HomeScreen widget
        redirect: (context, state) {
          if (!authModel.isAuthenticated) {
            // If user is not authenticated
            return '/login'; // Redirect to login
          }
          return null; // No redirection if authenticated
        },
      ),
      GoRoute(
        path: '/staff', // Path for staff list route
        builder: (context, state) =>
            const StaffListScreen(), // Building StaffListScreen widget
      ),
      GoRoute(
        path: '/add-staff', // Path for add staff route
        builder: (context, state) =>
            const AddStaffScreen(), // Building AddStaffScreen widget
      ),
      GoRoute(
        path: '/edit-staff', // Path for edit staff route
        builder: (context, state) {
          final staff =
              state.extra as UserModel; // Extracting UserModel from state
          return EditStaffScreen(
              staff: staff); // Building EditStaffScreen widget with staff data
        },
      ),
      GoRoute(
        path: '/inventory', // Path for inventory list route
        builder: (context, state) =>
            const InventoryListScreen(), // Building InventoryListScreen widget
      ),
      GoRoute(
        path: '/add-inventory', // Path for add inventory route
        builder: (context, state) =>
            const InventoryEditScreen(), // Building InventoryEditScreen widget
      ),
      GoRoute(
        path: '/edit-inventory', // Path for edit inventory route
        builder: (context, state) {
          final item = state.extra
              as InventoryItem; // Extracting InventoryItem from state
          return InventoryEditScreen(
              item: item); // Building InventoryEditScreen widget with item data
        },
      ),
      GoRoute(
        path: '/events', // Path for event list route
        builder: (context, state) =>
            const EventListScreen(), // Building EventListScreen widget
        redirect: (context, state) {
          if (!authModel.isAuthenticated) {
            // If user is not authenticated
            return '/login'; // Redirect to login
          }
          return null; // No redirection if authenticated
        },
      ),
      GoRoute(
        path: '/add-event', // Path for add event route
        builder: (context, state) =>
            const EventEditScreen(), // Building EventEditScreen widget
        redirect: (context, state) {
          if (!authModel.isAuthenticated) {
            // If user is not authenticated
            return '/login'; // Redirect to login
          }
          return null; // No redirection if authenticated
        },
      ),
      GoRoute(
        path: '/edit-event', // Path for edit event route
        builder: (context, state) {
          final event = state.extra as Event; // Extracting Event from state
          return EventEditScreen(
              event: event); // Building EventEditScreen widget with event data
        },
        redirect: (context, state) {
          if (!authModel.isAuthenticated) {
            // If user is not authenticated
            return '/login'; // Redirect to login
          }
          return null; // No redirection if authenticated
        },
      ),
      GoRoute(
        path: '/event-details', // Path for event details route
        builder: (context, state) {
          final event = state.extra as Event; // Extracting Event from state
          return EventDetailsScreen(
              event:
                  event); // Building EventDetailsScreen widget with event data
        },
        redirect: (context, state) {
          if (!authModel.isAuthenticated) {
            // If user is not authenticated
            return '/login'; // Redirect to login
          }
          return null; // No redirection if authenticated
        },
      ),
      GoRoute(
        path: '/menu-items', // Path for menu items list route
        builder: (context, state) => const MenuItemListScreen(), // Building MenuItemListScreen widget
      ),
      GoRoute(
        path: '/add-menu-item', // Path for add menu item route
        builder: (context, state) => const MenuItemEditScreen(), // Building MenuItemEditScreen widget
      ),
      GoRoute(
        path: '/edit-menu-item', // Path for edit menu item route
        builder: (context, state) {
          final menuItem = state.extra as MenuItem; // Extracting MenuItem from state
          return MenuItemEditScreen(menuItem: menuItem); // Building MenuItemEditScreen widget with menuItem data
        },
      ),
    ],
    errorBuilder: (context, state) => Material(
      child: Center(
        child: Text('Error: ${state.error}'), // Displaying error message
      ),
    ),
  );
}
