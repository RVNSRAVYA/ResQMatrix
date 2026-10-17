import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'screens/admin_screen.dart';
import 'screens/allocation_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/flood_map_screen.dart';
import 'screens/flood_prediction_screen.dart';
import 'screens/organization_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/triage_screen.dart';
import 'screens/weather_screen.dart';
import 'services/api_config.dart';
import 'theme/app_theme.dart';
import 'widgets/ui_kit.dart';

void main() {
  runApp(const ResQMatrixApp());
}

class ResQMatrixApp extends StatelessWidget {
  const ResQMatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQMatrix: Intelligent Emergency Prioritization and Resource Allocation Framework',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const DashboardScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation model
// ---------------------------------------------------------------------------

class _NavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String group;
  final String? tag;
  final Widget Function() builder;
  const _NavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.group,
    required this.builder,
    this.tag,
  });
}

final List<_NavItem> _navItems = [
  _NavItem(
    title: 'Priority triage',
    subtitle: 'Rank active emergencies with explainable 0–100 scores.',
    icon: Icons.ssid_chart_rounded,
    accent: AppColors.orange,
    group: 'Operations',
    tag: 'CORE',
    builder: () => const PriorityTriageScreen(),
  ),
  _NavItem(
    title: 'Resource allocation',
    subtitle: 'Match and allocate verified, available resources.',
    icon: Icons.hub_rounded,
    accent: AppColors.teal,
    group: 'Operations',
    tag: 'CORE',
    builder: () => const ResourceAllocationScreen(),
  ),
  _NavItem(
    title: 'Emergency request',
    subtitle: 'Send a request with urgency and location details.',
    icon: Icons.sos_rounded,
    accent: AppColors.red,
    group: 'Operations',
    builder: () => const EmergencyScreen(),
  ),
  _NavItem(
    title: 'Flood risk prediction',
    subtitle: 'ML flood probability from weather, river and terrain inputs.',
    icon: Icons.query_stats_rounded,
    accent: AppColors.indigo,
    group: 'Intelligence',
    tag: 'AI',
    builder: () => const FloodPredictionScreen(),
  ),
  _NavItem(
    title: 'Flood risk atlas',
    subtitle: 'Station-wise risk map built from historical records.',
    icon: Icons.map_rounded,
    accent: AppColors.green,
    group: 'Intelligence',
    tag: 'AI',
    builder: () => const FloodMapScreen(),
  ),
  _NavItem(
    title: 'Weather monitor',
    subtitle: 'Current conditions for response planning.',
    icon: Icons.cloud_rounded,
    accent: AppColors.blue,
    group: 'Intelligence',
    builder: () => const WeatherScreen(),
  ),
  _NavItem(
    title: 'Resource directory',
    subtitle: 'Browse verified emergency support categories.',
    icon: Icons.medical_services_rounded,
    accent: Color(0xFF2788A2),
    group: 'Network',
    builder: () => const ResourcesScreen(),
  ),
  _NavItem(
    title: 'Organization portal',
    subtitle: 'Register resources and record donations.',
    icon: Icons.apartment_rounded,
    accent: AppColors.violet,
    group: 'Network',
    builder: () => const OrganizationScreen(),
  ),
  _NavItem(
    title: 'Administrator console',
    subtitle: 'Monitor cases and verify resource submissions.',
    icon: Icons.admin_panel_settings_rounded,
    accent: AppColors.ink,
    group: 'Network',
    builder: () => const AdminScreen(),
  ),
];

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _apiOnline = false;
  bool _loading = true;
  int _activeRequests = 0;
  int _verifiedResources = 0;
  int _donationRecords = 0;
  Map<String, dynamic>? _model;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    try {
      final response =
          await http.get(Uri.parse('${ApiConfig.baseUrl}$path')).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    final results = await Future.wait([
      _get('/health'),
      _get('/emergency-requests'),
      _get('/resources'),
      _get('/donations'),
      _get('/model-info'),
    ]);
    if (!mounted) return;
    final health = results[0];
    final requests = List<dynamic>.from(results[1]?['requests'] ?? const []);
    final resources = List<dynamic>.from(results[2]?['resources'] ?? const []);
    final donations = List<dynamic>.from(results[3]?['donations'] ?? const []);
    setState(() {
      _apiOnline = health != null;
      _activeRequests =
          requests.where((r) => r['status'] != 'Resolved' && r['status'] != 'Cancelled').length;
      _verifiedResources = resources
          .where((r) =>
              r['status'] == 'Verified' && ((r['available_quantity'] ?? r['quantity'] ?? 0) as num) > 0)
          .length;
      _donationRecords = donations.length;
      _model = results[4];
      _loading = false;
    });
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen)).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1040;
      final content = _Content(
        wide: wide,
        loading: _loading,
        apiOnline: _apiOnline,
        activeRequests: _activeRequests,
        verifiedResources: _verifiedResources,
        donationRecords: _donationRecords,
        model: _model,
        onRefresh: _refresh,
        onOpen: _open,
      );
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: wide
              ? Row(children: [
                  _Sidebar(apiOnline: _apiOnline, loading: _loading, onOpen: _open),
                  Expanded(child: content),
                ])
              : content,
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Sidebar (wide screens)
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final bool apiOnline;
  final bool loading;
  final void Function(Widget) onOpen;
  const _Sidebar({required this.apiOnline, required this.loading, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<_NavItem>>{};
    for (final item in _navItems) {
      groups.putIfAbsent(item.group, () => []).add(item);
    }
    return Container(
      width: 268,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.inkDeep, Color(0xFF12304A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF14B8A6)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ResQMatrix',
                  style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -.5)),
              SizedBox(height: 2),
              Text('RESPONSE COORDINATION',
                  style: TextStyle(color: Color(0xFF8FB3C4), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            ]),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Text(entry.key.toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF6E93A6), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                ),
                for (final item in entry.value)
                  _SidebarTile(item: item, onTap: () => onOpen(item.builder())),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
          ),
          child: Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: loading ? AppColors.amber : (apiOnline ? AppColors.mint : AppColors.orange),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                loading ? 'Checking API…' : (apiOnline ? 'API connected' : 'API offline'),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  final _NavItem item;
  final VoidCallback onTap;
  const _SidebarTile({required this.item, required this.onTap});

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: _hover ? Colors.white.withValues(alpha: .08) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(widget.item.icon, size: 19, color: _hover ? AppColors.mint : const Color(0xFFA8C4D2)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.item.title,
                    style: TextStyle(
                      color: _hover ? Colors.white : const Color(0xFFD5E4EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              if (widget.item.tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(widget.item.tag!,
                      style: const TextStyle(
                          color: AppColors.mint, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: .6)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content
// ---------------------------------------------------------------------------

class _Content extends StatelessWidget {
  final bool wide;
  final bool loading;
  final bool apiOnline;
  final int activeRequests;
  final int verifiedResources;
  final int donationRecords;
  final Map<String, dynamic>? model;
  final Future<void> Function() onRefresh;
  final void Function(Widget) onOpen;

  const _Content({
    required this.wide,
    required this.loading,
    required this.apiOnline,
    required this.activeRequests,
    required this.verifiedResources,
    required this.donationRecords,
    required this.model,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final pagePad = w >= 900 ? 32.0 : 18.0;
      final inner = (w > 1240 ? 1180.0 : w) - pagePad * 2;
      return Center(
        child: SizedBox(
          width: w > 1240 ? 1180 : w,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pagePad, 18, pagePad, 36),
              children: [
                _TopBar(wide: wide, apiOnline: apiOnline, loading: loading, onRefresh: onRefresh),
                const SizedBox(height: 20),
                _Hero(
                  narrow: inner < 640,
                  model: model,
                  onPredict: () => onOpen(const FloodPredictionScreen()),
                  onEmergency: () => onOpen(const EmergencyScreen()),
                ),
                const SizedBox(height: 22),
                _KpiRow(
                  width: inner,
                  loading: loading,
                  apiOnline: apiOnline,
                  active: activeRequests,
                  verified: verifiedResources,
                  donations: donationRecords,
                ),
                const SizedBox(height: 28),
                const SectionTitle(
                  title: 'Operations workspaces',
                  subtitle: 'Tools for citizens, organizations and response coordinators.',
                ),
                _WorkspaceGrid(width: inner, onOpen: onOpen),
                const SizedBox(height: 26),
                _ModelPanel(model: model, loading: loading, width: inner),
                const SizedBox(height: 22),
                const InfoBanner(
                  icon: Icons.verified_user_outlined,
                  color: AppColors.teal,
                  text:
                      'Decision-support notice: priority scores and flood predictions are estimates. '
                      'Verify requests and follow official emergency guidance; this app is not an official warning system.',
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'ResQMatrix  ·  Intelligent Emergency Prioritization and Resource Allocation Framework',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8492A3), fontSize: 10.5, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  final bool wide;
  final bool apiOnline;
  final bool loading;
  final Future<void> Function() onRefresh;
  const _TopBar({required this.wide, required this.apiOnline, required this.loading, required this.onRefresh});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';
    return Row(children: [
      if (!wide) ...[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.ink, Color(0xFF236071)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 11),
      ],
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(wide ? 'Command center' : 'ResQMatrix',
              style: const TextStyle(
                  color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const SizedBox(height: 2),
          Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: loading ? AppColors.amber : (apiOnline ? AppColors.teal : AppColors.orange),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(loading ? 'CHECKING' : (apiOnline ? 'API CONNECTED' : 'API OFFLINE'),
              style: const TextStyle(color: AppColors.ink, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: .6)),
        ]),
      ),
      const SizedBox(width: 6),
      IconButton.filledTonal(
        onPressed: onRefresh,
        tooltip: 'Refresh overview',
        icon: const Icon(Icons.refresh_rounded, size: 20),
      ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  final bool narrow;
  final Map<String, dynamic>? model;
  final VoidCallback onPredict;
  final VoidCallback onEmergency;
  const _Hero({required this.narrow, required this.model, required this.onPredict, required this.onEmergency});

  @override
  Widget build(BuildContext context) {
    final num? accuracy = model?['accuracy_percent'] is num ? model!['accuracy_percent'] as num : null;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x2611263D), blurRadius: 32, offset: Offset(0, 14))],
      ),
      child: Stack(children: [
        Positioned(
          right: -46,
          top: -64,
          child: Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .06), width: 34),
            ),
          ),
        ),
        Positioned(
          right: 60,
          bottom: -90,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.mint.withValues(alpha: .10)),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(narrow ? 22 : 32),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: .12)),
                  ),
                  child: const Text('INTELLIGENT EMERGENCY FRAMEWORK',
                      style: TextStyle(
                          color: Color(0xFFB9F5E8), fontSize: 9.5, letterSpacing: 1, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 16),
                Text(
                  narrow ? 'Every minute\nmatters.' : 'Every minute matters.\nCoordinate faster. Respond smarter.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: narrow ? 27 : 34,
                      letterSpacing: -1,
                      height: 1.08,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prioritize needs with explainable scoring, connect verified resources and anticipate flood risk with a model trained on historical records.',
                  style: TextStyle(color: Color(0xFFD3E4EC), height: 1.5, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(
                    onPressed: onEmergency,
                    icon: const Icon(Icons.add_alert_rounded, size: 18),
                    label: const Text('Raise emergency'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.mint, foregroundColor: AppColors.ink),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPredict,
                    icon: const Icon(Icons.query_stats_rounded, size: 18),
                    label: const Text('Estimate flood risk'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: .3)),
                    ),
                  ),
                ]),
              ]),
            ),
            if (!narrow) ...[
              const SizedBox(width: 28),
              Container(
                width: 168,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: .12)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('MODEL ACCURACY',
                      style: TextStyle(
                          color: Color(0xFF9BE7DA), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: accuracy != null ? (accuracy / 100).clamp(0.0, 1.0).toDouble() : 0.0,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          color: AppColors.mint,
                          backgroundColor: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      Text(accuracy != null ? '${accuracy.toStringAsFixed(1)}%' : '—',
                          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chronological hold-out\n2020 – 2025',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFC3D8E2), fontSize: 10.5, height: 1.35)),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final double width;
  final bool loading;
  final bool apiOnline;
  final int active;
  final int verified;
  final int donations;
  const _KpiRow({
    required this.width,
    required this.loading,
    required this.apiOnline,
    required this.active,
    required this.verified,
    required this.donations,
  });

  @override
  Widget build(BuildContext context) {
    final columns = width >= 900 ? 4 : 2;
    const gap = 12.0;
    final tile = (width - gap * (columns - 1)) / columns;
    String v(Object n) => loading ? '—' : '$n';
    final tiles = [
      _Kpi('Active requests', v(active), Icons.campaign_rounded, AppColors.orange),
      _Kpi('Verified resources', v(verified), Icons.verified_user_rounded, AppColors.teal),
      _Kpi('Donation records', v(donations), Icons.volunteer_activism_rounded, AppColors.indigo),
      _Kpi('API status', loading ? 'Checking' : (apiOnline ? 'Online' : 'Offline'),
          apiOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, apiOnline ? AppColors.green : AppColors.red),
    ];
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final t in tiles) SizedBox(width: tile, child: _KpiTile(kpi: t))],
    );
  }
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
}

