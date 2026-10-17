import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  String emergencyType = 'Rescue';
  String urgency = 'Medium';

  final TextEditingController peopleController = TextEditingController();
  final TextEditingController descriptionController =
      TextEditingController();

  Position? currentPosition;
  bool isLoadingLocation = true;
  bool isSubmitting = false;
  String locationMessage = 'Getting your current location...';

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  @override
  void dispose() {
    peopleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      isLoadingLocation = true;
      locationMessage = 'Getting your current location...';
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          isLoadingLocation = false;
          locationMessage = 'Location service is disabled.';
        });
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          isLoadingLocation = false;
          locationMessage = 'Location permission denied.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          isLoadingLocation = false;
          locationMessage =
              'Location permission permanently denied.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentPosition = position;
        isLoadingLocation = false;
        locationMessage = 'Location detected successfully.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingLocation = false;
        locationMessage = 'Unable to get current location.';
      });
    }
  }

  Future<void> submitRequest() async {
    if (peopleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter number of people.'),
        ),
      );
      return;
    }

    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Current location is not available. Please try again.',
          ),
        ),
      );
      return;
    }

    final peopleCount = int.tryParse(
      peopleController.text.trim(),
    );

    if (peopleCount == null || peopleCount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid number of people.'),
        ),
      );
      return;
    }

    if (isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/emergency-requests',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'emergency_type': emergencyType,
              'urgency': urgency,
              'people_count': peopleCount,
              'description': descriptionController.text.trim(),
              'latitude': currentPosition!.latitude,
              'longitude': currentPosition!.longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final request = data['request'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Emergency request submitted successfully.\n'
              'Request ID: ${request['request_id']}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        // Clear the form after successful submission.
        peopleController.clear();
        descriptionController.clear();

        setState(() {
          emergencyType = 'Rescue';
          urgency = 'Medium';
        });
      } else {
        String message =
            'Request failed. Server returned ${response.statusCode}.';

        try {
          final errorData = jsonDecode(response.body);

          if (errorData is Map &&
              errorData['detail'] != null) {
            message = errorData['detail'].toString();
          }
        } catch (_) {
          // Keep the default error message.
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
    } on http.ClientException {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not connect to the ResQMatrix backend.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong while submitting the request.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Request'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Emergency Help',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Submit your emergency requirement',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              initialValue: emergencyType,
              decoration: const InputDecoration(
                labelText: 'Emergency Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Rescue',
                  child: Text('Rescue'),
                ),
                DropdownMenuItem(
                  value: 'Medical',
                  child: Text('Medical'),
                ),
                DropdownMenuItem(
                  value: 'Ambulance',
                  child: Text('Ambulance'),
                ),
                DropdownMenuItem(
                  value: 'Food',
                  child: Text('Food'),
                ),
                DropdownMenuItem(
                  value: 'Water',
                  child: Text('Water'),
                ),
                DropdownMenuItem(
                  value: 'Medicines',
                  child: Text('Medicines'),
                ),
                DropdownMenuItem(
                  value: 'Shelter',
                  child: Text('Shelter'),
                ),
                DropdownMenuItem(
                  value: 'Other',
                  child: Text('Other'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    emergencyType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: urgency,
              decoration: const InputDecoration(
                labelText: 'Urgency',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Low',
                  child: Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'Medium',
                  child: Text('Medium'),
                ),
                DropdownMenuItem(
                  value: 'High',
                  child: Text('High'),
                ),
                DropdownMenuItem(
                  value: 'Critical',
                  child: Text('Critical'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    urgency = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: peopleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of People',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe your emergency',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(locationMessage),
                          if (currentPosition != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Latitude: '
                              '${currentPosition!.latitude}\n'
                              'Longitude: '
                              '${currentPosition!.longitude}',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isLoadingLocation)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    (isLoadingLocation || isSubmitting)
                        ? null
                        : submitRequest,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    isSubmitting
                        ? 'Submitting...'
                        : 'Submit Emergency Request',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    isLoadingLocation ? null : getCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Refresh Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}