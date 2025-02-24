import 'package:flutter/material.dart'; // Importing Flutter material package for UI components
import 'package:cateredtoyou/models/event_model.dart'; // Importing the EventMetadata model

class EventMetadataSection extends StatefulWidget {
  final Map<String, dynamic>? initialMetadata; // Initial metadata for the event
  final ValueChanged<Map<String, dynamic>> onMetadataChanged; // Callback when metadata changes

  const EventMetadataSection({
    super.key, // Key for the widget
    this.initialMetadata, // Optional initial metadata
    required this.onMetadataChanged, // Required callback for metadata changes
  });

  @override
  State<EventMetadataSection> createState() => _EventMetadataSectionState(); // Create the state for this widget
}

class _EventMetadataSectionState extends State<EventMetadataSection> {
  late bool _hasDietaryRequirements; // Whether the event has dietary requirements
  late bool _hasSpecialEquipment; // Whether the event needs special equipment
  late bool _hasBarService; // Whether the event requires bar service
  late List<String> _dietaryRestrictions; // List of dietary restrictions
  late List<String> _specialEquipmentNeeded; // List of special equipment needed
  String? _barServiceType; // Type of bar service required
  final _dietaryController = TextEditingController(); // Controller for dietary restriction input
  final _equipmentController = TextEditingController(); // Controller for special equipment input

  @override
  void initState() {
    super.initState();
    _initializeValues(); // Initialize values from initial metadata
  }

  void _initializeValues() {
    final metadata = widget.initialMetadata; // Get initial metadata
    // _hasDietaryRequirements = metadata?.hasDietaryRequirements ?? false; // Set dietary requirements flag
    // _hasSpecialEquipment = metadata?.hasSpecialEquipment ?? false; // Set special equipment flag
    // _hasBarService = metadata?.hasBarService ?? false; // Set bar service flag
    // _dietaryRestrictions = List.from(metadata?.dietaryRestrictions ?? []); // Initialize dietary restrictions list
    // _specialEquipmentNeeded = List.from(metadata?.specialEquipmentNeeded ?? []); // Initialize special equipment list
    // _barServiceType = metadata?.barServiceType; // Set bar service type
  }

  void _updateMetadata() {
    // final metadata = EventMetadata(
    //   hasDietaryRequirements: _hasDietaryRequirements, // Update dietary requirements flag
    //   hasSpecialEquipment: _hasSpecialEquipment, // Update special equipment flag
    //   hasBarService: _hasBarService, // Update bar service flag
    //   dietaryRestrictions: _dietaryRestrictions, // Update dietary restrictions list
    //   specialEquipmentNeeded: _specialEquipmentNeeded, // Update special equipment list
    //   barServiceType: _barServiceType, // Update bar service type
    // );
    // widget.onMetadataChanged(metadata); // Call the callback with updated metadata
  }

  void _addDietaryRestriction(String restriction) {
    if (restriction.isNotEmpty && !_dietaryRestrictions.contains(restriction)) {
      setState(() {
        _dietaryRestrictions.add(restriction); // Add new dietary restriction
        _dietaryController.clear(); // Clear the input field
        _updateMetadata(); // Update metadata
      });
    }
  }

