import 'package:cateredtoyou/models/delivery_route_model.dart'; // Importing DeliveryRoute model
import 'package:cateredtoyou/models/event_model.dart'; // Importing Event model
import 'package:cateredtoyou/models/inventory_item_model.dart'; // Importing InventoryItem model
import 'package:cateredtoyou/models/menu_item_model.dart'; // Importing MenuItem model
import 'package:cateredtoyou/models/user_model.dart'; // Importing User model
import 'package:cateredtoyou/models/vehicle_model.dart'; // Importing Vehicle model
import 'package:cateredtoyou/views/customers/add_customer_screen.dart';
import 'package:cateredtoyou/views/customers/customer_list_screen.dart';
import 'package:cateredtoyou/views/customers/edit_customer_screen.dart';
import 'package:cateredtoyou/views/delivery/delivery_form_screen.dart'; // Importing DeliveryFormScreen widget
import 'package:cateredtoyou/views/delivery/delivery_list_screen.dart'; // Importing DeliveryListScreen widget
import 'package:cateredtoyou/views/delivery/driver_deliveries_screen.dart'; // Importing DriverDeliveriesScreen widget
import 'package:cateredtoyou/views/delivery/track_delivery_screen.dart'; // Importing TrackDeliveryScreen widget
import 'package:cateredtoyou/views/events/event_details_screen.dart'; // Importing EventDetailsScreen widget
import 'package:cateredtoyou/views/events/event_edit_screen.dart'; // Importing EventEditScreen widget
import 'package:cateredtoyou/views/events/event_list_screen.dart'; // Importing EventListScreen widget
import 'package:cateredtoyou/views/inventory/inventory_edit_screen.dart'; // Importing InventoryEditScreen widget
import 'package:cateredtoyou/views/inventory/inventory_list_screen.dart'; // Importing InventoryListScreen widget
import 'package:cateredtoyou/views/menu_item/menu_item_edit_screen.dart'; // Importing MenuItemEditScreen widget
import 'package:cateredtoyou/views/menu_item/menu_item_list_screen.dart'; // Importing MenuItemListScreen widget
import 'package:cateredtoyou/views/staff/add_staff_screen.dart'; // Importing AddStaffScreen widget
import 'package:cateredtoyou/views/staff/edit_staff_screen.dart'; // Importing EditStaffScreen widget
import 'package:cateredtoyou/views/staff/staff_list_screen.dart'; // Importing StaffListScreen widget
import 'package:cateredtoyou/views/staff/staff_permission_screen.dart';
import 'package:cateredtoyou/views/tasks/manage_task_screen.dart'; // Importing ManageTasksScreen widget
import 'package:cateredtoyou/views/tasks/task_list_screen.dart'; // Importing TaskListScreen widget
import 'package:cateredtoyou/views/vehicles/vehicle_details_screen.dart'; // Importing VehicleDetailsScreen widget
import 'package:cateredtoyou/views/vehicles/vehicle_form_screen.dart'; // Importing VehicleFormScreen widget
import 'package:cateredtoyou/views/vehicles/vehicle_list_screen.dart'; // Importing VehicleListScreen widget
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:go_router/go_router.dart'; // Importing GoRouter package for routing
import 'package:cateredtoyou/models/auth_model.dart'; // Importing AuthModel for authentication state
import 'package:cateredtoyou/views/auth/login_screen.dart'; // Importing LoginScreen widget
import 'package:cateredtoyou/views/auth/register_screen.dart'; // Importing RegisterScreen widget
import 'package:cateredtoyou/views/home/home_screen.dart';

import '../models/customer_model.dart'; // Importing HomeScreen widget

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
      path: '/customers',
      builder: (context, state) =>
          const CustomerListScreen(),
    ),
      GoRoute(
        path: '/add_customer',
        builder: (context, state) =>
        const AddCustomerScreen(),
      ),
      GoRoute(
        path: '/edit_customer',
        builder: (context, state){
          final customer = state.extra as CustomerModel;
          return EditCustomerScreen(customer: customer);
        },
      ),
    GoRoute(
      path: '/staff/:id/permissions',
      builder: (context, state) {
        final user = state.extra as UserModel; // Extracting UserModel from state
        return UserPermissionsScreen(user: user); // Building UserPermissionsScreen widget with user data
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
        builder: (context, state) =>
            const MenuItemListScreen(), // Building MenuItemListScreen widget
      ),
      GoRoute(
        path: '/add-menu-item', // Path for add menu item route
        builder: (context, state) =>
            const MenuItemEditScreen(), // Building MenuItemEditScreen widget
      ),
      GoRoute(
        path: '/edit-menu-item', // Path for edit menu item route
        builder: (context, state) {
          final menuItem =
              state.extra as MenuItem; // Extracting MenuItem from state
          return MenuItemEditScreen(
              menuItem:
                  menuItem); // Building MenuItemEditScreen widget with menuItem data
        },
      ),
      GoRoute(
        // Route for tasks list
        path: '/tasks',
        builder: (context, state) =>
            const TaskListScreen(), // Building TaskListScreen widget
        redirect: (context, state) {
          // Redirecting to login if not authenticated
          if (!authModel.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
      GoRoute(
        // Route for manage tasks
        path: '/manage-tasks',
        builder: (context, state) =>
            const ManageTasksScreen(), // Building ManageTasksScreen widget
        redirect: (context, state) {
          // Redirecting to login if not authenticated
          if (!authModel.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/vehicles', // Path for vehicle list route
        builder: (context, state) =>
            const VehicleListScreen(), // Building VehicleListScreen widget
      ),
      GoRoute(
        path: '/add-vehicle', // Path for add vehicle route
        builder: (context, state) =>
            const VehicleFormScreen(), // Building VehicleFormScreen widget
      ),
      GoRoute(
        path: '/edit-vehicle', // Path for edit vehicle route
        builder: (context, state) {
          final vehicle = state.extra as Vehicle; // Extracting Vehicle from state
          return VehicleFormScreen(
              vehicle: vehicle); // Building VehicleFormScreen widget with vehicle data
        },
      ),
      GoRoute(
        path: '/vehicle-details', // Path for vehicle details route
        builder: (context, state) {
          final vehicle = state.extra as Vehicle; // Extracting Vehicle from state
          return VehicleDetailsScreen(
              vehicle: vehicle); // Building VehicleDetailsScreen widget with vehicle data
        },
      ),
      GoRoute(
        path: '/track-delivery', // Path for track delivery route
        builder: (context, state) {
          final route = state.extra as DeliveryRoute; // Extracting DeliveryRoute from state
          return TrackDeliveryScreen(
              route: route); // Building TrackDeliveryScreen widget with route data
        },
      ),
      GoRoute(
        path: '/deliveries', // Path for deliveries list route
        builder: (context, state) =>
            const DeliveryListScreen(), // Building DeliveryListScreen widget
      ),
      GoRoute(
        path: '/add-delivery', // Path for add delivery route
        builder: (context, state) =>
            const DeliveryFormScreen(), // Building DeliveryFormScreen widget
      ),
      GoRoute(
        path: '/driver-deliveries', // Path for driver deliveries route
        builder: (context, state) =>
            const DriverDeliveriesScreen(), // Building DriverDeliveriesScreen widget
      ),
    ],
    errorBuilder: (context, state) => Material(
      child: Center(
        child: Text('Error: ${state.error}'), // Displaying error message
      ),
    ),
  );
}
