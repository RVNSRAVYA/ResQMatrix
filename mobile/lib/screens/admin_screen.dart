import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

const _adminInk = Color(0xFF14273D);
const _adminTeal = Color(0xFF0F9F91);
const _adminCanvas = Color(0xFFF4F7FB);
const _adminMuted = Color(0xFF66768A);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> _emergencies = [];
  List<dynamic> _resources = [];
  bool _loading = true;
  bool _updating = false;
  String? _error;
  final _statuses = const ['Submitted', 'Under Review', 'Assigned', 'Accepted', 'In Progress', 'Resolved', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/emergency-requests')).timeout(const Duration(seconds: 12)),
        http.get(Uri.parse('${ApiConfig.baseUrl}/resources')).timeout(const Duration(seconds: 12)),
      ]);
      if (results.any((response) => response.statusCode != 200)) throw Exception('API returned an error.');
      if (!mounted) return;
      final emergencies = List<dynamic>.from((jsonDecode(results[0].body) as Map<String, dynamic>)['requests'] ?? const []);
      final resources = List<dynamic>.from((jsonDecode(results[1].body) as Map<String, dynamic>)['resources'] ?? const []);
      setState(() {
        _emergencies = emergencies.reversed.toList();
        _resources = resources.reversed.toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Cannot connect to the API. Start the ResQMatrix backend, then refresh.'; });
    }
  }

  Future<void> _patch(String path, Map<String, dynamic> body, String success) async {
    setState(() => _updating = true);
    try {
      final response = await http
          .patch(Uri.parse('${ApiConfig.baseUrl}/$path'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['detail'] ?? 'Update failed (${response.statusCode}).');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $error')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return const Color(0xFFCB3A4B);
      case 'high':
        return const Color(0xFFE87935);
      case 'medium':
        return const Color(0xFFB78616);
      default:
        return _adminTeal;
    }
  }

  Color _resourceColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return _adminTeal;
      case 'pending':
        return const Color(0xFFB7791F);
      case 'rejected':
      case 'unavailable':
        return const Color(0xFFCB3A4B);
      default:
        return _adminMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingResources = _resources.where((resource) => resource['status'] == 'Pending').length;
    final activeEmergencies = _emergencies.where((emergency) => emergency['status'] != 'Resolved' && emergency['status'] != 'Cancelled').length;
    final verifiedResources = _resources.where((resource) => resource['status'] == 'Verified').length;

    return Scaffold(
      backgroundColor: _adminCanvas,
      appBar: AppBar(
        title: const Text('Administrator Console'),
        backgroundColor: _adminCanvas,
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh data', icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 6)],
      ),
      body: _loading && _emergencies.isEmpty && _resources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                    children: [
                      const _AdminHero(),
                      const SizedBox(height: 16),
                      if (_error != null) _AdminError(message: _error!),
                      Row(children: [
                        Expanded(child: _AdminMetric(label: 'Active emergencies', value: '$activeEmergencies', icon: Icons.campaign_rounded, tint: const Color(0xFFE87935))),
                        const SizedBox(width: 9),
                        Expanded(child: _AdminMetric(label: 'Awaiting review', value: '$pendingResources', icon: Icons.pending_actions_rounded, tint: const Color(0xFFB78616))),
                        const SizedBox(width: 9),
                        Expanded(child: _AdminMetric(label: 'Verified resources', value: '$verifiedResources', icon: Icons.verified_user_rounded, tint: _adminTeal)),
                      ]),
                      const SizedBox(height: 24),
                      const _AdminSection(title: 'Emergency monitoring', subtitle: 'Review request details and keep the response status up to date.'),
                      const SizedBox(height: 11),
                      if (_emergencies.isEmpty) const _AdminEmpty(icon: Icons.inbox_rounded, title: 'No emergency requests yet', subtitle: 'New submissions will appear here for review.'),
                      ..._emergencies.map((emergency) {
                        final urgency = '${emergency['urgency'] ?? 'Medium'}';
                        final urgencyColor = _urgencyColor(urgency);
                        final status = '${emergency['status'] ?? 'Submitted'}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE4EAF1)), boxShadow: const [BoxShadow(color: Color(0x050D2036), blurRadius: 15, offset: Offset(0, 5))]),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 43, height: 43, decoration: BoxDecoration(color: urgencyColor.withOpacity(.11), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.sos_rounded, color: urgencyColor, size: 23)),
                              const SizedBox(width: 11),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${emergency['emergency_type'] ?? 'Emergency'} request', style: const TextStyle(color: _adminInk, fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 3),
                                Text('${emergency['request_id'] ?? ''} · ${emergency['people_count'] ?? 1} people affected', style: const TextStyle(color: _adminMuted, fontSize: 11.5)),
                              ])),
                              _StatusPill(label: urgency.toUpperCase(), color: urgencyColor),
                            ]),
                            if ('${emergency['description'] ?? ''}'.trim().isNotEmpty) ...[
                              const SizedBox(height: 11),
                              Text('${emergency['description']}', style: const TextStyle(color: Color(0xFF536275), height: 1.35, fontSize: 12)),
                            ],
                            const SizedBox(height: 11),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _MetaPill(icon: Icons.place_outlined, text: '${(emergency['latitude'] as num?)?.toStringAsFixed(4) ?? '—'}, ${(emergency['longitude'] as num?)?.toStringAsFixed(4) ?? '—'}'),
                              _MetaPill(icon: Icons.schedule_rounded, text: status),
                            ]),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _statuses.contains(status) ? status : 'Submitted',
                              decoration: const InputDecoration(labelText: 'Update response status', prefixIcon: Icon(Icons.route_rounded, size: 18)),
                              items: _statuses.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                              onChanged: _updating ? null : (value) {
                                if (value != null && value != status) {
                                  _patch('emergency-requests/${emergency['request_id']}/status', {'status': value}, 'Emergency status updated.');
                                }
                              },
                            ),
                          ]),
                        );
                      }),
                      const SizedBox(height: 22),
                      const _AdminSection(title: 'Resource verification', subtitle: 'Only verified resources can be recommended for allocation.'),
                      const SizedBox(height: 11),
                      if (_resources.isEmpty) const _AdminEmpty(icon: Icons.inventory_2_outlined, title: 'No resource submissions', subtitle: 'Resources registered by organizations will appear here.'),
                      ..._resources.map((resource) {
                        final status = '${resource['status'] ?? 'Pending'}';
                        final color = _resourceColor(status);
                        final available = resource['available_quantity'] ?? resource['quantity'] ?? 0;
                        final quantity = resource['quantity'] ?? 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF1))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 42, height: 42, decoration: const BoxDecoration(color: Color(0xFFEAF4F5), borderRadius: BorderRadius.all(Radius.circular(13))), child: const Icon(Icons.inventory_2_rounded, color: _adminTeal, size: 22)),
                              const SizedBox(width: 11),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${resource['name'] ?? 'Resource'}', style: const TextStyle(color: _adminInk, fontWeight: FontWeight.w900, fontSize: 14.5)),
                                const SizedBox(height: 3),
                                Text('${resource['organization_name'] ?? 'Organization'} · ${resource['resource_type'] ?? 'Other'}', style: const TextStyle(color: _adminMuted, fontSize: 11.5)),
                                const SizedBox(height: 3),
                                Text('${resource['location'] ?? 'Location not supplied'}', style: const TextStyle(color: _adminMuted, fontSize: 11.5)),
                              ])),
                              _StatusPill(label: status, color: color),
                            ]),
                            const SizedBox(height: 11),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _MetaPill(icon: Icons.inventory_outlined, text: '$available available / $quantity total'),
                              if (resource['latitude'] != null && resource['longitude'] != null)
                                _MetaPill(icon: Icons.my_location_rounded, text: '${(resource['latitude'] as num).toStringAsFixed(3)}, ${(resource['longitude'] as num).toStringAsFixed(3)}'),
                            ]),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              FilledButton.icon(
                                onPressed: _updating ? null : () => _patch('resources/${resource['resource_id']}/verification', {'status': 'Verified'}, 'Resource verified.'),
                                icon: const Icon(Icons.verified_rounded, size: 17),
                                label: const Text('Verify'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _updating ? null : () => _patch('resources/${resource['resource_id']}/verification', {'status': 'Rejected'}, 'Resource rejected.'),
                                icon: const Icon(Icons.block_rounded, size: 17),
                                label: const Text('Reject'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _updating ? null : () => _patch('resources/${resource['resource_id']}/verification', {'status': 'Unavailable'}, 'Resource marked unavailable.'),
                                icon: const Icon(Icons.pause_circle_outline_rounded, size: 17),
                                label: const Text('Unavailable'),
                              ),
                            ]),
                          ]),
                        );
                      }),
                      const SizedBox(height: 14),
                      const _AdminWarning(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF14273D), Color(0xFF24596B)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CONTROL ROOM', style: TextStyle(color: Color(0xFFB7F7EA), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
            SizedBox(height: 10),
            Text('Monitor. Verify. Coordinate.', style: TextStyle(color: Colors.white, fontSize: 23, height: 1.12, fontWeight: FontWeight.w900, letterSpacing: -.35)),
            SizedBox(height: 8),
            Text('Review active cases, maintain workflow visibility and approve resource submissions.', style: TextStyle(color: Color(0xFFD6E6EE), fontSize: 12, height: 1.4)),
          ])),
          const SizedBox(width: 12),
          Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(.12))), child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF99F6E4), size: 33)),
        ]),
      );
}

