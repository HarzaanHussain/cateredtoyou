# CateredToYou - Catering Management System

A comprehensive Flutter-based catering management system with real-time event planning, inventory tracking, and staff management capabilities.

## Features

### Core Features
- Authentication & Authorization
  - Role-based access control (RBAC)
  - User authentication with Firebase Auth
  - Permission management for different roles
  - Secure data access based on organization

- Event Management
  - Create, edit, and manage catering events
  - Real-time status updates
  - Staff assignment and tracking
  - Automated workflow management
  - Resource allocation
  - Guest count tracking
  - Menu and supply management

- Inventory Management
  - Real-time inventory tracking
  - Low stock alerts
  - Automatic inventory adjustments
  - Supply reordering suggestions
  - Transaction history
  - Category-based organization

- Staff Management
  - Staff profiles and roles
  - Shift scheduling
  - Performance tracking
  - Staff assignment to events
  - Status monitoring

- Menu Management
  - Menu item creation and management
  - Price tracking
  - Recipe and ingredient management
  - Menu categorization
  - Inventory requirements tracking

### Automated Tasks
When creating an event, the system automatically:
1. Validates inventory availability
2. Reserves required supplies
3. Creates inventory transactions
4. Sends notifications for:
   - Low stock alerts
   - Staff assignments
   - Event status changes
   - Upcoming events
5. Updates inventory levels
6. Creates audit logs for all operations

## Technical Architecture

### State Management
- Provider for app-wide state management
- ChangeNotifier for reactive updates
- Stream-based real-time updates

### Data Layer
- Firebase Firestore for data storage
- Real-time data synchronization
- Batch operations for transactional integrity
- Collection-based data organization

### Firebase Collections Structure
 
/users
  ├── uid
  │   ├── profile info
  │   └── permissions
/organizations
  ├── orgId
  │   ├── details
  │   └── settings
/events
  ├── eventId
  │   ├── details
  │   ├── menu
  │   └── supplies
/inventory
  ├── itemId
  │   ├── details
  │   └── transactions
/menu_items
  └── itemId
      └── details
 

## Project Structure

 plaintext
lib/
├── models/                    # Data Models
│   ├── auth_model.dart       # Authentication state
│   ├── event_model.dart      # Event data structure
│   ├── inventory_model.dart  # Inventory management
│   ├── menu_model.dart       # Menu item structure
│   └── user_model.dart       # User profile data

├── services/                  # Business Logic
│   ├── auth_service.dart     # Authentication
│   ├── event_service.dart    # Event operations
│   ├── inventory_service.dart # Inventory management
│   ├── menu_service.dart     # Menu operations
│   └── staff_service.dart    # Staff management

├── views/                    # UI Screens
│   ├── auth/                # Authentication screens
│   ├── events/             # Event management
│   ├── inventory/          # Inventory management
│   └── staff/              # Staff management

└── widgets/                 # Reusable Components
    ├── custom_button.dart
    └── custom_text_field.dart
 

## Setup and Installation

### Prerequisites
- Flutter SDK (3.5.3 or higher)
- Firebase project
- Dart SDK (3.0.0 or higher)

### Installation Steps

1. Clone the repository:
   
git clone https://github.com/HarzaanHussain/cateredtoyou.git
cd cateredtoyou
 

2. Install dependencies:
   
flutter pub get
 

3. Configure Firebase:
   - Create a new Firebase project
   - Add your Firebase configuration files
   - Enable Authentication and Firestore

4. Run the application:
   
flutter run
 

## Configuration

### Firebase Setup
1. Create a new Firebase project
2. Enable Email/Password authentication
3. Set up Firestore with appropriate rules
4. Add your `google-services.json` and `firebase_options.dart`

### Environment Variables
Create a `.env` file with:
 
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
 

## Security and Permissions

### Role-Based Access Control
- Admin: Full system access
- Client: Organization management
- Manager: Event and staff management
- Chef: Kitchen and inventory
- Server: Event execution
- Driver: Delivery management

### Data Isolation
- Organization-level data separation
- Role-based data access
- Secure customer information
- Audit logging

## Contributing

1. Fork the repository
2. Create your feature branch:
   
git checkout -b feature/your-feature
 
3. Commit your changes:
   
git commit -m 'Add some feature'
 
4. Push to the branch:
   
git push origin feature/your-feature
 
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for the backend infrastructure
- Contributors and users of the application