  void _addSpecialEquipment(String equipment) {
    if (equipment.isNotEmpty && !_specialEquipmentNeeded.contains(equipment)) {
      setState(() {
        _specialEquipmentNeeded.add(equipment); // Add new special equipment
        _equipmentController.clear(); // Clear the input field
        _updateMetadata(); // Update metadata
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Padding around the card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align children to the start
          children: [
            Text(
              'Event Requirements', // Title of the section
              style: Theme.of(context).textTheme.titleLarge, // Style the title
            ),
            const SizedBox(height: 16), // Space below the title
            
            // Dietary Requirements Section
            SwitchListTile(
              title: const Text('Dietary Requirements'), // Label for the switch
              value: _hasDietaryRequirements, // Current value of the switch
              onChanged: (value) {
                setState(() {
                  _hasDietaryRequirements = value; // Update the value
                  if (!value) _dietaryRestrictions.clear(); // Clear restrictions if disabled
                  _updateMetadata(); // Update metadata
                });
              },
            ),
            if (_hasDietaryRequirements) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), // Padding around the input section
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dietaryController, // Controller for the input field
                            decoration: const InputDecoration(
                              labelText: 'Add dietary restriction', // Label for the input field
                              hintText: 'e.g., Vegetarian, Gluten-free', // Hint text for the input field
                            ),
                            onSubmitted: _addDietaryRestriction, // Add restriction on submit
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add), // Add icon button
                          onPressed: () => _addDietaryRestriction(_dietaryController.text), // Add restriction on button press
                        ),
                      ],
                    ),
                    const SizedBox(height: 8), // Space below the input row
                    Wrap(
                      spacing: 8, // Space between chips
                      children: _dietaryRestrictions.map((restriction) {
                        return Chip(
                          label: Text(restriction), // Label for the chip
                          onDeleted: () {
                            setState(() {
                              _dietaryRestrictions.remove(restriction); // Remove restriction on delete
                              _updateMetadata(); // Update metadata
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(), // Divider between sections

            // Special Equipment Section
            SwitchListTile(
              title: const Text('Special Equipment Needed'), // Label for the switch
              value: _hasSpecialEquipment, // Current value of the switch
              onChanged: (value) {
                setState(() {
                  _hasSpecialEquipment = value; // Update the value
                  if (!value) _specialEquipmentNeeded.clear(); // Clear equipment list if disabled
                  _updateMetadata(); // Update metadata
                });
              },
            ),
            if (_hasSpecialEquipment) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), // Padding around the input section
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _equipmentController, // Controller for the input field
                            decoration: const InputDecoration(
                              labelText: 'Add special equipment', // Label for the input field
                              hintText: 'e.g., Projector, Sound system', // Hint text for the input field
                            ),
                            onSubmitted: _addSpecialEquipment, // Add equipment on submit
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add), // Add icon button
                          onPressed: () => _addSpecialEquipment(_equipmentController.text), // Add equipment on button press
                        ),
                      ],
                    ),
                    const SizedBox(height: 8), // Space below the input row
                    Wrap(
                      spacing: 8, // Space between chips
                      children: _specialEquipmentNeeded.map((equipment) {
                        return Chip(
                          label: Text(equipment), // Label for the chip
                          onDeleted: () {
                            setState(() {
                              _specialEquipmentNeeded.remove(equipment); // Remove equipment on delete
                              _updateMetadata(); // Update metadata
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(), // Divider between sections

            // Bar Service Section
            SwitchListTile(
              title: const Text('Bar Service Required'), // Label for the switch
              value: _hasBarService, // Current value of the switch
              onChanged: (value) {
                setState(() {
                  _hasBarService = value; // Update the value
                  if (!value) _barServiceType = null; // Clear bar service type if disabled
                  _updateMetadata(); // Update metadata
                });
              },
            ),
            if (_hasBarService)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), // Padding around the dropdown
                child: DropdownButtonFormField<String>(
                  value: _barServiceType, // Current value of the dropdown
                  decoration: const InputDecoration(
                    labelText: 'Bar Service Type', // Label for the dropdown
                  ),
                  items: const [
                    DropdownMenuItem(value: 'full', child: Text('Full Service Bar')), // Full service bar option
                    DropdownMenuItem(value: 'beer_wine', child: Text('Beer & Wine Only')), // Beer & wine only option
                    DropdownMenuItem(value: 'mobile', child: Text('Mobile Bar')), // Mobile bar option
                    DropdownMenuItem(value: 'custom', child: Text('Custom Setup')), // Custom setup option
                  ],
                  onChanged: (value) {
                    setState(() {
                      _barServiceType = value; // Update bar service type
                      _updateMetadata(); // Update metadata
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dietaryController.dispose(); // Dispose dietary controller
    _equipmentController.dispose(); // Dispose equipment controller
    super.dispose();
  }
}