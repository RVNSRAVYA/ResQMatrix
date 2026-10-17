import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

const _allocInk = Color(0xFF14273D);
const _allocTeal = Color(0xFF0F9F91);
const _allocCanvas = Color(0xFFF4F7FB);

class ResourceAllocationScreen extends StatefulWidget {
  const ResourceAllocationScreen({super.key});

  @override
  State<ResourceAllocationScreen> createState() => _ResourceAllocationScreenState();
}

class _ResourceAllocationScreenState extends State<ResourceAllocationScreen> {
  List<dynamic> _requests = [];
  List<dynamic> _recommendations = [];
  List<dynamic> _history = [];
  String? _selectedRequestId;
  bool _loading = true;
  bool _loadingRecommendations = false;
  bool _allocating = false;
  String? _error;
  String _methodNote = 'Recommendations are decision support and should be reviewed by an authorized coordinator.';
  final TextEditingController _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/emergency-requests')).timeout(const Duration(seconds: 12)),
        http.get(Uri.parse('${ApiConfig.baseUrl}/allocations')).timeout(const Duration(seconds: 12)),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        throw Exception('API returned an error.');
      }
      final emergencyData = jsonDecode(responses[0].body) as Map<String, dynamic>;
      final allocationData = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final active = List<dynamic>.from(emergencyData['requests'] ?? const []).where((row) {
        final status = (row['status'] ?? 'Submitted').toString();
        return status != 'Resolved' && status != 'Cancelled';
      }).toList();
      final retainedId = active.any((row) => row['request_id'] == _selectedRequestId)
          ? _selectedRequestId
          : (active.isNotEmpty ? active.first['request_id'].toString() : null);
      if (!mounted) return;
      setState(() {
        _requests = active;
        _history = List<dynamic>.from(allocationData['allocations'] ?? const []);
        _selectedRequestId = retainedId;
        _loading = false;
      });
      if (retainedId != null) {
        await _loadRecommendations(retainedId, showSpinner: false);
      } else if (mounted) {
        setState(() => _recommendations = []);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load requests or allocation history. Start the ResQMatrix API and refresh.';
      });
    }
  }

  Future<void> _loadRecommendations(String requestId, {bool showSpinner = true}) async {
    if (showSpinner && mounted) setState(() => _loadingRecommendations = true);
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/allocations/recommendations/$requestId'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['detail'] ?? 'Could not load recommendations.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _recommendations = List<dynamic>.from(data['recommendations'] ?? const []);
        _methodNote = (data['method_note'] ?? _methodNote).toString();
        _loadingRecommendations = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingRecommendations = false;
        _error = 'Recommendation error: $error';
      });
    }
  }

  Future<void> _allocate(Map<String, dynamic> resource) async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (_selectedRequestId == null || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a request and enter a whole number greater than zero.')));
      return;
    }
    final available = (resource['available_quantity'] as num?)?.toInt() ?? 0;
    if (quantity > available) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Only $available unit(s) are available.')));
      return;
    }
    setState(() => _allocating = true);
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/allocations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'request_id': _selectedRequestId, 'resource_id': resource['resource_id'], 'quantity': quantity}),
      ).timeout(const Duration(seconds: 12));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['detail'] ?? 'Allocation failed (${response.statusCode}).');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']?.toString() ?? 'Resource allocated.')));
      await _loadAll();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not allocate resource: $error')));
    } finally {
      if (mounted) setState(() => _allocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _allocCanvas,
      appBar: AppBar(
        title: const Text('Resource Allocation'),
        backgroundColor: _allocCanvas,
        actions: [IconButton(onPressed: _loadAll, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 8)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _AllocationHero(verifiedOptions: _recommendations.length),
                  const SizedBox(height: 16),
                  if (_error != null) _InlineError(message: _error!),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5EBF2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Choose an active emergency', style: TextStyle(color: _allocInk, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      const Text('Recommendations refresh for the selected request.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      const SizedBox(height: 12),
                      if (_requests.isEmpty)
                        const Text('There are no active requests to allocate resources to.', style: TextStyle(color: Color(0xFF64748B)))
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedRequestId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5F8FB),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                          ),
                          items: _requests.map((row) => DropdownMenuItem<String>(
                            value: row['request_id'].toString(),
                            child: Text('${row['request_id']} · ${row['emergency_type']} · ${row['status']}', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedRequestId = value);
                            _loadRecommendations(value);
                          },
                        ),
                      if (_requests.isNotEmpty && _selectedRequestId != null) ...[
                        const SizedBox(height: 10),
                        _SelectedRequestSummary(request: _requests.firstWhere((row) => row['request_id'].toString() == _selectedRequestId)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    const Expanded(child: Text('Recommended resources', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _allocInk))),
                    Text('${_recommendations.length} matches', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  if (_loadingRecommendations) const Padding(padding: EdgeInsets.all(26), child: Center(child: CircularProgressIndicator())),
                  if (!_loadingRecommendations && _requests.isNotEmpty && _recommendations.isEmpty)
                    _EmptyAllocation(message: 'No verified, available resource in a compatible category was found. An administrator can verify organization resources in the Administrator Console.'),
                  if (!_loadingRecommendations)
                    ..._recommendations.map((item) {
                      final resource = Map<String, dynamic>.from(item as Map);
                      final score = (resource['recommendation_score'] as num?)?.toInt() ?? 0;
                      final available = (resource['available_quantity'] as num?)?.toInt() ?? 0;
                      final distance = resource['distance_km'] as num?;
                      final reasons = List<dynamic>.from(resource['reasons'] ?? const []);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE3EAF1)), boxShadow: const [BoxShadow(color: Color(0x070D2036), blurRadius: 17, offset: Offset(0, 6))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFE6F7F4), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.inventory_2_rounded, color: _allocTeal, size: 25)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${resource['name'] ?? 'Resource'}', style: const TextStyle(color: _allocInk, fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text('${resource['organization_name'] ?? 'Organization'} · ${resource['resource_type'] ?? 'Resource'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              const SizedBox(height: 3),
                              Text('${resource['location'] ?? 'Location not provided'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ])),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFE6F7F4), borderRadius: BorderRadius.circular(99)), child: Text('$score pts', style: const TextStyle(color: _allocTeal, fontWeight: FontWeight.w900, fontSize: 11))),
                          ]),
                          const SizedBox(height: 13),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _InfoPill(icon: Icons.verified_rounded, label: 'Verified'),
                            _InfoPill(icon: Icons.inventory_outlined, label: '$available available'),
                            if (distance != null) _InfoPill(icon: Icons.near_me_rounded, label: '${distance.toStringAsFixed(1)} km away'),
                          ]),
                          const SizedBox(height: 12),
                          ...reasons.map((reason) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle_outline_rounded, color: _allocTeal, size: 15), const SizedBox(width: 7), Expanded(child: Text(reason.toString(), style: const TextStyle(color: Color(0xFF536275), fontSize: 12, height: 1.3)))]))),
                          const SizedBox(height: 9),
                          Row(children: [
                            SizedBox(width: 88, child: TextField(controller: _quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Units', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),),
                            const SizedBox(width: 10),
                            Expanded(child: FilledButton.icon(onPressed: _allocating ? null : () => _allocate(resource), icon: const Icon(Icons.outbox_rounded, size: 18), label: Text(_allocating ? 'Allocating…' : 'Allocate resource'), style: FilledButton.styleFrom(backgroundColor: _allocInk, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                          ]),
                        ]),
                      );
                    }),
                  const SizedBox(height: 20),
                  Row(children: [const Icon(Icons.history_rounded, color: _allocTeal), const SizedBox(width: 8), const Expanded(child: Text('Recent allocations', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: _allocInk))), Text('${_history.length}', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700))]),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    const _EmptyAllocation(message: 'Your confirmed allocations will appear here.')
                  else
                    ..._history.take(6).map((item) {
                      final row = item as Map<String, dynamic>;
                      return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE5EBF2))), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFEAF4F5), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.task_alt_rounded, color: _allocTeal)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${row['resource_name'] ?? 'Resource'} · ${row['quantity'] ?? 1} unit(s)', style: const TextStyle(fontWeight: FontWeight.w800, color: _allocInk)), const SizedBox(height: 3), Text('${row['allocation_id']} · ${row['request_id']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))])), const Icon(Icons.check_circle_rounded, color: _allocTeal, size: 20)]));
                    }),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEAF4F5), borderRadius: BorderRadius.circular(16)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, color: _allocTeal), const SizedBox(width: 10), Expanded(child: Text(_methodNote, style: const TextStyle(fontSize: 12, height: 1.4, color: _allocInk)))])),
                ],
              ),
            ),
    );
  }
}

