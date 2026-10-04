import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'app_store.dart';
import 'config.dart';
import 'incident_detail.dart';
import 'report_flow.dart';
import 'risk_lab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _ShellState();
}

class _ShellState extends State<AppShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final citizen = store.role == AppRole.citizen;
    final labels = [
      store.t(
        citizen ? 'My reports' : 'Incident queue',
        citizen ? 'मेरी रिपोर्टें' : 'घटना सूची',
      ),
      store.t('Map', 'मानचित्र'),
      store.t('Updates', 'अपडेट'),
      store.t('Overview', 'अवलोकन'),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              appTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              '${store.user?['name']} · ${store.user?['role']}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: store.language,
            icon: const Icon(Icons.translate),
            tooltip: 'Hindi / English',
          ),
          IconButton(
            onPressed: store.refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync server records',
          ),
          IconButton(
            onPressed: () async {
              await store.logout();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: Column(
        children: [
          if (store.error != null)
            MaterialBanner(
              content: Text(store.error!, style: const TextStyle(fontSize: 12)),
              actions: [
                TextButton(
                  onPressed: store.refresh,
                  child: Text(store.t('Retry', 'फिर कोशिश करें')),
                ),
              ],
            ),
          Expanded(
            child: [
              _IncidentQueue(store: store),
              _IncidentMap(store: store),
              _Updates(store: store),
              _Overview(store: store),
            ][_tab],
          ),
        ],
      ),
      floatingActionButton: citizen && _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ReportFlowScreen(),
                ),
              ),
              backgroundColor: GovColors.gold,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(store.t('Report', 'रिपोर्ट')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (var i = 0; i < labels.length; i++)
            NavigationDestination(
              icon: Icon(
                [
                  Icons.water_damage_outlined,
                  Icons.map_outlined,
                  Icons.notifications_outlined,
                  Icons.dashboard_outlined,
                ][i],
              ),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}

class _IncidentQueue extends StatelessWidget {
  final AppStore store;
  const _IncidentQueue({required this.store});
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: store.refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: GovColors.navy,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.t(
                  'A clear path from report to closure',
                  'रिपोर्ट से समापन तक स्पष्ट प्रक्रिया',
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                store.t(
                  'Photo · officer review · priority · crew response · verified proof',
                  'फोटो · अधिकारी समीक्षा · प्राथमिकता · क्रू प्रतिक्रिया · सत्यापित प्रमाण',
                ),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          store.t('Current incident records', 'वर्तमान घटना रिकॉर्ड'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (store.incidents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 35),
            child: Text(
              store.t(
                'No incidents in your current account view.',
                'आपके वर्तमान खाते में कोई घटना नहीं।',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        for (final incident in store.incidents)
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Icon(
                Icons.water_damage_outlined,
                color: bandColor(incident['band'] as String),
              ),
              title: Text(
                incident['location'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${(incident['status'] as String).replaceAll("_", " ")}\n${incident['report_count']} report(s)',
              ),
              isThreeLine: true,
              trailing: Text(
                'P ${incident['priority_score']}\n/100',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: GovColors.gold,
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => IncidentDetail(id: incident['id'] as String),
                ),
              ),
            ),
          ),
        if (store.pending.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            store.t(
              'Queued securely; awaiting server receipt',
              'सुरक्षित कतार; सर्वर प्राप्ति बाकी',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final report in store.pending)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.cloud_upload_outlined,
                  color: GovColors.gold,
                ),
                title: Text(report.fields['location']!),
                subtitle: Text(report.fields['captured_at']!),
              ),
            ),
          OutlinedButton.icon(
            onPressed: store.refresh,
            icon: const Icon(Icons.sync),
            label: Text(
              store.t('Retry queued reports', 'कतारबद्ध रिपोर्ट फिर भेजें'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _IncidentMap extends StatelessWidget {
  final AppStore store;
  const _IncidentMap({required this.store});
  @override
  Widget build(BuildContext context) {
    final incidents = store.incidents
        .where((i) => i['status'] != 'CLOSED')
        .toList();
    final center = incidents.isEmpty
        ? const LatLng(28.4595, 77.0262)
        : LatLng(
            (incidents.first['lat'] as num).toDouble(),
            (incidents.first['lon'] as num).toDouble(),
          );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            store.t(
              'Report locations · colour is priority band, not flood extent',
              'रिपोर्ट स्थान · रंग प्राथमिकता वर्ग है, बाढ़ का फैलाव नहीं',
            ),
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.nalanetra.nalanetra_floodgrid',
              ),
              MarkerLayer(
                markers: [
                  for (final i in incidents)
                    Marker(
                      point: LatLng(
                        (i['lat'] as num).toDouble(),
                        (i['lon'] as num).toDouble(),
                      ),
                      width: 42,
                      height: 42,
                      child: IconButton(
                        icon: Icon(
                          Icons.location_on,
                          size: 33,
                          color: bandColor(i['band'] as String),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                IncidentDetail(id: i['id'] as String),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Updates extends StatelessWidget {
  final AppStore store;
  const _Updates({required this.store});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      Text(
        store.t('Workflow updates', 'प्रक्रिया अपडेट'),
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      if (store.notifications.isEmpty)
        Text(
          store.t(
            'No role-scoped updates yet.',
            'अभी आपकी भूमिका का कोई अपडेट नहीं।',
          ),
        ),
      for (final n in store.notifications)
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.notifications_outlined,
              color: GovColors.gold,
            ),
            title: Text(n['title'] as String),
            subtitle: Text('${n['body']}\n${n['at']} · ${n['push_status']}'),
            isThreeLine: true,
          ),
        ),
    ],
  );
}

class _Overview extends StatelessWidget {
  final AppStore store;
  const _Overview({required this.store});
  @override
  Widget build(BuildContext context) {
    final total = store.incidents.length,
        closed = store.incidents.where((i) => i['status'] == 'CLOSED').length;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          store.t('Response overview', 'प्रतिक्रिया अवलोकन'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          store.t(
            'Accessible account records; these are not city-wide impact measurements.',
            'आपके खाते के रिकॉर्ड; ये पूरे शहर के प्रभाव का माप नहीं हैं।',
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$closed / $total ${store.t("incidents closed by officer", "घटनाएं अधिकारी द्वारा बंद")}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: total == 0 ? 0 : closed / total,
                  minHeight: 10,
                  color: GovColors.ok,
                ),
              ],
            ),
          ),
        ),
        for (final status in [
          'SUBMITTED',
          'VERIFIED',
          'DISPATCHED',
          'ON_SITE',
          'WORK_IN_PROGRESS',
          'AWAITING_REVIEW',
          'CLOSED',
        ])
          Card(
            child: ListTile(
              title: Text(status.replaceAll('_', ' ')),
              trailing: Text(
                '${store.incidents.where((i) => i['status'] == status).length}',
                style: const TextStyle(
                  fontSize: 21,
                  color: GovColors.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const RiskLab()),
          ),
          icon: const Icon(Icons.science_outlined),
          label: Text(
            store.t('Inspect risk fixture experiment', 'जोखिम प्रयोग देखें'),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          store.t(
            'Live radar, calibrated flood-depth models and municipal asset inventory require operator integration. In-app workflow updates are connected; FCM device enrolment is separate integration work.',
            'लाइव रडार, स्थानीय बाढ़-गहराई मॉडल और नगर निगम संसाधन सूची को जोड़ना बाकी है। ऐप में प्रक्रिया अपडेट जुड़े हैं; FCM डिवाइस पंजीकरण अलग एकीकरण है।',
          ),
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
      ],
    );
  }
}
