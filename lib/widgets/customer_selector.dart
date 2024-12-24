import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/customer_model.dart';
import 'package:cateredtoyou/services/customer_service.dart';

class CustomerSelector extends StatelessWidget {
  final String? selectedCustomerId;
  final Function(String) onCustomerSelected;
  final VoidCallback onAddNewCustomer;

  const CustomerSelector({
    super.key,
    this.selectedCustomerId,
    required this.onCustomerSelected,
    required this.onAddNewCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<CustomerModel>>(
          stream: context.read<CustomerService>().getCustomers(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading customers');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final customers = snapshot.data ?? [];

            return InputDecorator(
              decoration: InputDecoration(
                labelText: 'Customer',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onAddNewCustomer,
                  tooltip: 'Add New Customer',
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCustomerId,
                  isExpanded: true,
                  hint: const Text('Select Customer'),
                  items: customers.map((customer) {
                    return DropdownMenuItem(
                      value: customer.id,
                      child: Text(
                        '${customer.fullName} (${customer.email})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onCustomerSelected(value);
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