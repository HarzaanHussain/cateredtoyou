import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cateredtoyou/models/manifest_model.dart';
import 'package:cateredtoyou/services/event_service.dart';

/// ListItem widget for displaying manifest summary information
/// 
/// This widget shows a summary of a manifest including event details,
/// item counts, and loading statistics in a card format.
class ManifestListItem extends StatefulWidget {
  final Manifest manifest;
  final VoidCallback onTap;

  const ManifestListItem({
    super.key,
    required this.manifest,
    required this.onTap,
  });

  @override
  State<ManifestListItem> createState() => _ManifestListItemState();
}

class _ManifestListItemState extends State<ManifestListItem> {
  String _eventName = 'Loading...';
  String _eventDate = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  Future<void> _loadEventDetails() async {
    try {
      final eventService = Provider.of<EventService>(context, listen: false);
      final event = await eventService.getEventById(widget.manifest.eventId);

      if (mounted) {
        setState(() {
          _eventName = event?.name ?? 'Unknown Event';
          _eventDate = event?.startDate != null
              ? DateFormat('MMM d, yyyy').format(event!.startDate)
              : 'Date unknown';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eventName = 'Error loading event';
          _eventDate = '';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Count unassigned items
    final unassignedItems = widget.manifest.items
        .where((item) => item.vehicleId == null)
        .length;
    
    
    
    // Count loaded items
    final loadedItems = widget.manifest.items
        .where((item) => item.loadingStatus == LoadingStatus.loaded)
        .length;
    
    // Calculate loading progress
    final loadingProgress = widget.manifest.items.isNotEmpty
        ? (loadedItems / widget.manifest.items.length * 100).toInt()
        : 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event icon/avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha((0.1 * 255).toInt()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.green,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Event details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _eventName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_isLoading)
                          Container(
                            width: 100,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        else
                          Text(
                            _eventDate,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Loading status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(loadingProgress).withAlpha((0.2 * 255).toInt()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(loadingProgress),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _getStatusColor(loadingProgress),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Loading progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$loadedItems of ${widget.manifest.items.length} items loaded',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$loadingProgress%',
                        style: TextStyle(
                          fontSize: 14,
                          color: _getStatusColor(loadingProgress),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: loadingProgress / 100,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(loadingProgress)),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Item stats in a row
              Row(
                children: [
                  _buildStatIndicator(
                    context,
                    'Total Items',
                    widget.manifest.items.length.toString(),
                    Icons.inventory,
                    Colors.blue,
                  ),
                  _buildStatIndicator(
                    context,
                    'Loaded',
                    loadedItems.toString(),
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                  _buildStatIndicator(
                    context,
                    'Unassigned',
                    unassignedItems.toString(),
                    Icons.pending_actions,
                    unassignedItems > 0 ? Colors.orange : Colors.grey,
                  ),
                ],
              ),
              
              // Last updated timestamp
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Last updated: ${DateFormat('MMM d, h:mm a').format(widget.manifest.updatedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              
              // Action row at bottom - FIX: Wrap buttons in SizedBox with fixed width
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 120, // Fixed width to prevent overflow
                    child: TextButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('View'),
                      onPressed: widget.onTap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180, // Fixed width to prevent constraint issues
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      label: const Text('Manage Loading'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: widget.onTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatIndicator(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$value $label',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(int progress) {
    if (progress == 100) {
      return Colors.green;
    } else if (progress > 50) {
      return Colors.orange;
    } else if (progress > 0) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }
  
  String _getStatusText(int progress) {
    if (progress == 100) {
      return 'Fully Loaded';
    } else if (progress > 0) {
      return 'Loading: $progress%';
    } else {
      return 'Not Started';
    }
  }
}