class _KpiTile extends StatelessWidget {
  final _Kpi kpi;
  const _KpiTile({required this.kpi});

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          IconBadge(icon: kpi.icon, color: kpi.color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kpi.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.ink, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.7)),
              const SizedBox(height: 2),
              Text(kpi.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );
}

class _WorkspaceGrid extends StatelessWidget {
  final double width;
  final void Function(Widget) onOpen;
  const _WorkspaceGrid({required this.width, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final columns = width >= 900 ? 3 : (width >= 560 ? 2 : 1);
    const gap = 14.0;
    final tile = (width - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final item in _navItems)
          SizedBox(width: tile, child: _WorkspaceCard(item: item, onTap: () => onOpen(item.builder()))),
      ],
    );
  }
}

class _WorkspaceCard extends StatefulWidget {
  final _NavItem item;
  final VoidCallback onTap;
  const _WorkspaceCard({required this.item, required this.onTap});

  @override
  State<_WorkspaceCard> createState() => _WorkspaceCardState();
}

class _WorkspaceCardState extends State<_WorkspaceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _hover ? item.accent.withValues(alpha: .45) : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: _hover ? item.accent.withValues(alpha: .16) : const Color(0x080D2036),
              blurRadius: _hover ? 26 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconBadge(icon: item.icon, color: item.accent, size: 48),
                  const Spacer(),
                  if (item.tag != null) ...[
                    StatusChip(label: item.tag!, color: item.accent),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.arrow_outward_rounded, size: 18, color: _hover ? item.accent : AppColors.muted),
                ]),
                const SizedBox(height: 16),
                Text(item.title,
                    style: const TextStyle(
                        color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                const SizedBox(height: 6),
                Text(item.subtitle,
                    style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 12.2)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModelPanel extends StatelessWidget {
  final Map<String, dynamic>? model;
  final bool loading;
  final double width;
  const _ModelPanel({required this.model, required this.loading, required this.width});

  String _years() {
    final range = model?['date_range'];
    if (range is List && range.length == 2) {
      return '${range[0].toString().substring(0, 4)}–${range[1].toString().substring(0, 4)}';
    }
    return '—';
  }

  String _pct(dynamic metrics, String key) {
    if (metrics is Map && metrics[key] is num) {
      return '${((metrics[key] as num) * 100).toStringAsFixed(1)}%';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = model?['evaluation'];
    final num? rows = model?['dataset_rows'] is num ? model!['dataset_rows'] as num : null;
    final stats = [
      ('Historical records', rows != null ? _thousands(rows.toInt()) : '—', Icons.dataset_rounded, AppColors.indigo),
      ('Coverage', _years(), Icons.date_range_rounded, AppColors.blue),
      ('Stations', model?['stations'] == null ? '—' : '${model!['stations']}', Icons.sensors_rounded, AppColors.teal),
      ('Precision', _pct(evaluation, 'precision'), Icons.gps_fixed_rounded, AppColors.green),
      ('Recall', _pct(evaluation, 'recall'), Icons.radar_rounded, AppColors.orange),
      ('F1 score', _pct(evaluation, 'f1'), Icons.balance_rounded, AppColors.violet),
    ];
    final columns = width >= 900 ? 6 : (width >= 560 ? 3 : 2);
    const gap = 10.0;
    final tile = (width - 36 - gap * (columns - 1)) / columns;
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(icon: Icons.psychology_alt_rounded, color: AppColors.indigo, size: 42),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Flood-prediction model',
                  style: TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -.3)),
              SizedBox(height: 2),
              Text('Logistic Regression · trained on historical records, tested on unseen later years',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5)),
            ]),
          ),
          if (loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            StatusChip(
              label: model == null ? 'Offline' : '${model!['accuracy_percent']}% accuracy',
              color: model == null ? AppColors.orange : AppColors.green,
              icon: model == null ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
            ),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in stats)
              Container(
                width: tile,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(s.$3, size: 17, color: s.$4),
                  const SizedBox(height: 8),
                  Text(s.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(s.$1, style: const TextStyle(color: AppColors.muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'The bundled records are simulated historical-style data. Accuracy describes this dataset only and is not evidence of real-world forecast skill.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
        ),
      ]),
    );
  }

  static String _thousands(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}
