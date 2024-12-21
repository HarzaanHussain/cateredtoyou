# CateredToYou - Catering Management System

## Overview
CateredToYou is a comprehensive Flutter-based catering management application integrated with Firebase. It provides a robust solution for managing catering operations, including staff management, inventory control, event planning, and task automation.

## Project Structure
```
lib/
├── models/                  # Data models
│   ├── user.dart           # User model
│   ├── auth_model.dart     # Authentication state management
│   └── organization.dart   # Organization model
│
├── routes/                 # Navigation
│   └── app_router.dart     # Centralized routing with GoRouter
│
├── services/              # Business logic & Firebase interactions
│   ├── auth_service.dart   # Authentication service
│   ├── firebase_service.dart # Firebase configuration
│   ├── staff_service.dart   # Staff management
│   ├── organization_service.dart # Organization management
│   └── role_permissions.dart # Permission management
│
├── utils/                 # Utilities
│   ├── constants.dart      # App constants
│   └── validators.dart     # Form validation
│
├── views/                 # UI screens
│   ├── auth/              # Authentication screens
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── staff/            # Staff management
│   │   ├── staff_list_screen.dart
│   │   ├── add_staff_screen.dart
│   │   └── edit_staff_screen.dart
│   └── home/
│       └── home_screen.dart
│
└── widgets/              # Reusable components
    ├── custom_button.dart
    └── custom_text_field.dart
```

## Current Features

### Authentication System
- Email/password authentication
- Role-based access control
- Organization-based data isolation
- Session management
- Secure password handling

### Staff Management
- Staff creation and editing
- Role assignment (Admin, Manager, Chef, Server, Driver)
- Department management
- Status control (Active/Inactive)
- Staff search and filtering
- Permission-based access control

### Organization Management
- Multi-organization support
- Organization-based data isolation
- Organization settings management
- User-organization relationship handling

## Upcoming Features

### 1. Inventory Management (In Development)
- Inventory tracking
- Stock level monitoring
- Automatic reorder alerts
- Usage tracking
- Inventory categories
  - Food items
  - Beverages
  - Equipment
  - Supplies
- Reports and analytics

### 2. Event Management (Planned)
- Event creation and planning
- Client management
- Venue management
- Menu planning
- Staff assignment
- Event timeline creation
- Resource allocation
- Budget tracking
- Client communication tools
- Event status tracking
- Automated task generation

### 3. Task Management (Planned)
- Automated task generation from events
- Task assignment
- Priority management
- Status tracking
- Department-based task routing
- Deadline management
- Task dependencies
- Progress tracking
- Notification system

## Technical Details

### Firebase Integration
- Cloud Firestore for data storage
- Firebase Authentication for user management
- Security rules for data protection
- Real-time data synchronization

### State Management
- Provider for state management
- ChangeNotifier for service states
- StreamBuilder for real-time updates

### Navigation
- GoRouter for routing
- Deep linking support
- Route protection
- Navigation state management

### Security
```javascript
// Security Rules Structure
service cloud.firestore {
  match /databases/{database}/documents {
    // Organization-based access
    match /organizations/{orgId} {
      allow read: if isAuthenticated();
      allow write: if hasManagementRole();
    }

    // User management
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if hasManagementPermissions();
    }

    // Additional collections...
  }
}
```

## Getting Started

### Prerequisites
- Flutter SDK (Latest stable version)
- Firebase CLI
- Node.js & npm
- Git

### Installation
1. Clone the repository:
```bash
git clone https://github.com/yourusername/cateredtoyou.git
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
```bash
flutterfire configure
```

4. Run the app:
```bash
flutter run
```

### Environment Setup
Create a `.env` file with:
```
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_APP_ID=your_app_id
```

## Development Guidelines

### Code Style
- Follow Flutter's style guide
- Use camelCase for variables and methods
- Use PascalCase for classes
- Document public APIs
- Write unit tests for business logic

### State Management
- Use Provider for simple state
- Implement proper error handling
- Follow reactive programming patterns
- Maintain immutable state

### UI/UX Guidelines
- Material Design 3
- Responsive layouts
- Error feedback
- Loading states
- Accessibility support

## Contributing
1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Push to the branch
5. Open a pull request

## License
This project is licensed under the MIT License.