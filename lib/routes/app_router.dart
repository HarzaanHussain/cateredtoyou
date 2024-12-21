import 'package:cateredtoyou/models/user.dart';
import 'package:cateredtoyou/views/staff/add_staff_screen.dart';
import 'package:cateredtoyou/views/staff/edit_staff_screen.dart';
import 'package:cateredtoyou/views/staff/staff_list_screen.dart';
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:go_router/go_router.dart'; // Importing GoRouter package for routing
import 'package:cateredtoyou/models/auth_model.dart'; // Importing AuthModel for authentication state
import 'package:cateredtoyou/views/auth/login_screen.dart'; // Importing LoginScreen widget
import 'package:cateredtoyou/views/auth/register_screen.dart'; // Importing RegisterScreen widget
import 'package:cateredtoyou/views/home/home_screen.dart'; // Importing HomeScreen widget

class AppRouter {
  // Defining AppRouter class
  final AuthModel authModel; // Declaring a final variable for AuthModel

  AppRouter(this.authModel); // Constructor to initialize authModel

  late final GoRouter router = GoRouter(
    // Initializing GoRouter instance
    refreshListenable:
        authModel, // Listening to changes in authModel for refreshing routes
    debugLogDiagnostics: true, // Enabling debug logs for diagnostics
    initialLocation: '/login', // Setting initial route to '/login'
    routes: [
      // Defining routes
      GoRoute(
        // Defining route for login
        path: '/login', // Path for login route
        name: 'login', // Name for login route
        builder: (context, state) =>
            const LoginScreen(), // Building LoginScreen widget
        redirect: (context, state) {
          // Redirect logic for login route
          if (authModel.isAuthenticated) {
            // If user is authenticated
            return '/home'; // Redirect to home
          }
          return null; // No redirection if not authenticated
        },
      ),
      GoRoute(
        // Defining route for register
        path: '/register', // Path for register route
        name: 'register', // Name for register route
        builder: (context, state) =>
            const RegisterScreen(), // Building RegisterScreen widget
        redirect: (context, state) {
          // Redirect logic for register route
          if (authModel.isAuthenticated) {
            // If user is authenticated
            return '/home'; // Redirect to home
          }
          return null; // No redirection if not authenticated
        },
      ),
      GoRoute(
        // Defining route for home
        path: '/home', // Path for home route
        name: 'home', // Name for home route
        builder: (context, state) =>
            const HomeScreen(), // Building HomeScreen widget
        redirect: (context, state) {
          // Redirect logic for home route
          if (!authModel.isAuthenticated) {
            // If user is not authenticated
            return '/login'; // Redirect to login
          }
          return null; // No redirection if authenticated
        },
      ),
       GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffListScreen(),
      ),
      GoRoute(
        path: '/add-staff',
        builder: (context, state) => const AddStaffScreen(),
      ),
      GoRoute(
        path: '/edit-staff',
        builder: (context, state) {
          final staff = state.extra as UserModel;
          return EditStaffScreen(staff: staff);
        },
      ),
    ],

    errorBuilder: (context, state) => Material(
      // Error handling for routes
      child: Center(
        // Centering the error message
        child: Text('Error: ${state.error}'), // Displaying error message
      ),
    ),
  );
}
