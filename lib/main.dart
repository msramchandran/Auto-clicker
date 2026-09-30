import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:flutter/services.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RapidoAutoClickerApp());
}


// ─────────────────────────────────────────────────────────────────────────────
// App Root
// ─────────────────────────────────────────────────────────────────────────────
class RapidoAutoClickerApp extends StatelessWidget {
  const RapidoAutoClickerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Clicker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFCC00),
          onPrimary: Color(0xFF0F0F0F),
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Info Model
// ─────────────────────────────────────────────────────────────────────────────
class AppInfo {
  final String id;
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color cardColor;
  final String acceptButtonName;

  const AppInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.cardColor,
    required this.acceptButtonName,
  });
}

const List<AppInfo> kApps = [
  AppInfo(
    id: 'rapido',
    name: 'Rapido',
    emoji: '🛺',
    primaryColor: Color(0xFFFFCC00),
    cardColor: Color(0xFF2A2200),
    acceptButtonName: '"Accept" button',
  ),
  AppInfo(
    id: 'uber',
    name: 'Uber',
    emoji: '⬛',
    primaryColor: Color(0xFFFFFFFF),
    cardColor: Color(0xFF1A1A1A),
    acceptButtonName: '"Match" button',
  ),
  AppInfo(
    id: 'azhai',
    name: 'Azhai Partner',
    emoji: '🟢',
    primaryColor: Color(0xFF00C853),
    cardColor: Color(0xFF0D2B0D),
    acceptButtonName: '"ACCEPT ORDER" button',
  ),
  AppInfo(
    id: 'ola',
    name: 'OLA',
    emoji: '🟡',
    primaryColor: Color(0xFFF7C31C),
    cardColor: Color(0xFF2A1F00),
    acceptButtonName: '"Accept in X" button',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Location Profiles Model
// ─────────────────────────────────────────────────────────────────────────────
class LocationProfile {
  String id;
  String name;
  String locations;
  bool isActive;

  LocationProfile({
    required this.id,
    required this.name,
    required this.locations,
    this.isActive = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locations': locations,
        'isActive': isActive,
      };

  factory LocationProfile.fromJson(Map<String, dynamic> json) =>
      LocationProfile(
        id: json['id'],
        name: json['name'],
        locations: json['locations'],
        isActive: json['isActive'] ?? false,
      );
}

const _channel = MethodChannel('com.example.autoclicker/accessibility');

// ─────────────────────────────────────────────────────────────────────────────
// Home Page
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _serviceActive = false;
  bool _isHUDEnabled = true;
  bool _olaBlockerEnabled = true;
  bool _isAppPurchased = false;
  int _totalAccepted = 0;
  String _lastActivity = 'Waiting for ride requests...';

  // Per-app state
  final Map<String, bool> _appEnabled = {};
  final Map<String, String> _appLocation = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, RangeValues> _pickupRanges = {};
  final Map<String, RangeValues> _dropRanges = {};
  final Map<String, RangeValues> _priceRanges = {};
  
  // Location Profiles
  List<LocationProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final app in kApps) {
      _appEnabled[app.id] = false;
      _appLocation[app.id] = '';
      _controllers[app.id] = TextEditingController();
      _pickupRanges[app.id] = const RangeValues(0.0, 5.0);
      _dropRanges[app.id] = const RangeValues(0.0, 50.0);
      _priceRanges[app.id] = const RangeValues(0.0, 1500.0);
    }
    _loadAllStates();
    _setupMethodCallHandler();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkServiceStatus();
  }

  // ── Method Channel Handler (receive from native) ──────────────────────────

  void _setupMethodCallHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onRideAccepted') {
        final appName = call.arguments['appName'] as String? ?? '';
        final location = call.arguments['location'] as String? ?? '';
        setState(() {
          _totalAccepted++;
          _lastActivity = '✅ [$appName] Accepted → $location';
        });
      } else if (call.method == 'onRideDetected') {
        final appName = call.arguments['appName'] as String? ?? '';
        final info = call.arguments['info'] as String? ?? '';
        setState(() => _lastActivity = '⏳ [$appName] $info');
      }
    });
  }

  // ── Load / Save ───────────────────────────────────────────────────────────

  Future<void> _loadAllStates() async {
    await _checkServiceStatus();
    try {
      final result = await _channel.invokeMethod<Map>('getAllAppStates');
      if (result != null && mounted) {
        setState(() {
          for (final app in kApps) {
            _appEnabled[app.id] = result['${app.id}_enabled'] as bool? ?? false;
            _appLocation[app.id] = result['${app.id}_location'] as String? ?? '';
            final loc = _appLocation[app.id] ?? '';
            if (loc.isNotEmpty) _controllers[app.id]!.text = loc;
            double pMin = (result['${app.id}_pickup_min'] as num?)?.toDouble() ?? 0.0;
            double pMax = (result['${app.id}_pickup_max'] as num?)?.toDouble() ?? 5.0;
            if (pMax > 5.0) pMax = 5.0;
            _pickupRanges[app.id] = RangeValues(pMin, pMax);
            _dropRanges[app.id] = RangeValues(
              (result['${app.id}_drop_min'] as num?)?.toDouble() ?? 0.0,
              (result['${app.id}_drop_max'] as num?)?.toDouble() ?? 50.0,
            );
            _priceRanges[app.id] = RangeValues(
              (result['${app.id}_price_min'] as num?)?.toDouble() ?? 0.0,
              (result['${app.id}_price_max'] as num?)?.toDouble() ?? 1500.0,
            );
          }
          _totalAccepted = result['totalAccepted'] as int? ?? 0;
          _isHUDEnabled = result['isHUDEnabled'] as bool? ?? true;
          
          final profilesJson = result['locationProfiles'] as String? ?? '[]';
          try {
            final List decoded = jsonDecode(profilesJson);
            _profiles = decoded.map((e) => LocationProfile.fromJson(e)).toList();
          } catch (_) {
            _profiles = [];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _checkServiceStatus() async {
    try {
      final bool result = await _channel.invokeMethod('isServiceEnabled') ?? false;
      if (mounted) setState(() => _serviceActive = result);
    } catch (_) {
      if (mounted) setState(() => _serviceActive = false);
    }
  }

  Future<void> _setHUDEnabled(bool value) async {
    setState(() => _isHUDEnabled = value);
    try {
      await _channel.invokeMethod('setHUDEnabled', {'enabled': value});
    } catch (_) {}
  }

  // ── Profile Methods ──

  Future<void> _saveProfiles() async {
    final jsonStr = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    
    // Collect active locations
    final activeLocations = _profiles
        .where((p) => p.isActive)
        .map((p) => p.locations)
        .where((locs) => locs.trim().isNotEmpty)
        .join(',');

    try {
      await _channel.invokeMethod('setLocationProfiles', {
        'profilesJson': jsonStr,
        'activeLocations': activeLocations,
      });
    } catch (_) {}
  }

  void _addOrEditProfile([LocationProfile? profile]) {
    final isEditing = profile != null;
    final nameCtrl = TextEditingController(text: profile?.name ?? '');
    final locsCtrl = TextEditingController(text: profile?.locations ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(isEditing ? 'Edit Profile' : 'New Profile',
              style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Profile Name (e.g. Home)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locsCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Locations (comma separated)',
                  labelStyle: TextStyle(color: Colors.white54),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00)),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final locs = locsCtrl.text.trim();
                if (name.isEmpty || locs.isEmpty) return;
                
                setState(() {
                  if (isEditing) {
                    profile.name = name;
                    profile.locations = locs;
                  } else {
                    _profiles.add(LocationProfile(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      locations: locs,
                    ));
                  }
                });
                _saveProfiles();
                Navigator.pop(context);
              },
              child: const Text('SAVE', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  void _toggleProfile(LocationProfile profile, bool value) {
    setState(() => profile.isActive = value);
    _saveProfiles();
  }

  void _deleteProfile(LocationProfile profile) {
    setState(() => _profiles.remove(profile));
    _saveProfiles();
  }

  // ────────────────────────

  Future<void> _setAppEnabled(String appId, bool value) async {
    setState(() => _appEnabled[appId] = value);
    try {
      await _channel.invokeMethod('setAppEnabled', {'appId': appId, 'enabled': value});
    } catch (_) {}
  }

  Future<void> _saveAppLocation(String appId, String location) async {
    setState(() => _appLocation[appId] = location);
    try {
      await _channel.invokeMethod('setAppLocation', {'appId': appId, 'location': location});
    } catch (_) {}
  }

  Future<void> _saveAppFilters(String appId) async {
    try {
      await _channel.invokeMethod('setAppFilters', {
        'appId': appId,
        'pickupMin': _pickupRanges[appId]!.start,
        'pickupMax': _pickupRanges[appId]!.end,
        'dropMin': _dropRanges[appId]!.start,
        'dropMax': _dropRanges[appId]!.end,
        'priceMin': _priceRanges[appId]!.start,
        'priceMax': _priceRanges[appId]!.end,
      });
    } catch (_) {}
  }

  Future<void> _showCropBox(String appName) async {
    if (!_serviceActive) {
      _showSnack('First enable Accessibility Service!');
      return;
    }
    try {
      await _channel.invokeMethod('showCropBox', {'appName': appName});
      _showSnack('Open $appName app to set the crop box');
    } on PlatformException catch (e) {
      debugPrint("Failed to show crop box: '${e.message}'.");
    }
  }

  void _openAccessibilitySettings() {
    _channel.invokeMethod('openAccessibilitySettings');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildHeader(),
              const SizedBox(height: 16),
              _buildHUDToggleCard(),
              const SizedBox(height: 16),
              _buildProfilesCard(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Open Ride History Page', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RideHistoryPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildOverallStatusCard(),
              const SizedBox(height: 16),
              if (!_serviceActive) _buildAccessibilityWarningCard(),
              if (!_serviceActive) const SizedBox(height: 16),

              // ── 4 App Cards ──
              const Text(
                'Apps',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ...kApps.map((app) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAppCard(app),
                  )),

              const SizedBox(height: 8),
              _buildHowItWorksCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final activeCount = _appEnabled.values.where((v) => v).length;
    return Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Auto Clicker',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Ride Accept Automation',
                style: TextStyle(fontSize: 13, color: Color(0xFFB3B3B3))),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: activeCount > 0
                ? const Color(0xFF152A15)
                : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activeCount > 0
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFF444444),
            ),
          ),
          child: Text(
            '$activeCount Active',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: activeCount > 0
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF888888)),
          ),
        ),
      ],
    );
  }

  // ── HUD Toggle Card ────────────────────────────────────────────────────────

  Widget _buildHUDToggleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.layers, color: Color(0xFFFFCC00), size: 24),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Show Floating Icon',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text('Display status over other apps',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),
                ],
              ),
            ],
          ),
          Switch(
            value: _isHUDEnabled,
            onChanged: _setHUDEnabled,
            activeColor: Colors.black,
            activeTrackColor: const Color(0xFFFFCC00),
            inactiveThumbColor: const Color(0xFF888888),
            inactiveTrackColor: const Color(0xFF2A2A2A),
          ),
        ],
      ),
    );
  }

  // ── Profiles Card ──────────────────────────────────────────────────────────

  Widget _buildProfilesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: Color(0xFFFFCC00), size: 20),
                  SizedBox(width: 8),
                  Text('Location Profiles',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFFFFCC00)),
                onPressed: () => _addOrEditProfile(),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          if (_profiles.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('No profiles added. Add a profile for predefined locations.',
                style: TextStyle(fontSize: 12, color: Color(0xFFB3B3B3))),
          ] else ...[
            const SizedBox(height: 12),
            ..._profiles.map((p) => _buildProfileItem(p)),
          ]
        ],
      ),
    );
  }

  Widget _buildProfileItem(LocationProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(profile.locations,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB3B3B3)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16, color: Colors.white54),
            onPressed: () => _addOrEditProfile(profile),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 16, color: Colors.white54),
            onPressed: () => _deleteProfile(profile),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Switch(
            value: profile.isActive,
            onChanged: (v) => _toggleProfile(profile, v),
            activeColor: Colors.black,
            activeTrackColor: const Color(0xFFFFCC00),
            inactiveThumbColor: const Color(0xFF888888),
            inactiveTrackColor: const Color(0xFF444444),
          ),
        ],
      ),
    );
  }

  // ── Overall Status Card ───────────────────────────────────────────────────

  Widget _buildOverallStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
            children: [
              // Total accepted
              Expanded(
                child: Column(
                  children: [
                    Text('$_totalAccepted',
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFCC00))),
                    const Text('Total Accepted',
                        style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: const Color(0xFF2A2A2A)),
              // Last activity
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Last Activity',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),
                      const SizedBox(height: 4),
                      Text(
                        _lastActivity,
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ── Accessibility Warning ─────────────────────────────────────────────────

  Widget _buildAccessibilityWarningCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5A2020)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF44336), size: 20),
              SizedBox(width: 8),
              Text('Accessibility Service Required',
                  style: TextStyle(
                      color: Color(0xFFF44336),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '1️⃣ Open Settings → 2️⃣ Installed Apps → 3️⃣ Auto Clicker → 4️⃣ Enable',
            style: TextStyle(fontSize: 12, color: Color(0xFFB3B3B3)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 16),
              label: const Text('Open Accessibility Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: _openAccessibilitySettings,
            ),
          ),
        ],
      ),
    );
  }

  // ── Individual App Card ───────────────────────────────────────────────────

  Widget _buildAppCard(AppInfo app) {
    final isEnabled = _appEnabled[app.id] ?? false;
    final location = _appLocation[app.id] ?? '';
    final ctrl = _controllers[app.id]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isEnabled ? app.cardColor : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled ? app.primaryColor.withOpacity(0.5) : const Color(0xFF2A2A2A),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // App emoji + name
                Text(app.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text(
                        isEnabled
                            ? (location.isEmpty
                                ? '⚠️ Set drop location below'
                                : '🎯 Target: $location')
                            : 'Disabled',
                        style: TextStyle(
                            fontSize: 12,
                            color: isEnabled
                                ? (location.isEmpty
                                    ? const Color(0xFFFF9800)
                                    : app.primaryColor)
                                : const Color(0xFF666666)),
                      ),
                    ],
                  ),
                ),
                // Enable toggle
                Switch(
                  value: isEnabled,
                  onChanged: (val) {
                    if (val && !_serviceActive) {
                      _showSnack('First enable Accessibility Service!');
                      return;
                    }
                    _setAppEnabled(app.id, val);
                  },
                  activeColor: Colors.blue,
                  activeTrackColor: Colors.red.withOpacity(0.3),
                ),
              ],
            ),
          ),

          // ── Location input (always visible) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: ctrl,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Drop locations (e.g. Kovur, Porur, Guindy)',
                            hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF111111),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF333333)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF333333)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: app.primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              _saveAppLocation(app.id, val.trim());
                              _showSnack('${app.name}: Saved → ${val.trim()}');
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app.primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () {
                          final loc = ctrl.text.trim();
                          if (loc.isEmpty) {
                            _showSnack('Location enter பண்ணுங்கள்!');
                            return;
                          }
                          _saveAppLocation(app.id, loc);
                          _showSnack('${app.name}: Saved → $loc');
                          FocusScope.of(context).unfocus();
                        },
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // ── Distance Sliders ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pickup: ${_pickupRanges[app.id]!.start.toStringAsFixed(1)} - ${_pickupRanges[app.id]!.end.toStringAsFixed(1)} KM',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    trackHeight: 2,
                    activeTrackColor: app.primaryColor,
                    thumbColor: app.primaryColor,
                  ),
                  child: RangeSlider(
                    values: _pickupRanges[app.id]!,
                    min: 0.0,
                    max: 5.0,
                    divisions: 50,
                    labels: RangeLabels(
                      '${_pickupRanges[app.id]!.start.toStringAsFixed(1)} KM',
                      '${_pickupRanges[app.id]!.end.toStringAsFixed(1)} KM',
                    ),
                    onChanged: (vals) => setState(() => _pickupRanges[app.id] = vals),
                    onChangeEnd: (_) => _saveAppFilters(app.id),
                  ),
                ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Drop: ${_dropRanges[app.id]!.start.toStringAsFixed(1)} - ${_dropRanges[app.id]!.end.toStringAsFixed(1)} KM',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    trackHeight: 2,
                    activeTrackColor: app.primaryColor,
                    thumbColor: app.primaryColor,
                  ),
                  child: RangeSlider(
                    values: _dropRanges[app.id]!,
                    min: 0.0,
                    max: 100.0,
                    divisions: 100,
                    labels: RangeLabels(
                      '${_dropRanges[app.id]!.start.toStringAsFixed(1)} KM',
                      '${_dropRanges[app.id]!.end.toStringAsFixed(1)} KM',
                    ),
                    onChanged: (vals) => setState(() => _dropRanges[app.id] = vals),
                    onChangeEnd: (_) => _saveAppFilters(app.id),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price: ₹${_priceRanges[app.id]!.start.toStringAsFixed(0)} - ₹${_priceRanges[app.id]!.end.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    trackHeight: 2,
                    activeTrackColor: app.primaryColor,
                    thumbColor: app.primaryColor,
                  ),
                  child: RangeSlider(
                    values: _priceRanges[app.id]!,
                    min: 0.0,
                    max: 2000.0,
                    divisions: 200,
                    labels: RangeLabels(
                      '₹${_priceRanges[app.id]!.start.toStringAsFixed(0)}',
                      '₹${_priceRanges[app.id]!.end.toStringAsFixed(0)}',
                    ),
                    onChanged: (vals) => setState(() => _priceRanges[app.id] = vals),
                    onChangeEnd: (_) => _saveAppFilters(app.id),
                  ),
                ),
                
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showCropBox(app.name),
                  icon: const Icon(Icons.crop_free, size: 18),
                  label: const Text('Set Target Zone (Crop Box)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ],
            ),
          ),

          // ── Accept button info ──
          if (isEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: app.primaryColor.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                '🤖 Auto-clicks: ${app.acceptButtonName}',
                style: TextStyle(fontSize: 11, color: app.primaryColor.withOpacity(0.8)),
              ),
            ),
        ],
      ),
    );
  }

  // ── How It Works Card ─────────────────────────────────────────────────────

  Widget _buildHowItWorksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ℹ️ How it works',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          const Text(
            '• Each app has its own ON/OFF toggle\n'
            '• Enter multiple drop locations separated by commas (,)\n'
            '• E.g. "Kovur, Porur, Guindy" will accept any of those 3\n'
            '• Only ENABLED apps will be auto-clicked\n'
            '• Phone vibrates when trip accepted',
            style: TextStyle(fontSize: 12, color: Color(0xFFB3B3B3), height: 1.7),
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 20),
          const Text(
            'Rapido: com.rapido.rider\n'
            'Uber: com.ubercab.driver\n'
            'OLA: com.olacabs.oladriver\n'
            'Azhai: com.azhai.partner',
            style: TextStyle(
                fontSize: 10,
                color: Color(0xFF555555),
                fontFamily: 'monospace',
                height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF444444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ride History Page
// ─────────────────────────────────────────────────────────────────────────────

enum DataFilter { all, withData, withoutData }

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({super.key});

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {
  List<dynamic> _history = [];
  bool _loading = true;
  DataFilter _currentFilter = DataFilter.all;


  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final String result = await _channel.invokeMethod('getRideHistory') ?? '[]';
      setState(() {
        _history = jsonDecode(result);
        // Reverse so newest is at the top
        _history = _history.reversed.toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildList(String? filterApp) {
    final filtered = _history.where((item) {
      if (filterApp != null && item['appName'] != filterApp) return false;
      
      final double fare = (item['fare'] ?? -1.0).toDouble();
      final double pickupKm = (item['pickupKm'] ?? -1.0).toDouble();
      final double dropKm = (item['dropKm'] ?? -1.0).toDouble();
      
      final bool hasData = fare > 0 || pickupKm >= 0 || dropKm >= 0;
      
      if (_currentFilter == DataFilter.withData && !hasData) return false;
      if (_currentFilter == DataFilter.withoutData && hasData) return false;
      
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No rides found', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final bool isAccepted = item['status'] == 'ACCEPTED';
        final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0);
        final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        final appInfo = kApps.firstWhere(
          (a) => a.name == item['appName'],
          orElse: () => const AppInfo(
            id: 'unknown',
            name: 'Unknown',
            emoji: '❓',
            primaryColor: Colors.grey,
            cardColor: Colors.black,
            acceptButtonName: '',
          ),
        );

        // Real Data Extraction
        final double fare = (item['fare'] ?? -1.0).toDouble();
        final String priceStr = fare >= 0 ? '₹${fare.toStringAsFixed(0)}' : 'Data not received';
        
        final double tip = (item['tip'] ?? -1.0).toDouble();
        final String tipStr = tip > 0 ? '+ ₹${tip.toStringAsFixed(0)} Tip' : '';
        
        final double pickupKm = (item['pickupKm'] ?? -1.0).toDouble();
        final String pickupKmStr = pickupKm >= 0 ? '${pickupKm.toStringAsFixed(1)} km' : 'N/A';
        
        final double dropKm = (item['dropKm'] ?? -1.0).toDouble();
        final String dropKmStr = dropKm >= 0 ? '${dropKm.toStringAsFixed(1)} km' : 'N/A';
        
        final String rawPickupLoc = (item['pickupLocation'] ?? '').toString().trim();
        final String pickupLocation = rawPickupLoc.isNotEmpty ? rawPickupLoc : 'Data not received';
        
        final String rawDropLoc = (item['dropLocation'] ?? '').toString().trim();
        // Fallback to 'location' if dropLocation wasn't extracted (for backward compatibility)
        final String fallbackLoc = (item['location'] ?? '').toString().split('(').first.trim();
        final String dropLocation = rawDropLoc.isNotEmpty ? rawDropLoc : (fallbackLoc.isNotEmpty ? fallbackLoc : 'Data not received');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(
              color: isAccepted ? appInfo.primaryColor : Colors.grey.shade300,
              width: isAccepted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(appInfo.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      appInfo.name,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Price & Tip (Real Data)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    priceStr,
                    style: TextStyle(
                      color: fare >= 0 ? const Color(0xFF1E2026) : Colors.grey.shade500,
                      fontSize: fare >= 0 ? 32 : 18,
                      fontWeight: fare >= 0 ? FontWeight.w900 : FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                  if (tipStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        tipStr,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              
              // Timeline Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline graphic
                  Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E2026),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 50,
                        color: const Color(0xFF1E2026),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF1E2026), size: 18),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Timeline content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pickup
                        Text(
                          pickupKmStr,
                          style: const TextStyle(
                            color: Color(0xFF1E2026),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pickupLocation,
                          style: TextStyle(
                            color: pickupLocation == 'Data not received' ? Colors.red.shade400 : Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        // Drop
                        Text(
                          dropKmStr,
                          style: const TextStyle(
                            color: Color(0xFF1E2026),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dropLocation,
                          style: TextStyle(
                            color: dropLocation == 'Data not received' ? Colors.red.shade400 : Colors.grey.shade600,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Bottom Action Row
              Row(
                children: [
                  // Minus Button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: const Icon(Icons.remove, color: Color(0xFF1E2026)),
                  ),
                  const SizedBox(width: 12),
                  // Accept/Status Button
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isAccepted ? const Color(0xFFFFCC00) : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isAccepted ? 'ACCEPTED' : (item['status'] ?? 'DETECTED'),
                        style: TextStyle(
                          color: isAccepted ? const Color(0xFF1E2026) : Colors.grey.shade600,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$timeStr • ${item['appName']}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: kApps.length + 1, // All + each app
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ride History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1A1A1A),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFFFFCC00),
            labelColor: const Color(0xFFFFCC00),
            unselectedLabelColor: Colors.white54,
            tabs: [
              const Tab(text: 'All'),
              ...kApps.map((app) => Tab(text: app.name)),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<DataFilter>(
                        segments: const [
                          ButtonSegment(value: DataFilter.all, label: Text('All')),
                          ButtonSegment(value: DataFilter.withData, label: Text('Valid Data')),
                          ButtonSegment(value: DataFilter.withoutData, label: Text('No Data')),
                        ],
                        selected: {_currentFilter},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _currentFilter = newSelection.first;
                          });
                        },
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          selectedBackgroundColor: const Color(0xFFFFCC00),
                          selectedForegroundColor: Colors.black,
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Color(0xFF333333)),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildList(null),
                        ...kApps.map((app) => _buildList(app.name)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