class _AdminMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  const _AdminMetric({required this.label, required this.value, required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE4EAF1))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 35, height: 35, decoration: BoxDecoration(color: tint.withOpacity(.11), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: tint, size: 19)), const SizedBox(height: 9), Text(value, style: const TextStyle(color: _adminInk, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: _adminMuted, fontSize: 10.5, fontWeight: FontWeight.w700), maxLines: 2)]));
}

class _AdminSection extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AdminSection({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _adminInk, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.2)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _adminMuted, fontSize: 12, height: 1.35))]);
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(99)), child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .35)));
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFF3F7FA), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: _adminMuted, size: 14), const SizedBox(width: 6), Text(text, style: const TextStyle(color: _adminInk, fontSize: 10.5, fontWeight: FontWeight.w700))]));
}

class _AdminEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _AdminEmpty({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF1))), child: Column(children: [Icon(icon, color: const Color(0xFF91A2B5), size: 29), const SizedBox(height: 8), Text(title, style: const TextStyle(color: _adminInk, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _adminMuted, fontSize: 12, height: 1.35))]));
}

class _AdminError extends StatelessWidget {
  final String message;
  const _AdminError({required this.message});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF4CACA))), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: Color(0xFFCB3A4B)), const SizedBox(width: 9), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF9F2635), fontSize: 12)))]));
}

class _AdminWarning extends StatelessWidget {
  const _AdminWarning();

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFFF5E9), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFF4DEBD))), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.security_rounded, color: Color(0xFFB7791F)), SizedBox(width: 9), Expanded(child: Text('Demonstration console: authentication and role-based authorization are not implemented. Do not expose these administrative actions publicly for real emergency operations.', style: TextStyle(color: Color(0xFF7D521B), fontSize: 11.5, height: 1.4)))]));
}
