import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cateredtoyou/models/menu_item_model.dart';
import 'package:cateredtoyou/services/menu_item_service.dart';

class MenuItemListScreen extends StatefulWidget {
  const MenuItemListScreen({super.key});

  @override
  State<MenuItemListScreen> createState() => _MenuItemListScreenState();
}

class _MenuItemListScreenState extends State<MenuItemListScreen> {
  String _searchQuery = '';
  MenuItemType? _filterType;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MenuItem> _filterMenuItems(List<MenuItem> items) {
    return items.where((item) {
      if (_filterType != null && item.type != _filterType) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Back button icon.
          onPressed: () => context.push('/home'), // Navigate to home screen when pressed.
        ),  
        title: const Text('Menu Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-menu-item'),
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
                    hintText: 'Search menu items...',
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
                        selected: _filterType == null,
                        label: const Text('All'),
                        onSelected: (selected) {
                          setState(() {
                            _filterType = selected ? null : _filterType;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ...MenuItemType.values.map((type) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _filterType == type,
                            label: Text(type.toString().split('.').last),
                            onSelected: (selected) {
                              setState(() {
                                _filterType = selected ? type : null;
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
            child: StreamBuilder<List<MenuItem>>(
              stream: context.read<MenuItemService>().getMenuItems(),
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

                final menuItems = snapshot.data ?? [];
                final filteredItems = _filterMenuItems(menuItems);

                if (menuItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'No menu items found',
                          style: TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/add-menu-item'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Menu Item'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredItems.isEmpty) {
                  return const Center(
                    child: Text('No menu items match your search'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    return MenuItemCard(
                      menuItem: filteredItems[index],
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

class MenuItemCard extends StatelessWidget {
  final MenuItem menuItem;

  const MenuItemCard({
    super.key,
    required this.menuItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        
        contentPadding: const EdgeInsets.all(16),
        onTap: () => context.push('/edit-menu-item', extra: menuItem),
        title: Row(
          children: [
            Expanded(
              child: Text(
                menuItem.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '\$${menuItem.price.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
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
            Text(menuItem.description),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getIconForType(menuItem.type),
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  menuItem.type.toString().split('.').last,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(width: 16),
                if (menuItem.inventoryRequirements.isNotEmpty)
                  Icon(
                    Icons.inventory,
                    size: 16,
                    color: theme.textTheme.bodySmall?.color,
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.push('/edit-menu-item', extra: menuItem);
                break;
              case 'delete':
                _showDeleteConfirmation(context);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              textStyle: TextStyle(color: Colors.red),
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(MenuItemType type) {
    switch (type) {
      case MenuItemType.appetizer:
        return Icons.lunch_dining;
      case MenuItemType.mainCourse:
        return Icons.restaurant;
      case MenuItemType.sideDish:
        return Icons.dinner_dining;
      case MenuItemType.dessert:
        return Icons.cake;
      case MenuItemType.beverage:
        return Icons.local_bar;
      case MenuItemType.other:
        return Icons.food_bank;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final menuItemService = context.read<MenuItemService>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Menu Item'),
        content: Text('Are you sure you want to delete "${menuItem.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await menuItemService.deleteMenuItem(menuItem.id);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Menu item deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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
  }
}