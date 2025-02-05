import 'package:cateredtoyou/models/customer_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {

  String _searchQuery = '';
  final _searchController =
  TextEditingController(); // Controller for the search input field.

  @override
  void dispose() {
    _searchController
        .dispose(); // Disposes the controller when the widget is removed from the widget tree.
    super.dispose();
  }

  /// Filters the customers list based on the search query.
  List<CustomerModel> _filterCustomer(List<CustomerModel> customerList) {
    if (_searchQuery.isEmpty) {
      return customerList; // If search query is empty, return the full list.
    }

    return customerList.where((customer) {
      final searchLower = _searchQuery.toLowerCase(); // Convert search query to lowercase.
      final phoneNumber = customer.phoneNumber?.replaceAll(RegExp(r'\D'), '') ?? '';

      return customer.fullName.toLowerCase().contains(searchLower) || // Check if full name contains search query.
          customer.email.toLowerCase().contains(searchLower) || // Check if email contains search query.
          phoneNumber.contains(searchLower); // Check if role contains search query.
    }).toList();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.push('/home'),
        ),
        title: Text('Customer View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add_customer'),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
            ),
          )
        ],
      ),
    );
  }
}
