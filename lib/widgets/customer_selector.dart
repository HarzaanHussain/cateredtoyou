
import 'package:flutter/material.dart'; // Importing Flutter material package for UI components.
import 'package:provider/provider.dart'; // Importing Provider package for state management.
import 'package:cateredtoyou/models/customer_model.dart'; // Importing CustomerModel class.
import 'package:cateredtoyou/services/customer_service.dart'; // Importing CustomerService class for fetching customers.

/// A widget that allows the user to select a customer from a dropdown list or add a new customer.
class CustomerSelector extends StatelessWidget {
  final String? selectedCustomerId; // The ID of the currently selected customer.
  final Function(String) onCustomerSelected; // Callback function when a customer is selected.
  final VoidCallback onAddNewCustomer; // Callback function when the add new customer button is pressed.

  /// Constructor for CustomerSelector.
  const CustomerSelector({
    super.key, // Key for the widget.
    this.selectedCustomerId, // Optional selected customer ID.
    required this.onCustomerSelected, // Required callback for customer selection.
    required this.onAddNewCustomer, // Required callback for adding a new customer.
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start of the column.
      children: [
        StreamBuilder<List<CustomerModel>>( // StreamBuilder to listen to the stream of customers.
          stream: context.read<CustomerService>().getCustomers(), // Fetching customers from CustomerService.
          builder: (context, snapshot) {
            if (snapshot.hasError) { // Check if there is an error in the snapshot.
              return const Text('Error loading customers'); // Display error message.
            }

            if (snapshot.connectionState == ConnectionState.waiting) { // Check if the connection is still waiting.
              return const CircularProgressIndicator(); // Display loading indicator.
            }

            final customers = snapshot.data ?? []; // Get the list of customers or an empty list if null.

            return InputDecorator(
              decoration: InputDecoration(
                labelText: 'Customer', // Label for the dropdown.
                border: const OutlineInputBorder(), // Outline border for the dropdown.
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add), // Icon for adding a new customer.
                  onPressed: onAddNewCustomer, // Callback for adding a new customer.
                  tooltip: 'Add New Customer', // Tooltip for the add button.
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCustomerId, // Currently selected customer ID.
                  isExpanded: true, // Expand the dropdown to fill available space.
                  hint: const Text('Select Customer'), // Hint text when no customer is selected.
                  items: customers.map((customer) { // Map each customer to a DropdownMenuItem.
                    return DropdownMenuItem(
                      value: customer.id, // Customer ID as the value.
                      child: Text(
                        '${customer.fullName} (${customer.email})', // Display customer's full name and email.
                        overflow: TextOverflow.ellipsis, // Handle overflow with ellipsis.
                      ),
                    );
                  }).toList(),
                  onChanged: (value) { // Callback when a new customer is selected.
                    if (value != null) {
                      onCustomerSelected(value); // Call the onCustomerSelected callback with the selected customer ID.
                    }
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}