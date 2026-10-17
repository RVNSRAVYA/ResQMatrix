import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api_config.dart';

const _triageInk = Color(0xFF14273D);
const _triageTeal = Color(0xFF0F9F91);
const _triageCanvas = Color(0xFFF4F7FB);

class PriorityTriageScreen extends StatefulWidget {
  const PriorityTriageScreen({super.key});

  @override
  State<PriorityTriageScreen> createState() => _PriorityTriageScreenState();
}

class _PriorityTriageScreenState extends State<PriorityTriageScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String? _error;
  String _methodNote =
      'Transparent rule-based decision support. Dispatchers should review the underlying facts.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/triage'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw Exception('Triage API returned ${response.statusCode}.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _requests = List<dynamic>.from(data['requests'] ?? const []);
        _methodNote = (data['method_note'] ?? _methodNote).toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the triage queue. Start the ResQMatrix API and refresh.';
      });
    }
  }

  Color _bandColor(String band) {
    switch (band.toLowerCase()) {
      case 'critical':
        return const Color(0xFFCB3A4B);
      case 'high':
        return const Color(0xFFE87935);
      case 'moderate':
        return const Color(0xFFB78616);
      default:
        return _triageTeal;
    }
  }

  int _count(String band) =>
      _requests.where((row) => row['priority_band'] == band).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _triageCanvas,
      appBar: AppBar(
        title: const Text('Priority Triage'),
        backgroundColor: _triageCanvas,
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Refresh queue',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _TriageHero(queueLength: _requests.length),
                  const SizedBox(height: 16),
                  if (_error != null) _ErrorBanner(message: _error!),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MiniStat(label: 'Critical', value: '${_count('Critical')}', color: _bandColor('Critical')),
                      _MiniStat(label: 'High', value: '${_count('High')}', color: _bandColor('High')),
                      _MiniStat(label: 'Moderate', value: '${_count('Moderate')}', color: _bandColor('Moderate')),
                      _MiniStat(label: 'Low', value: '${_count('Low')}', color: _bandColor('Low')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ranked response queue',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _triageInk),
                        ),
                      ),
                      Text('${_requests.length} active', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Requests are ordered by an explainable score to help coordinators review the queue.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  if (_requests.isEmpty)
                    const _EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'No active requests',
                      subtitle: 'New emergency requests will appear here after they are submitted.',
                    ),
                  ..._requests.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final request = entry.value as Map<String, dynamic>;
                    final band = (request['priority_band'] ?? 'Low').toString();
                    final color = _bandColor(band);
                    final score = (request['priority_score'] as num?)?.toInt() ?? 0;
                    final reasons = List<dynamic>.from(request['reasons'] ?? const []);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5EBF2)),
                        boxShadow: const [BoxShadow(color: Color(0x080D2036), blurRadius: 18, offset: Offset(0, 6))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(13)),
                              child: Text('$rank', style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${request['emergency_type'] ?? 'Emergency'} request', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _triageInk)),
                                const SizedBox(height: 3),
                                Text('${request['request_id'] ?? ''}  ·  ${request['people_count'] ?? 1} people affected', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(99)),
                              child: Text(band.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)),
                            ),
                          ]),
                          const SizedBox(height: 15),
                          Row(children: [
                            const Text('Priority score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            const Spacer(),
                            Text('$score / 100', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)),
                          ]),
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(value: (score / 100).clamp(0.0, 1.0).toDouble(), minHeight: 7, color: color, backgroundColor: const Color(0xFFE9EEF4)),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF6F8FB), borderRadius: BorderRadius.circular(14)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('RECOMMENDED NEXT STEP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8, color: Color(0xFF64748B))),
                              const SizedBox(height: 5),
                              Text('${request['recommended_action'] ?? 'Review request'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _triageInk)),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 4),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            title: const Text('Why this score?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _triageInk)),
                            children: reasons.map((reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 7),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Icon(Icons.check_circle_outline_rounded, size: 16, color: _triageTeal),
                                const SizedBox(width: 8),
                                Expanded(child: Text(reason.toString(), style: const TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF536275)))),
                              ]),
                            )).toList(),
                          ),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFEAF4F5), borderRadius: BorderRadius.circular(16)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline_rounded, color: _triageTeal),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_methodNote, style: const TextStyle(fontSize: 12, height: 1.4, color: _triageInk))),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TriageHero extends StatelessWidget {
  final int queueLength;
  const _TriageHero({required this.queueLength});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF14273D), Color(0xFF21465B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(99)), child: const Text('OPERATIONS INTELLIGENCE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1))),
            const SizedBox(height: 13),
            const Text('Prioritize what\nmatters most.', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.06)),
            const SizedBox(height: 9),
            Text('$queueLength active request(s) in the decision-support queue', style: const TextStyle(color: Color(0xFFD5E3EC), fontSize: 12, height: 1.35)),
          ])),
          const SizedBox(width: 12),
          Container(width: 72, height: 72, decoration: BoxDecoration(color: const Color(0xFF14B8A6).withOpacity(.18), borderRadius: BorderRadius.circular(23)), child: const Icon(Icons.hub_rounded, color: Color(0xFF5EEAD4), size: 38)),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE6ECF2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(color: _triageInk, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE6ECF2))),
        child: Column(children: [Icon(icon, size: 34, color: _triageTeal), const SizedBox(height: 10), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _triageInk)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), height: 1.35))]),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(14)), child: Row(children: [const Icon(Icons.cloud_off_rounded, color: Color(0xFFB42318)), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFB42318), fontSize: 12)))]));
}
