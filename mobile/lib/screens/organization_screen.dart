import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

const _orgInk = Color(0xFF14273D);
const _orgTeal = Color(0xFF0F9F91);
const _orgCanvas = Color(0xFFF4F7FB);
const _orgMuted = Color(0xFF66768A);

class OrganizationScreen extends StatefulWidget {
  const OrganizationScreen({super.key});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  final _org = TextEditingController();
  final _resourceName = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _location = TextEditingController();
  final _contact = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _donationOrg = TextEditingController();
  final _donor = TextEditingController();
  final _donationValue = TextEditingController();
  final _donationNotes = TextEditingController();

  String _resourceType = 'Food & Water';
  String _donationType = 'Money';
  bool _busy = false;
  bool _loading = true;
  List<dynamic> _resources = [];
  List<dynamic> _donations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    for (final controller in [
      _org,
      _resourceName,
      _quantity,
      _location,
      _contact,
      _latitude,
      _longitude,
      _donationOrg,
      _donor,
      _donationValue,
      _donationNotes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/resources')).timeout(const Duration(seconds: 12)),
        http.get(Uri.parse('${ApiConfig.baseUrl}/donations')).timeout(const Duration(seconds: 12)),
      ]);
      if (results.any((response) => response.statusCode != 200)) {
        throw Exception('Could not load organization data.');
      }
      if (!mounted) return;
      setState(() {
        _resources = (jsonDecode(results[0].body)['resources'] as List).reversed.toList();
        _donations = (jsonDecode(results[1].body)['donations'] as List).reversed.toList();
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Cannot connect to the API. Start the ResQMatrix backend and refresh.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _send(String endpoint, Map<String, dynamic> body, String success) async {
    setState(() => _busy = true);
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['detail'] ?? 'Request failed (${response.statusCode})');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      if (endpoint == 'resources') {
        _resourceName.clear();
        _quantity.text = '1';
        _location.clear();
        _contact.clear();
        _latitude.clear();
        _longitude.clear();
      } else {
        _donor.clear();
        _donationValue.clear();
        _donationNotes.clear();
      }
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 19),
      );

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'received':
        return _orgTeal;
      case 'pending':
        return const Color(0xFFB7791F);
      case 'rejected':
      case 'unavailable':
        return const Color(0xFFCB3A4B);
      default:
        return _orgMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _orgCanvas,
      appBar: AppBar(
        title: const Text('Organization Portal'),
        backgroundColor: _orgCanvas,
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading && _resources.isEmpty && _donations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                    children: [
                      _OrgHero(resourceCount: _resources.length, donationCount: _donations.length),
                      const SizedBox(height: 16),
                      if (_error != null) _ErrorBanner(message: _error!),
                      Row(children: [
                        Expanded(child: _MetricCard(label: 'Resources listed', value: '${_resources.length}', icon: Icons.inventory_2_rounded, tint: _orgTeal)),
                        const SizedBox(width: 10),
                        Expanded(child: _MetricCard(label: 'Donations logged', value: '${_donations.length}', icon: Icons.volunteer_activism_rounded, tint: const Color(0xFF7B6AD8))),
                      ]),
                      const SizedBox(height: 22),
                      const _SectionHeading(title: 'Register a resource', subtitle: 'Add available supplies, capacity or response support.'),
                      const SizedBox(height: 11),
                      _Panel(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextField(controller: _org, textInputAction: TextInputAction.next, decoration: _dec('Organization / NGO name', icon: Icons.apartment_rounded)),
                          const SizedBox(height: 11),
                          TextField(controller: _resourceName, textInputAction: TextInputAction.next, decoration: _dec('Resource name', hint: 'e.g. Mobile medical team, shelter, food kits', icon: Icons.inventory_2_rounded)),
                          const SizedBox(height: 11),
                          DropdownButtonFormField<String>(
                            value: _resourceType,
                            decoration: _dec('Resource category', icon: Icons.category_rounded),
                            items: ['Food & Water', 'Medical', 'Ambulance', 'Rescue Team', 'Shelter', 'Medicines', 'Other'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                            onChanged: _busy ? null : (value) => setState(() => _resourceType = value ?? 'Other'),
                          ),
                          const SizedBox(height: 11),
                          TextField(controller: _quantity, keyboardType: TextInputType.number, decoration: _dec('Quantity / capacity', icon: Icons.numbers_rounded)),
                          const SizedBox(height: 11),
                          TextField(controller: _location, textInputAction: TextInputAction.next, decoration: _dec('Location or area name', hint: 'e.g. Machilipatnam town', icon: Icons.place_rounded)),
                          const SizedBox(height: 11),
                          Row(children: [
                            Expanded(child: TextField(controller: _latitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: _dec('Latitude (optional)', hint: '16.1875')),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: TextField(controller: _longitude, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: _dec('Longitude (optional)', hint: '81.1389')),
                            ),
                          ]),
                          const SizedBox(height: 7),
                          const Text('Adding both coordinates enables proximity-aware resource recommendations. If omitted, matching still works by category and availability.', style: TextStyle(color: _orgMuted, fontSize: 11.5, height: 1.4)),
                          const SizedBox(height: 11),
                          TextField(controller: _contact, keyboardType: TextInputType.phone, decoration: _dec('Contact details (optional)', icon: Icons.phone_outlined)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      final quantity = int.tryParse(_quantity.text.trim());
                                      final latText = _latitude.text.trim();
                                      final lonText = _longitude.text.trim();
                                      final latitude = latText.isEmpty ? null : double.tryParse(latText);
                                      final longitude = lonText.isEmpty ? null : double.tryParse(lonText);
                                      if (_org.text.trim().isEmpty || _resourceName.text.trim().isEmpty || _location.text.trim().isEmpty || quantity == null || quantity < 0) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter organization, resource, location and a valid non-negative quantity.')));
                                        return;
                                      }
                                      if ((latText.isEmpty) != (lonText.isEmpty) || (latText.isNotEmpty && (latitude == null || longitude == null || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180))) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid latitude and longitude together, or leave both blank.')));
                                        return;
                                      }
                                      _send('resources', {
                                        'organization_name': _org.text.trim(),
                                        'name': _resourceName.text.trim(),
                                        'resource_type': _resourceType,
                                        'quantity': quantity,
                                        'location': _location.text.trim(),
                                        'contact': _contact.text.trim(),
                                        'latitude': latitude,
                                        'longitude': longitude,
                                      }, 'Resource submitted for administrator verification.');
                                    },
                              icon: Icon(_busy ? Icons.hourglass_top_rounded : Icons.add_business_rounded),
                              label: Text(_busy ? 'Submitting…' : 'Submit resource for verification'),
                            ),
                          ),
                          const SizedBox(height: 9),
                          const _InlineNote(text: 'New resources remain Pending until an administrator verifies them. Only verified and available inventory is eligible for allocation.'),
                        ]),
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeading(title: 'Record a donation', subtitle: 'Keep a clear record of relief contributions.'),
                      const SizedBox(height: 11),
                      _Panel(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          TextField(controller: _donationOrg, textInputAction: TextInputAction.next, decoration: _dec('Receiving organization / NGO', icon: Icons.apartment_rounded)),
                          const SizedBox(height: 11),
                          TextField(controller: _donor, textInputAction: TextInputAction.next, decoration: _dec('Donor name', icon: Icons.person_outline_rounded)),
                          const SizedBox(height: 11),
                          DropdownButtonFormField<String>(
                            value: _donationType,
                            decoration: _dec('Donation type', icon: Icons.volunteer_activism_rounded),
                            items: ['Money', 'Food', 'Water', 'Medicines', 'Clothing', 'Equipment', 'Other'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                            onChanged: _busy ? null : (value) => setState(() => _donationType = value ?? 'Other'),
                          ),
                          const SizedBox(height: 11),
                          TextField(controller: _donationValue, decoration: _dec('Amount or quantity', hint: 'e.g. ₹5,000 or 40 food kits', icon: Icons.payments_outlined)),
                          const SizedBox(height: 11),
                          TextField(controller: _donationNotes, maxLines: 2, decoration: _dec('Notes (optional)', icon: Icons.notes_rounded)),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      if (_donationOrg.text.trim().isEmpty || _donor.text.trim().isEmpty || _donationValue.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter organization, donor and amount/quantity.')));
                                        return;
                                      }
                                      _send('donations', {
                                        'organization_name': _donationOrg.text.trim(),
                                        'donor_name': _donor.text.trim(),
                                        'donation_type': _donationType,
                                        'quantity_or_amount': _donationValue.text.trim(),
                                        'notes': _donationNotes.text.trim(),
                                      }, 'Donation recorded successfully.');
                                    },
                              icon: const Icon(Icons.volunteer_activism_rounded),
                              label: const Text('Record donation'),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeading(title: 'Registered resources', subtitle: 'Track review status and available quantities.'),
                      const SizedBox(height: 11),
                      if (_resources.isEmpty) const _EmptyPanel(icon: Icons.inventory_2_outlined, title: 'No resources yet', subtitle: 'Resources you submit will appear here with a verification status.'),
                      ..._resources.map((resource) => _RecordCard(
                            icon: Icons.inventory_2_rounded,
                            title: '${resource['name'] ?? 'Resource'}',
                            subtitle: '${resource['organization_name'] ?? 'Organization'} · ${resource['resource_type'] ?? 'Other'}',
                            detail: '${resource['location'] ?? 'Location not supplied'} · ${resource['available_quantity'] ?? resource['quantity'] ?? 0} available of ${resource['quantity'] ?? 0}',
                            status: '${resource['status'] ?? 'Pending'}',
                            statusColor: _statusColor('${resource['status'] ?? 'Pending'}'),
                          )),
                      const SizedBox(height: 18),
                      const _SectionHeading(title: 'Donation records', subtitle: 'A single view of the contributions submitted by your organization.'),
                      const SizedBox(height: 11),
                      if (_donations.isEmpty) const _EmptyPanel(icon: Icons.volunteer_activism_outlined, title: 'No donations recorded', subtitle: 'Donation records will appear here after submission.'),
                      ..._donations.map((donation) => _RecordCard(
                            icon: Icons.volunteer_activism_rounded,
                            title: '${donation['donation_type'] ?? 'Donation'} · ${donation['quantity_or_amount'] ?? ''}',
                            subtitle: '${donation['donor_name'] ?? 'Donor'} → ${donation['organization_name'] ?? 'Organization'}',
                            detail: '${donation['notes'] ?? ''}',
                            status: '${donation['status'] ?? 'Received'}',
                            statusColor: _statusColor('${donation['status'] ?? 'Received'}'),
                          )),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _OrgHero extends StatelessWidget {
  final int resourceCount;
  final int donationCount;
  const _OrgHero({required this.resourceCount, required this.donationCount});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF14273D), Color(0xFF24596B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: const Text('PARTNER & RELIEF OPERATIONS', style: TextStyle(color: Color(0xFFB7F7EA), fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: .8))),
            const SizedBox(height: 12),
            const Text('Mobilize what matters.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.12, fontWeight: FontWeight.w900, letterSpacing: -.5)),
            const SizedBox(height: 8),
            const Text('Register real capacity, record donations and help response coordinators discover verified support.', style: TextStyle(color: Color(0xFFD6E6EE), height: 1.4, fontSize: 12)),
            const SizedBox(height: 15),
            Wrap(spacing: 9, runSpacing: 8, children: [
              _HeroPill(icon: Icons.inventory_2_rounded, label: '$resourceCount resources'),
              _HeroPill(icon: Icons.volunteer_activism_rounded, label: '$donationCount donations'),
            ]),
          ])),
          const SizedBox(width: 12),
          Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(.12))), child: const Icon(Icons.volunteer_activism_rounded, size: 35, color: Color(0xFF99F6E4))),
        ]),
      );
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))]));
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5EBF2)), boxShadow: const [BoxShadow(color: Color(0x050D2036), blurRadius: 14, offset: Offset(0, 5))]), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: tint.withOpacity(.11), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: tint, size: 21)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: _orgInk, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: _orgMuted, fontSize: 11, fontWeight: FontWeight.w600))]))]));
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeading({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _orgInk, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.25)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: _orgMuted, height: 1.35, fontSize: 12))]);
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5EBF2)), boxShadow: const [BoxShadow(color: Color(0x050D2036), blurRadius: 16, offset: Offset(0, 5))]), child: child);
}

