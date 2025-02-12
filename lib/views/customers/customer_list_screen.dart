import 'package:cateredtoyou/models/customer_model.dart';
import 'package:cateredtoyou/models/user_model.dart';
import 'package:cateredtoyou/services/auth_service.dart';
import 'package:cateredtoyou/services/customer_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
      final phoneNumber = customer.phoneNumber.replaceAll(RegExp(r'\D'), '');

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
              decoration: InputDecoration(
                hintText: 'Search Customer...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)
                ),
                suffixIcon: _searchQuery.isNotEmpty? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ) : null,
              ),
              onChanged: (value){
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<List<CustomerModel>>(
              stream: context.read<CustomerService>().getCustomers(),
              builder: (context, snapshot){
                if(snapshot.hasError){
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                if(snapshot.connectionState == ConnectionState.waiting){
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final allCustomers = snapshot.data ?? [];
                final filteredCustomers = _filterCustomer(allCustomers);

                if(allCustomers.isEmpty){
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No Customers Found',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add_customer'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Customer'),
                        ),
                      ],
                    ),
                  );
                }

                if(filteredCustomers.isEmpty){
                  return const Center(
                    child: Text('No Customers Match Search Criteria'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (context, index){
                    final customer = filteredCustomers[index];
                    return CustomerListItem(customer:customer);
                  },
                );

              },
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerListItem extends StatelessWidget {
  final CustomerModel customer;

  const CustomerListItem({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    context.read<CustomerService>();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => context.push('/edit_customer', extra: customer),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            customer.firstName[0] + customer.lastName[0],
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          customer.fullName,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4,),
            Text(customer.email),
            const SizedBox(height: 4,),
            Text(customer.phoneNumber),
          ],
        ),
        trailing: StreamBuilder<UserModel?>(
          stream: context.read<AuthService>().authStateChanges.asyncMap((user) async{
            if(user == null) return null;
            final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            if(!doc.exists) return null;
            return UserModel.fromMap(doc.data()!);
          }),
          builder: (context, snapshot){
            if(!snapshot.hasData) return const SizedBox.shrink();
            final currentUser = snapshot.data!;
            final canManageCustomers = ['admin', 'client', 'manager'].contains(currentUser.role);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if(canManageCustomers)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit Customer',
                    onPressed: () => context.push('/edit_customer', extra: customer),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
