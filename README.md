# CateredToYou - Staff and Inventory Management System

A Flutter application for managing staff, inventory, and catering operations with role-based access control and real-time data synchronization.

## Project Overview

CateredToYou is a comprehensive management system that allows catering businesses to:
- Manage staff members with different roles and permissions
- Track inventory items and stock levels
- Handle role-based access control
- Manage organizations and multi-tenant data isolation

### Core Features

- **Authentication & Authorization**
  - User registration and login
  - Role-based access control (Admin, Client, Manager, Chef, Server, Driver)
  - Organization-based data isolation

- **Staff Management**
  - Add/Edit staff members
  - Assign roles and permissions
  - Manage employment status
  - Password reset functionality

- **Inventory Management**
  - Track inventory items
  - Monitor stock levels
  - Handle reorder points
  - Record inventory transactions

## Project Structure

 
lib/
├── models/                 # Data Models
│   ├── user.dart          # User data model with roles and permissions
│   ├── auth_model.dart    # Authentication state management
│   ├── inventory_item_model.dart  # Inventory item model
│   └── organization.dart   # Organization model
│
├── services/              # Business Logic Layer
│   ├── auth_service.dart       # Authentication operations
│   ├── firebase_service.dart   # Firebase initialization and config
│   ├── inventory_service.dart  # Inventory management
│   ├── organization_service.dart # Organization management
│   ├── role_permissions.dart   # Permission management
│   └── staff_service.dart      # Staff management
│
├── views/                 # UI Screens
│   ├── auth/
│   │   ├── login_screen.dart    # User login
│   │   └── register_screen.dart # User registration
│   ├── inventory/
│   │   ├── inventory_list_screen.dart  # Inventory listing
│   │   └── inventory_edit_screen.dart  # Add/Edit inventory
│   ├── staff/
│   │   ├── staff_list_screen.dart     # Staff listing
│   │   ├── add_staff_screen.dart      # Add new staff
│   │   └── edit_staff_screen.dart     # Edit staff details
│   └── home/
│       └── home_screen.dart           # Main dashboard
│
├── widgets/              # Reusable Components
│   ├── bottom_nav_bar.dart   # Bottom navigation
│   ├── custom_button.dart    # Styled buttons
│   ├── custom_text_field.dart # Form inputs
│   └── permission_widget.dart # Permission-based rendering
│
└── utils/               # Utilities
    └── validators.dart  # Form validation rules

 

## Technical Architecture

### Authentication Flow
1. Users can register as clients or staff members
2. Authentication state is managed using Firebase Auth
3. User roles and permissions are stored in Firestore
4. Organization-based data isolation is enforced

### Data Model
1. **Users Collection**
   - uid: string
   - email: string
   - firstName: string
   - lastName: string
   - role: string
   - organizationId: string
   - employmentStatus: string
   - createdAt: timestamp
   - updatedAt: timestamp

2. **Permissions Collection**
   - uid: string (matches user)
   - role: string
   - permissions: array
   - organizationId: string

3. **Inventory Collection**
   - id: string
   - name: string
   - category: enum
   - quantity: number
   - reorderPoint: number
   - organizationId: string

### Security Rules
The application implements comprehensive security rules for data access:
- Organization-based isolation
- Role-based access control
- Validation of inventory operations
- Protected staff management

## Setup and Configuration

1. **Prerequisites**
   - Flutter SDK
   - Firebase project
   - Firebase CLI

2. **Firebase Setup**
      
   # Initialize Firebase
   flutterfire configure
    

3. **Environment Configuration**
   - Create firebase_options.dart with your Firebase credentials
   - Set up security rules in Firebase Console

4. **Run the Application**
      
   flutter pub get
   flutter run
    

## Role-Based Permissions

1. **Admin**
   - Full system access
   - Manage all staff and inventory
   - View all reports

2. **Client**
   - Manage staff members
   - View inventory
   - Access reports

3. **Manager**
   - Manage assigned staff
   - Handle inventory
   - View reports

4. **Staff** (Chef, Server, Driver)
   - View assigned tasks
   - Update inventory (role-specific)
   - View relevant information

## Future Enhancements

1. **Planned Features**
   - Event management system
   - Task assignment and tracking
   - Automated inventory alerts
   - Advanced reporting

2. **Technical Improvements**
   - Implement caching for offline support
   - Add real-time notifications
   - Enhanced security measures
   - Performance optimization

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is proprietary and confidential. All rights reserved.