class _RecordCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String detail;
  final String status;
  final Color statusColor;
  const _RecordCard({required this.icon, required this.title, required this.subtitle, required this.detail, required this.status, required this.statusColor});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5EBF2))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 39, height: 39, decoration: const BoxDecoration(color: Color(0xFFEAF4F5), borderRadius: BorderRadius.all(Radius.circular(12))), child: Icon(icon, color: _orgTeal, size: 20)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _orgInk, fontWeight: FontWeight.w800, fontSize: 13.5)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _orgMuted, fontSize: 11.5)), if (detail.trim().isNotEmpty) ...[const SizedBox(height: 4), Text(detail, style: const TextStyle(color: _orgMuted, fontSize: 11, height: 1.3))]])), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(.11), borderRadius: BorderRadius.circular(99)), child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10)))]));
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5EBF2))), child: Column(children: [Icon(icon, color: const Color(0xFF91A2B5), size: 30), const SizedBox(height: 8), Text(title, style: const TextStyle(color: _orgInk, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _orgMuted, fontSize: 12, height: 1.35))]));
}

class _InlineNote extends StatelessWidget {
  final String text;
  const _InlineNote({required this.text});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, size: 16, color: _orgMuted), const SizedBox(width: 7), Expanded(child: Text(text, style: const TextStyle(color: _orgMuted, fontSize: 11, height: 1.35)))]);
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 13), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF4CACA))), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: Color(0xFFCB3A4B)), const SizedBox(width: 9), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF9F2635), fontSize: 12, height: 1.3)))]));
}
