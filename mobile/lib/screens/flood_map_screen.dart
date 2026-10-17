import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class FloodMapScreen extends StatefulWidget {
  const FloodMapScreen({super.key});
  @override
  State<FloodMapScreen> createState() => _FloodMapScreenState();
}

class _FloodMapScreenState extends State<FloodMapScreen> {
  static const _indiaCenter = LatLng(22.3, 80.6);
  static const _levels = ['Critical', 'High', 'Moderate', 'Low'];

  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;
  String? _error;
  String _datasetNote = 'Loading station risk estimates…';
  String _filter = 'All';
  String? _selected;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await http.get(Uri.parse('${ApiConfig.baseUrl}/risk-areas?limit=60')).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) throw Exception('API returned ${response.statusCode}.');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(
          (data['areas'] as List<dynamic>? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)));
      final range = data['date_range'];
      final years = (range is List && range.length == 2)
          ? '${range[0].toString().substring(0, 4)}–${range[1].toString().substring(0, 4)}'
          : 'historical';
      if (!mounted) return;
      setState(() {
        _areas = items;
        _datasetNote = '${data['dataset_rows'] ?? '—'} historical records · $years · ${items.length} stations';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Risk areas could not be loaded. Start the ResQMatrix backend and refresh.\n$e';
      });
    }
  }

  List<Map<String, dynamic>> get _visible =>
      _filter == 'All' ? _areas : _areas.where((a) => '${a['risk_level']}' == _filter).toList();

  int _count(String level) => _areas.where((a) => '${a['risk_level']}' == level).length;

  LatLng _point(Map<String, dynamic> a) =>
      LatLng((a['latitude'] as num).toDouble(), (a['longitude'] as num).toDouble());

  void _focus(Map<String, dynamic> area) {
    setState(() => _selected = '${area['station']}');
    _mapController.move(_point(area), 7.2);
  }

  void _showStation(Map<String, dynamic> area) {
    _focus(area);
    final risk = '${area['risk_level'] ?? 'Unknown'}';
    final color = AppColors.risk(risk);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(icon: Icons.sensors_rounded, color: color, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${area['station']}',
                    style: const TextStyle(color: AppColors.ink, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('${area['state']} · ${area['river']} basin',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ]),
            ),
            StatusChip(label: '$risk risk', color: color),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _sheetStat('Model-estimated\nflood probability', '${area['probability_percent']}%', color)),
            const SizedBox(width: 10),
            Expanded(
                child: _sheetStat('Historical flood\nrate', '${area['historical_flood_rate_percent']}%', AppColors.ink)),
            const SizedBox(width: 10),
            Expanded(
                child: _sheetStat('Flood events /\nrecords',
                    '${area['historical_flood_events']}/${area['historical_records']}', AppColors.indigo)),
          ]),
          const SizedBox(height: 16),
          Text('Coordinates: ${area['latitude']}, ${area['longitude']}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 10),
          const Text(
            'Estimated from simulated historical-style station records. Not an official flood boundary or warning.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
        ]),
      ),
    );
  }

  Widget _sheetStat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10.5, height: 1.25)),
        ]),
      );

  Widget _header() => GradientHeader(
        eyebrow: 'Geospatial response intelligence',
        title: 'Flood risk, at a glance.',
        subtitle: _datasetNote,
        icon: Icons.map_rounded,
        footer: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in _levels) _legend(l, AppColors.risk(l), _count(l)),
        ]),
      );

  Widget _legend(String label, Color color, int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label · $count',
              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _map() {
    final areas = _visible;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(initialCenter: _indiaCenter, initialZoom: 4.4, minZoom: 3, maxZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.resqmatrix.mobile',
            ),
            CircleLayer(
              circles: [
                for (final a in areas)
                  CircleMarker(
                    point: _point(a),
                    radius: 14 + 22 * ((a['probability'] as num).toDouble()),
                    useRadiusInMeter: false,
                    color: AppColors.risk('${a['risk_level']}').withValues(alpha: .22),
                    borderColor: AppColors.risk('${a['risk_level']}').withValues(alpha: .6),
                    borderStrokeWidth: 1.2,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final a in areas)
                  Marker(
                    point: _point(a),
                    width: 22,
                    height: 22,
                    child: GestureDetector(
                      onTap: () => _showStation(a),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.risk('${a['risk_level']}'),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: '${a['station']}' == _selected ? 3.2 : 2),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(attributions: [TextSourceAttribution('© OpenStreetMap contributors')]),
          ],
        ),
        if (_loading)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .96), borderRadius: BorderRadius.circular(13)),
              child: const Row(children: [
                SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Expanded(
                    child: Text('Calculating station risk…',
                        style: TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 28,
          child: Column(children: [
            FloatingActionButton.small(
              heroTag: 'zoom_in',
              onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              child: const Icon(Icons.add_rounded),
            ),
            const SizedBox(height: 6),
            FloatingActionButton.small(
              heroTag: 'zoom_out',
              onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              child: const Icon(Icons.remove_rounded),
            ),
            const SizedBox(height: 6),
            FloatingActionButton.small(
              heroTag: 'recenter',
              onPressed: () => _mapController.move(_indiaCenter, 4.4),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              child: const Icon(Icons.my_location_rounded),
            ),
          ]),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(12)),
            child: Text('${areas.length} stations · tap a marker',
                style: const TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Widget _filters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in ['All', ..._levels])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f == 'All' ? 'All (${_areas.length})' : '$f (${_count(f)})'),
                selected: _filter == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ]),
      );

  List<Widget> _stationTiles() {
    final rows = _visible;
    if (rows.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No stations in this band.', style: TextStyle(color: AppColors.muted))),
        ),
      ];
    }
    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: '${rows[i]['station']}' == _selected ? AppColors.teal.withValues(alpha: .07) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showStation(rows[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: AppColors.risk('${rows[i]['risk_level']}'), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${rows[i]['station']}',
                          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13.5)),
                      Text('${rows[i]['state']} · ${rows[i]['river']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                    ]),
                  ),
                  Text('${rows[i]['probability_percent']}%',
                      style: TextStyle(
                          color: AppColors.risk('${rows[i]['risk_level']}'), fontWeight: FontWeight.w900, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _errorBanner() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InfoBanner(text: _error ?? '', icon: Icons.error_outline_rounded, color: AppColors.red),
      );

  static const _disclaimer =
      'Important: station risk is estimated by the model from simulated historical-style records. '
      'It is not a live measurement, an official flood boundary or a government alert.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Flood Risk Atlas'),
        actions: [
          IconButton(onPressed: _loadAreas, tooltip: 'Refresh map', icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: wide
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                    child: Column(children: [
                      _header(),
                      const SizedBox(height: 14),
                      if (_error != null) _errorBanner(),
                      Expanded(
                        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Expanded(child: _map()),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 360,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _filters(),
                              const SizedBox(height: 12),
                              Expanded(child: ListView(children: _stationTiles())),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      const Text(_disclaimer, style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35)),
                    ]),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      if (_error != null) _errorBanner(),
                      SizedBox(height: 380, child: _map()),
                      const SizedBox(height: 14),
                      _filters(),
                      const SizedBox(height: 12),
                      ..._stationTiles(),
                      const SizedBox(height: 8),
                      const Text(_disclaimer, style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35)),
                    ],
                  ),
          ),
        );
      }),
    );
  }
}
