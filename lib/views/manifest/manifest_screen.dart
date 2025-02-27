import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/models/vehicle_model.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/services/vehicle_service.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_tab_widget.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_group_widget.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_content_widget.dart';
import 'package:cateredtoyou/managers/drag_drop_manager.dart';

class ManifestScreen extends StatefulWidget {
  const ManifestScreen({Key? key}) : super(key: key);

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  int _selectedVehicleIndex = -1;
  Map<String, bool> _selectedItems = {};
  Map<String, int> _itemQuantities = {};
  late DragDropManager _dragDropManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the DragDropManager with the current context
    _dragDropManager = DragDropManager(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Loading System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh data - this will trigger the rebuild with latest data
              setState(() {});
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Left panel - LoadingPlans and LoadingItems
          Expanded(
            flex: 3, // Takes 3/8 of the screen width
            child: _buildLoadingPlansPanel(),
          ),

          // Divider
          const VerticalDivider(width: 1, thickness: 1),

          // Right panel - Vehicles with assigned LoadingItems
          Expanded(
            flex: 5, // Takes 5/8 of the screen width
            child: _buildVehiclesPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPlansPanel() {
    return Consumer<ManifestService>(
      builder: (context, loadingPlanService, child) {
        return StreamBuilder<List<Manifest>>(
          stream: loadingPlanService.getManifests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final loadingPlans = snapshot.data ?? [];

            if (loadingPlans.isEmpty) {
              return const Center(child: Text('No loading plans available'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: loadingPlans.length,
              itemBuilder: (context, index) {
                final loadingPlan = loadingPlans[index];

                // Skip loading plans with no items
                if (loadingPlan.items.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ManifestGroup(
                  manifest: loadingPlan,
                  selectedItems: _selectedItems,
                  itemQuantities: _itemQuantities,
                  onSelectAll: (bool selected) {
                    setState(() {
                      for (var item in loadingPlan.items) {
                        _selectedItems[item.id] = selected;
                      }
                    });
                  },
                  onItemSelected: (String itemId, bool selected) {
                    setState(() {
                      _selectedItems[itemId] = selected;
                    });
                  },
                  onQuantityChanged: (String itemId, int quantity) {
                    setState(() {
                      _itemQuantities[itemId] = quantity;
                    });
                  },
                  onItemDragged: (List<ManifestItem> items, List<int> quantities) {
                    // Use the DragDropManager to handle drag start
                    _dragDropManager.handleItemDragStart(items, quantities);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVehiclesPanel() {
    return Consumer<VehicleService>(
      builder: (context, vehicleService, child) {
        return StreamBuilder<List<Vehicle>>(
          stream: vehicleService.getVehicles(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final vehicles = snapshot.data ?? [];

            if (vehicles.isEmpty) {
              return const Center(child: Text('No vehicles available'));
            }

            return Column(
              children: [
                // Vehicle tabs - horizontal list of vehicle identifiers
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final isSelected = _selectedVehicleIndex == index;

                      return VehicleTab(
                        vehicle: vehicle,
                        isSelected: isSelected,
                        onSelected: () {
                          setState(() {
                            _selectedVehicleIndex = isSelected ? -1 : index;
                          });
                        },
                      );
                    },
                  ),
                ),

                // Vehicle content - displays when a vehicle is selected
                Expanded(
                  child: _selectedVehicleIndex >= 0 && _selectedVehicleIndex < vehicles.length
                      ? _buildVehicleContent(vehicles[_selectedVehicleIndex])
                      : const Center(child: Text('Select a vehicle to view assigned items')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildVehicleContent(Vehicle vehicle) {
    return Consumer<ManifestService>(
      builder: (context, loadingPlanService, child) {
        return StreamBuilder<List<Manifest>>(
          stream: loadingPlanService.getManifests(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final loadingPlans = snapshot.data ?? [];
            final assignedItems = <ManifestItem>[];

            // Collect all items assigned to this vehicle
            for (var plan in loadingPlans) {
              for (var item in plan.items) {
                if (item.vehicleId == vehicle.id) {
                  assignedItems.add(item);
                }
              }
            }

            return DragTarget<Map<String, dynamic>>(
              onWillAccept: (data) {
                // Only accept drops if data contains valid items
                return data != null && data.containsKey('items');
              },
              onAccept: (data) {
                // Use the DragDropManager to handle item drop
                _dragDropManager.handleItemDropOnVehicle(vehicle.id);

                // Clear selection after successful assignment
                setState(() {
                  _selectedItems.clear();
                  _itemQuantities.clear();
                });
              },
              builder: (context, candidateData, rejectedData) {
                return VehicleContent(
                  vehicle: vehicle,
                  assignedItems: assignedItems,
                  onItemRemoved: (item) {
                    // Use the DragDropManager to remove item from vehicle
                    _dragDropManager.removeItemFromVehicle(item);
                  },
                  onItemStatusChanged: (item, status) {
                    // Use the DragDropManager to update item status
                    _dragDropManager.updateItemLoadingStatus(item, status);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}