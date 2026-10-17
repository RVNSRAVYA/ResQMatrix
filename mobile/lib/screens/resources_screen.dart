import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

const _resourceInk = Color(0xFF14273D);
const _resourceTeal = Color(0xFF0F9F91);
const _resourceCanvas = Color(0xFFF4F7FB);
const _resourceMuted = Color(0xFF66768A);

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _searchController = TextEditingController();
  static const _categories = ['All', 'Rescue Team', 'Medical', 'Ambulance', 'Shelter', 'Food & Water', 'Medicines', 'Other'];
  List<dynamic> _resources = [];
  String _selectedCategory = 'All';
  String _search = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() => _search = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/resources')).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw Exception('API returned ${response.statusCode}.');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _resources = List<dynamic>.from(data['resources'] ?? const []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load the resource directory. Start the API and refresh.'; });
    }
  }

  List<Map<String, dynamic>> get _availableResources {
    final normalized = _selectedCategory.toLowerCase();
    return _resources.map((item) => Map<String, dynamic>.from(item as Map)).where((resource) {
      final status = '${resource['status'] ?? 'Pending'}'.toLowerCase();
      final available = (resource['available_quantity'] as num?)?.toInt() ?? (resource['quantity'] as num?)?.toInt() ?? 0;
      if (status != 'verified' || available < 1) return false;
      final type = '${resource['resource_type'] ?? 'Other'}'.toLowerCase();
      final categoryMatches = _selectedCategory == 'All' || type == normalized || (normalized == 'food & water' && {'food', 'water', 'food & water'}.contains(type));
      final haystack = '${resource['name']} ${resource['organization_name']} ${resource['location']} ${resource['resource_type']}'.toLowerCase();
      return categoryMatches && (_search.isEmpty || haystack.contains(_search));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _resources.where((item) => item['status'] == 'Verified' && (((item['available_quantity'] ?? item['quantity'] ?? 0) as num) > 0)).length;
    return Scaffold(
      backgroundColor: _resourceCanvas,
      appBar: AppBar(
        title: const Text('Resource Directory'),
        backgroundColor: _resourceCanvas,
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh resources', icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 6)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF14273D), Color(0xFF24596B)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
                  child: Row(children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('VERIFIED RESPONSE NETWORK', style: TextStyle(color: Color(0xFFB7F7EA), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                      SizedBox(height: 11),
                      Text('Help is stronger\nwhen it is connected.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                      SizedBox(height: 8),
                      Text('Browse confirmed resources shared by participating organizations and relief partners.', style: TextStyle(color: Color(0xFFD6E6EE), height: 1.4, fontSize: 12)),
                    ])),
                    const SizedBox(width: 12),
                    Container(width: 65, height: 65, decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(21), border: Border.all(color: Colors.white.withOpacity(.12))), child: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF99F6E4), size: 34)),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF1))), child: Row(children: [Container(width: 42, height: 42, decoration: const BoxDecoration(color: Color(0xFFE5F6F3), borderRadius: BorderRadius.all(Radius.circular(13))), child: const Icon(Icons.verified_user_rounded, color: _resourceTeal, size: 22)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Resources ready for coordination', style: const TextStyle(color: _resourceInk, fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 3), Text('$availableCount verified listings with available capacity', style: const TextStyle(color: _resourceMuted, fontSize: 11.5))]))])),
                const SizedBox(height: 17),
                TextField(controller: _searchController, decoration: const InputDecoration(hintText: 'Search resource, organization or area', prefixIcon: Icon(Icons.search_rounded), suffixIcon: Icon(Icons.tune_rounded))),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          selectedColor: const Color(0xFFDDF5EF),
                          labelStyle: TextStyle(
                            color: _selectedCategory == category ? _resourceTeal : _resourceInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                          side: BorderSide(
                            color: _selectedCategory == category ? _resourceTeal.withOpacity(.3) : const Color(0xFFE0E7EF),
                          ),
                          onSelected: (_) => setState(() => _selectedCategory = category),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [const Expanded(child: Text('Available listings', style: TextStyle(color: _resourceInk, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.2))), Text('${_availableResources.length} results', style: const TextStyle(color: _resourceMuted, fontSize: 11.5, fontWeight: FontWeight.w700))]),
                const SizedBox(height: 10),
                if (_error != null) _ErrorPanel(message: _error!),
                if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
                if (!_loading && _error == null && _availableResources.isEmpty) const _EmptyResources(),
                if (!_loading)
                  ..._availableResources.map((resource) {
                    final available = (resource['available_quantity'] as num?)?.toInt() ?? (resource['quantity'] as num?)?.toInt() ?? 0;
                    final hasCoordinates = resource['latitude'] != null && resource['longitude'] != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE3EAF1)), boxShadow: const [BoxShadow(color: Color(0x050D2036), blurRadius: 15, offset: Offset(0, 5))]),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(width: 46, height: 46, decoration: const BoxDecoration(color: Color(0xFFEAF4F5), borderRadius: BorderRadius.all(Radius.circular(14))), child: Icon(_iconFor('${resource['resource_type']}'), color: _resourceTeal, size: 24)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${resource['name'] ?? 'Resource'}', style: const TextStyle(color: _resourceInk, fontSize: 14.5, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('${resource['organization_name'] ?? 'Organization'} · ${resource['resource_type'] ?? 'Other'}', style: const TextStyle(color: _resourceMuted, fontSize: 11.5)),
                          const SizedBox(height: 7),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.place_outlined, size: 15, color: _resourceMuted), const SizedBox(width: 5), Expanded(child: Text('${resource['location'] ?? 'Location not supplied'}', style: const TextStyle(color: _resourceMuted, fontSize: 11.5)))]),
                          if (hasCoordinates) ...[
                            const SizedBox(height: 4),
                            Text('${(resource['latitude'] as num).toStringAsFixed(4)}, ${(resource['longitude'] as num).toStringAsFixed(4)}', style: const TextStyle(color: _resourceMuted, fontSize: 10.5)),
                          ],
                          const SizedBox(height: 10),
                          Wrap(spacing: 7, runSpacing: 7, children: [
                            _ListingPill(icon: Icons.verified_rounded, label: 'Verified', color: _resourceTeal),
                            _ListingPill(icon: Icons.inventory_2_outlined, label: '$available available', color: const Color(0xFF4381BF)),
                          ]),
                        ])),
                      ]),
                    );
                  }),
                const SizedBox(height: 8),
                const Text('For safety, this directory displays only resources marked Verified with at least one available unit. Confirm availability and suitability with the listed organization before dispatch.', style: TextStyle(color: _resourceMuted, fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'rescue team':
      case 'rescue':
        return Icons.health_and_safety_rounded;
      case 'medical':
      case 'medicines':
        return Icons.medical_services_rounded;
      case 'ambulance':
        return Icons.emergency_rounded;
      case 'shelter':
        return Icons.home_work_rounded;
      case 'food & water':
      case 'food':
      case 'water':
        return Icons.local_drink_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }
}

class _ListingPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ListingPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 13), const SizedBox(width: 5), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 10))]));
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: Color(0xFFCB3A4B)), const SizedBox(width: 9), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF9F2635), fontSize: 12)))]));
}

class _EmptyResources extends StatelessWidget {
  const _EmptyResources();

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(23), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE3EAF1))), child: const Column(children: [Icon(Icons.search_off_rounded, color: Color(0xFF91A2B5), size: 31), SizedBox(height: 8), Text('No matching verified resources', style: TextStyle(color: _resourceInk, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Try another category or search. Organizations can submit resources through the Organization Portal; administrators must verify them before they appear here.', textAlign: TextAlign.center, style: TextStyle(color: _resourceMuted, height: 1.4, fontSize: 12))]));
}
