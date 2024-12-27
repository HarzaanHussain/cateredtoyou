# CateredToYou - Catering Management System

A comprehensive Flutter-based catering management system with real-time event planning, inventory tracking, task management, and staff management capabilities.

## Features
## Core Features

## Authentication & Authorization

Role-based access control (RBAC) with granular permissions
User authentication with Firebase Auth
Organization-based data isolation
Multi-role support: Admin, Client, Manager, Chef, Server, Staff, Driver


## Event Management

Event creation and lifecycle management
Real-time status updates and tracking
Staff assignment and scheduling
Menu planning and resource allocation
Guest count and requirements tracking
Event metadata for special requirements


## Task Management

Automated task generation based on events
Task assignment and reassignment
Priority levels and due dates
Progress tracking with checklists
Task status lifecycle management
Task comments and collaboration
Department-based task organization


## Inventory Management

Real-time inventory tracking
Low stock alerts
Transaction history
Category-based organization
Units and quantities management
Reorder point monitoring


## Staff Management

Staff profiles and roles
Employment status tracking
Department assignments
Staff availability management
Permission management
Password reset functionality


## Menu Management

Menu item creation and management
Price tracking
Inventory requirements tracking
Menu categorization
Dietary restrictions support



## Task Automation System
The system includes a sophisticated task automation engine that:

## Event-Based Tasks

Automatically generates tasks based on event requirements
Creates timeline-based task sequences
Assigns tasks to appropriate staff members
Sets priorities and due dates


## Task Categories

Planning tasks
Setup tasks
Service tasks
Cleanup tasks
Inventory management tasks


## Special Requirements Handling

Dietary requirement tasks
Equipment setup tasks
Bar service tasks
Large event coordination tasks



## Technical Architecture
## State Management

Provider pattern for app-wide state management
ChangeNotifier for reactive updates
Stream-based real-time updates

## Data Layer

Firebase Firestore for data storage
Real-time data synchronization
Batch operations for transactional integrity
Collection-based data organization

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

lib/
├── models/                 # Data Models
│   ├── auth_model.dart    # Authentication state
│   ├── event_model.dart   # Event data structure
│   ├── task_model.dart    # Task data structure
│   ├── inventory_model.dart
│   ├── menu_model.dart
│   └── user_model.dart
│
├── services/              # Business Logic
│   ├── auth_service.dart
│   ├── event_service.dart
│   ├── task_service.dart
│   ├── task_automation_service.dart
│   ├── inventory_service.dart
│   ├── menu_service.dart
│   └── staff_service.dart
│
├── views/                # UI Screens
│   ├── auth/
│   ├── events/
│   ├── tasks/
│   ├── inventory/
│   └── staff/
│
└── routes/              # Navigation
    └── app_router.dart

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


 

## Security and Permissions
## Role-Based Access Control

Admin: Full system access
Client: Organization management
Manager: Event and staff management
Chef: Kitchen and inventory management
Staff: Basic access to assigned tasks
Server: Event execution access
Driver: Delivery management

## Data Isolation

Organization-level data separation
Role-based data access
Secure customer information
Audit logging

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