class _AllocationHero extends StatelessWidget {
  final int verifiedOptions;
  const _AllocationHero({required this.verifiedOptions});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF14273D), Color(0xFF17695F)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: const Text('COORDINATED RESPONSE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
            const SizedBox(height: 13),
            const Text('Get the right help\nto the right request.', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.08)),
            const SizedBox(height: 9),
            const Text('Match verified resources and track committed units.', style: TextStyle(color: Color(0xFFD5EEE8), fontSize: 12, height: 1.35)),
          ])),
          const SizedBox(width: 12),
          Container(width: 70, height: 70, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.route_rounded, color: Color(0xFF99F6E4), size: 37)),
        ]),
      );
}

class _SelectedRequestSummary extends StatelessWidget {
  final Map<String, dynamic> request;
  const _SelectedRequestSummary({required this.request});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEAF4F5), borderRadius: BorderRadius.circular(13)), child: Row(children: [const Icon(Icons.warning_amber_rounded, color: _allocTeal), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${request['emergency_type'] ?? 'Emergency'} · ${request['urgency'] ?? 'Medium'}', style: const TextStyle(color: _allocInk, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${request['people_count'] ?? 1} person(s) affected · ${request['status'] ?? 'Submitted'}', style: const TextStyle(color: Color(0xFF536275), fontSize: 12))]))]));
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFF2F7F9), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: _allocTeal, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: _allocInk, fontWeight: FontWeight.w700, fontSize: 11))]));
}

class _EmptyAllocation extends StatelessWidget {
  final String message;
  const _EmptyAllocation({required this.message});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE5EBF2))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.inventory_2_outlined, color: _allocTeal, size: 25), const SizedBox(width: 12), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF64748B), height: 1.4, fontSize: 13)))]));
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: Color(0xFFB42318)), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12)))]));
}
