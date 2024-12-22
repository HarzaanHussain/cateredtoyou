// lib/views/inventory/inventory_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/inventory_item_model.dart';
import 'package:cateredtoyou/services/inventory_service.dart';
import 'package:cateredtoyou/widgets/custom_button.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  String _searchQuery = '';
  InventoryCategory? _filterCategory;
  bool _showLowStockOnly = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> _filterInventory(List<InventoryItem> items) {
    return items.where((item) {
      if (_showLowStockOnly && !item.needsReorder) return false;
      
      if (_filterCategory != null && item.category != _filterCategory) {
        return false;
      }

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(query);
    }).toList();
  }

  void _showQuantityAdjustDialog(InventoryItem item) {
    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(
      text: item.quantity.toString()
    );
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adjust ${item.name} Quantity'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'New Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a quantity';
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  if (number < 0) {
                    return 'Quantity cannot be negative';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final newQuantity = double.parse(quantityController.text);
                final notes = notesController.text.trim();
                
                final inventoryService = context.read<InventoryService>();
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                try {
                  await inventoryService.adjustQuantity(
                    item.id,
                    newQuantity,
                    notes: notes.isNotEmpty ? notes : null,
                  );

                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Quantity updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-inventory'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search inventory...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        selected: _showLowStockOnly,
                        label: const Text('Low Stock'),
                        onSelected: (selected) {
                          setState(() {
                            _showLowStockOnly = selected;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...InventoryCategory.values.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _filterCategory == category,
                            label: Text(category.toString().split('.').last),
                            onSelected: (selected) {
                              setState(() {
                                _filterCategory = selected ? category : null;
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: context.read<InventoryService>().getInventoryItems(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final items = snapshot.data ?? [];
                final filteredItems = _filterInventory(items);

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No inventory items found',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          label: 'Add Item',
                          onPressed: () => context.push('/add-inventory'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('No items match your search'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return InventoryListItem(
                      item: item,
                      onAdjustQuantity: () => _showQuantityAdjustDialog(item),
                    );
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

class InventoryListItem extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onAdjustQuantity;

  const InventoryListItem({
    super.key,
    required this.item,
    required this.onAdjustQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsReorder = item.needsReorder;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => context.push('/edit-inventory', extra: item),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (needsReorder)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Low Stock',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Category: ${item.category.toString().split('.').last}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity: ${item.quantity} ${item.unit.toString().split('.').last}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        'Reorder Point: ${item.reorderPoint}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onAdjustQuantity,
                  icon: const Icon(Icons.edit),
                  label: const Text('Adjust'),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/edit-inventory', extra: item);
                break;
              case 'delete':
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Item'),
                    content: Text(
                      'Are you sure you want to delete ${item.name}?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            final inventoryService = 
                                context.read<InventoryService>();
                            await inventoryService.deleteInventoryItem(item.id);

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item deleted successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              textStyle: TextStyle(color: Colors.red),
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}