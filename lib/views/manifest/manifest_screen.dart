import 'package:cateredtoyou/views/manifest/manifest_creation_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cateredtoyou/services/manifest_service.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/views/manifest/manifest_detail_screen.dart';
import 'package:cateredtoyou/views/manifest/split_view_manifest_screen.dart';
import 'package:cateredtoyou/views/manifest/widgets/manifest_list_item.dart';
import 'package:cateredtoyou/views/manifest/widgets/vehicle_overview_tab.dart';
import 'package:cateredtoyou/widgets/bottom_toolbar.dart'; // Imports bottom toolbar class


/// Main screen that displays a list of all manifests
///
/// This screen shows all manifests in a list view with summary information.
/// Users can tap on a manifest to view its details and manage assignments.
class ManifestScreen extends StatefulWidget {
  const ManifestScreen({super.key});

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterOption = 'All';
  
  // Tab controller
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool get _canShowSplitView {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200; // Only for very wide screens
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        bottomNavigationBar: const BottomToolbar(),
        appBar: AppBar(
          title: const Text('Catering Management'),
          elevation: 2,
          bottom: const TabBar(
            labelColor: Colors.black,        // <- selected tab text color
            tabs: [
              Tab(text: 'Manifests'),
              Tab(text: 'Vehicles'),
              Tab(text: 'Archive'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                _showFilterOptions(context);
              },
              tooltip: 'Filter manifests',
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () {
                _showSortOptions(context);
              },
              tooltip: 'Sort manifests',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // Active Manifests tab
            _buildManifestsTab(theme),
            
            // Vehicles tab
            const VehicleOverviewTab(),
            
            // Archive tab
            _buildArchivedTab(theme),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabIndex = DefaultTabController.of(context).index;
            // Only show FAB on the manifests tab
            if (tabIndex != 0) return const SizedBox.shrink();
            
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManifestCreationScreen(),
                  ),
                ).then((created) {
                  if (created == true) {
                    // Refresh the list if a new manifest was created
                    setState(() {});
                  }
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('New Manifest'),
              backgroundColor:Colors.green,// button same color as theme
            );
          }
        ),
      ),
    );
  }
  
  Widget _buildManifestsTab(ThemeData theme) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search manifests...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              filled: true,
              fillColor: theme.cardColor,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
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
        ),
        
        // Active filter chip
        if (_filterOption != 'All')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Chip(
                  label: Text(_filterOption),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _filterOption = 'All';
                    });
                  },
                  backgroundColor: Colors.green.withAlpha((0.1 * 255).toInt()),
                  deleteIconColor: Colors.green,
                  labelStyle: const TextStyle(color: Colors.green),
                ),
                const SizedBox(width: 8),
                Text(
                  'Active filter',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        
        // Manifests list
        Expanded(
          child: Consumer<ManifestService>(
            builder: (context, manifestService, child) {
              return StreamBuilder<List<Manifest>>(
                stream: manifestService.getManifests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading manifests',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: () {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  var manifests = snapshot.data ?? [];
                  
                  if (manifests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No manifests available',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Manifest'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ManifestCreationScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  // Apply filters if needed
                  if (_filterOption == 'With Unassigned Items') {
                    manifests = manifests.where((manifest) {
                      final unassignedItems = manifest.items
                          .where((item) => item.vehicleId == null)
                          .length;
                      return unassignedItems > 0;
                    }).toList();
                  } else if (_filterOption == 'Fully Loaded') {
                    manifests = manifests.where((manifest) {
                      // Check if all items are assigned AND loaded
                      final allAssigned = manifest.items.every((item) => item.vehicleId != null);
                      final allLoaded = manifest.items.every(
                        (item) => item.loadingStatus == LoadingStatus.loaded
                      );
                      return allAssigned && allLoaded && manifest.items.isNotEmpty;
                    }).toList();
                  } else if (_filterOption == 'Partially Loaded') {
                    manifests = manifests.where((manifest) {
                      // Check if some items are assigned but not all are loaded
                      final anyAssigned = manifest.items.any((item) => item.vehicleId != null);
                      final allLoaded = manifest.items.every(
                        (item) => item.loadingStatus == LoadingStatus.loaded || item.vehicleId == null
                      );
                      return anyAssigned && !allLoaded && manifest.items.isNotEmpty;
                    }).toList();
                  }

                  // Filter manifests based on search query
                  if (_searchQuery.isNotEmpty) {
                    final lowerQuery = _searchQuery.toLowerCase();
                    manifests = manifests.where((manifest) {
                      // Search by event ID or any other searchable field
                      // In a real app, you might want to search by event name which would require loading event details first
                      return manifest.eventId.toLowerCase().contains(lowerQuery);
                    }).toList();
                  }

                  if (manifests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No results found',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Clear Filters'),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                                _filterOption = 'All';
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: manifests.length,
                    itemBuilder: (context, index) {
                      final manifest = manifests[index];
                      
                      return ManifestListItem(
                        manifest: manifest,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _canShowSplitView
                                  ? SplitViewManifestScreen(
                                      manifestId: manifest.id,
                                    )
                                  : ManifestDetailScreen(
                                      manifestId: manifest.id,
                                    ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedTab(ThemeData theme) {
    return Column(
      children: [
        // Archive explanation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.archive_outlined, color: theme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Archived manifests are completed manifests where all items have been loaded.',
                ),
              ),
            ],
          ),
        ),
        
        // Archived manifests list
        Expanded(
          child: Consumer<ManifestService>(
            builder: (context, manifestService, child) {
              return StreamBuilder<List<Manifest>>(
                stream: manifestService.getArchivedManifests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading archived manifests',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  final manifests = snapshot.data ?? [];
                  
                  if (manifests.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No archived manifests',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Completed manifests will appear here',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: manifests.length,
                    itemBuilder: (context, index) {
                      final manifest = manifests[index];
                      
                      return ManifestListItem(
                        manifest: manifest,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManifestDetailScreen(
                                manifestId: manifest.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Filter Manifests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _buildFilterOption(context, 'All', _filterOption == 'All'),
              _buildFilterOption(context, 'With Unassigned Items', _filterOption == 'With Unassigned Items'),
              _buildFilterOption(context, 'Partially Loaded', _filterOption == 'Partially Loaded'),
              _buildFilterOption(context, 'Fully Loaded', _filterOption == 'Fully Loaded'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Sort Manifests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ListTile(
                title: const Text('Date (Newest First)'),
                leading: const Icon(Icons.sort),
                onTap: () {
                  Navigator.pop(context);
                  // Would implement sorting logic
                },
              ),
              ListTile(
                title: const Text('Date (Oldest First)'),
                leading: const Icon(Icons.sort),
                onTap: () {
                  Navigator.pop(context);
                  // Would implement sorting logic
                },
              ),
              ListTile(
                title: const Text('Loading Progress (High to Low)'),
                leading: const Icon(Icons.trending_down),
                onTap: () {
                  Navigator.pop(context);
                  // Would implement sorting logic
                },
              ),
              ListTile(
                title: const Text('Loading Progress (Low to High)'),
                leading: const Icon(Icons.trending_up),
                onTap: () {
                  Navigator.pop(context);
                  // Would implement sorting logic
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(BuildContext context, String title, bool isSelected) {
    return ListTile(
      title: Text(title),
      leading: isSelected
          ? Icon(Icons.radio_button_checked, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked),
      onTap: () {
        setState(() {
          _filterOption = title;
        });
        Navigator.pop(context);
      },
    );
  }
}