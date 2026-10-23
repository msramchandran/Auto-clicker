import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final String? initialDriverId;
  final bool? initialIsDailyLimitActive;
  final int? initialDailyLimitEndTime;
  final bool? initialIsAdRequired;
  final double? initialAdHoursRemaining;

  const ProfilePage({
    super.key,
    this.initialDriverId,
    this.initialIsDailyLimitActive,
    this.initialDailyLimitEndTime,
    this.initialIsAdRequired,
    this.initialAdHoursRemaining,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String? _errorMessage;

  // Profile Basic Info
  String _driverId = '';
  String _name = 'Driver';
  String _phone = '-';
  String _vehicleNumber = '-';
  String _profilePic = '';
  int _totalTrips = 0;
  bool _hasPaid = false;
  bool _isBlocked = false;
  String _appVersion = '1.0.3';

  // 12-Hour Daily Limit Block Info
  bool _isDailyLimitActive = false;
  int _dailyLimitEndTime = 0;
  int _dailyLimitRemainingMinutes = 0;
  int _dailyTripCount = 0;
  int _dailyEarnings = 0;

  // 6-Hour AD Pass Info
  bool _isAdPassActive = false;
  double _adPassHoursRemaining = 0.0;
  int _adWatchCount = 0;
  String? _lastAdWatchedAt;

  static const String _backendUrl = 'http://43.205.135.3:3000';

  @override
  void initState() {
    super.initState();
    _applyInitialProps();
    _fetchProfile();
  }

  void _applyInitialProps() {
    if (widget.initialDriverId != null && widget.initialDriverId!.isNotEmpty) {
      _driverId = widget.initialDriverId!;
    }
    if (widget.initialIsDailyLimitActive != null) {
      _isDailyLimitActive = widget.initialIsDailyLimitActive!;
    }
    if (widget.initialDailyLimitEndTime != null && widget.initialDailyLimitEndTime! > 0) {
      _dailyLimitEndTime = widget.initialDailyLimitEndTime!;
      final diff = _dailyLimitEndTime - DateTime.now().millisecondsSinceEpoch;
      _dailyLimitRemainingMinutes = diff > 0 ? (diff / 60000).ceil() : 0;
    }
    if (widget.initialIsAdRequired != null) {
      _isAdPassActive = !widget.initialIsAdRequired!;
      _adPassHoursRemaining = widget.initialAdHoursRemaining ?? 0.0;
    }
  }

  Future<void> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driverId') ?? _driverId;
    final deviceId = prefs.getString('deviceId') ?? '';

    String appVersion = '1.0.3';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
    } catch (_) {}

    if (driverId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Driver ID கிடைக்கவில்லை. தயவுசெய்து மீண்டும் Login பண்ணவும்.';
        });
      }
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_backendUrl/api/clicker-profile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'driver_id': driverId,
              'device_id': deviceId,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        _forceLogout('வேறு Device-ல் Login செய்யப்பட்டுள்ளது.');
        return;
      }

      final data = jsonDecode(response.body);
      if (data['status'] == 'logout') {
        _forceLogout(data['message'] ?? 'பழைய Version! புதிய App-ஐ Download செய்யவும்.');
        return;
      }
      if (data['status'] == 'success' && data['profile'] != null) {
        final p = data['profile'];
        if (mounted) {
          setState(() {
            _name = (p['name'] != null && p['name'].toString().trim().isNotEmpty)
                ? p['name']
                : 'Driver';
            _phone = p['phone'] ?? '-';
            _driverId = p['clickerId'] ?? driverId;
            _profilePic = p['profilePic'] ?? '';
            _vehicleNumber = p['vehicleNumber'] ?? 'N/A';
            _totalTrips = (p['acceptedTrips'] as num?)?.toInt() ?? 0;
            _hasPaid = p['hasPaidForClicker'] ?? false;
            _isBlocked = p['isBlocked'] ?? false;
            _appVersion = p['appVersion'] ?? appVersion;

            // 12-Hour Block Info
            _isDailyLimitActive = p['isDailyLimitActive'] ?? false;
            _dailyLimitEndTime = (p['dailyLimitEndTime'] as num?)?.toInt() ?? 0;
            _dailyLimitRemainingMinutes = (p['dailyLimitRemainingMinutes'] as num?)?.toInt() ?? 0;
            _dailyTripCount = (p['dailyTripCount'] as num?)?.toInt() ?? 0;
            _dailyEarnings = (p['dailyEarnings'] as num?)?.toInt() ?? 0;

            // 6-Hour AD Pass Info
            _isAdPassActive = p['isAdPassActive'] ?? false;
            _adPassHoursRemaining = (p['adPassHoursRemaining'] as num?)?.toDouble() ?? 0.0;
            _lastAdWatchedAt = p['lastAdWatchedAt'];
            _adWatchCount = (p['adWatchCount'] as num?)?.toInt() ?? 0;

            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = data['message'] ?? 'Profile விபரங்களை ஏற்ற முடியவில்லை.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network Error: Internet இணைப்பை சரிபார்க்கவும்.';
        });
      }
    }
  }

  Future<void> _openAzhaiPartnerForAd() async {
    final uri = Uri.parse('azhai://watch-ad?driverId=$_driverId');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Azhai Partner app-ஐ திறக்க முடியவில்லை. App install ஆகி உள்ளதா என பார்க்கவும்.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label நகலெடுக்கப்பட்டது (Copied)!'),
        backgroundColor: const Color(0xFF00C853),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Logout உறுதிப்படுத்தவும்', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('நிச்சயமாக வெளியேற விரும்புகிறீர்களா?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ரத்து', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('வெளியேறு', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('driverId');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _forceLogout(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  String _formatBlockRemainingTime(int minutes) {
    if (minutes <= 0) return 'முடிவடையும் நிலையில் உள்ளது';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '$hours மணி நேரம் $mins நிமிடங்கள்';
    }
    return '$mins நிமிடங்கள்';
  }

  String _formatLastAdTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'இன்னும் பார்க்கவில்லை';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'My Profile & Status',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFFCC00)),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchProfile();
            },
          ),
        ],
      ),
      body: _isLoading && _name == 'Driver' && _driverId.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFFCC00)),
                  SizedBox(height: 16),
                  Text('Profile ஏற்றப்படுகிறது...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFFFFCC00),
              backgroundColor: const Color(0xFF1A1A1A),
              onRefresh: _fetchProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Avatar & Basic Info Card
                    _buildHeaderCard(),
                    const SizedBox(height: 16),

                    // 🎬 Card 1: 6-Hour AD Pass Status
                    _buildAdPassCard(),
                    const SizedBox(height: 16),

                    // ⏱️ Card 2: 12-Hour Daily Limit Block Status
                    _buildDailyLimitCard(),
                    const SizedBox(height: 16),

                    // 📊 Card 3: Account & Stats
                    _buildAccountStatsCard(),
                    const SizedBox(height: 24),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B1515),
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout, size: 20),
                        label: const Text(
                          'LOGOUT (வெளியேறு)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Header Card
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFF2A2A2A),
            backgroundImage: _profilePic.isNotEmpty ? NetworkImage(_profilePic) : null,
            child: _profilePic.isEmpty
                ? const Icon(Icons.person, size: 48, color: Color(0xFFFFCC00))
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            _name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (_phone.isNotEmpty && _phone != '-')
            Text(
              '📱 $_phone',
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          const SizedBox(height: 10),

          // Driver ID Pill with Copy button
          InkWell(
            onTap: () => _copyToClipboard(_driverId, 'Driver ID'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.badge, color: Color(0xFFFFCC00), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'ID: $_driverId',
                    style: const TextStyle(
                      color: Color(0xFFFFCC00),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, color: Colors.white54, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Card 1: 6-Hour AD Pass Status
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAdPassCard() {
    final bool isActive = _isAdPassActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF00C853).withOpacity(0.5) : Colors.orangeAccent.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_fill,
                color: isActive ? const Color(0xFF00C853) : Colors.orangeAccent,
                size: 26,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '6 மணி நேர AD பாஸ் (AD Pass)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? const Color(0xFF00C853) : Colors.orangeAccent).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? const Color(0xFF00C853) : Colors.orangeAccent,
                  ),
                ),
                child: Text(
                  isActive ? '🟢 Active' : '🔴 Expired',
                  style: TextStyle(
                    color: isActive ? const Color(0xFF00C853) : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isActive
                ? '✅ AutoClicker பயன்படுத்த AD பாஸ் உள்ளது. அடுத்த விளம்பரத்திற்கு முன் இன்னும் ${_adPassHoursRemaining.toStringAsFixed(1)} மணி நேரம் பயன்படுத்தலாம்.'
                : '⚠️ AD பாஸ் காலாவதியானது! AutoClicker தொடர்ந்து வேலை செய்ய Azhai Partner செயலியில் விளம்பரம் பார்க்கவும்.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Details row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('மீதமுள்ள நேரம்', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? '${_adPassHoursRemaining.toStringAsFixed(1)} hrs' : '0 hrs (தேவை)',
                      style: TextStyle(
                        color: isActive ? const Color(0xFF00C853) : Colors.orangeAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('பார்த்த விளம்பரங்கள்', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '$_adWatchCount முறை',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_lastAdWatchedAt != null && _lastAdWatchedAt!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'கடைசியாக பார்த்த நேரம்: ${_formatLastAdTime(_lastAdWatchedAt)}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],

          // Button to watch AD if expired
          if (!isActive) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text(
                  '▶️ விளம்பரம் பார் (Azhai Partner)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _openAzhaiPartnerForAd,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Card 2: 12-Hour Daily Limit Block Status
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDailyLimitCard() {
    final bool isBlocked = _isDailyLimitActive;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? Colors.redAccent.withOpacity(0.6) : const Color(0xFF00C853).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBlocked ? Icons.block : Icons.check_circle,
                color: isBlocked ? Colors.redAccent : const Color(0xFF00C853),
                size: 26,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '12 மணி நேர தினசரி வரம்பு (Daily Limit)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isBlocked ? Colors.redAccent : const Color(0xFF00C853)).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBlocked ? Colors.redAccent : const Color(0xFF00C853),
                  ),
                ),
                child: Text(
                  isBlocked ? '🚫 Blocked' : '✅ Available',
                  style: TextStyle(
                    color: isBlocked ? Colors.redAccent : const Color(0xFF00C853),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isBlocked
                ? '⚠️ இன்றைய தினசரி வரம்பு முடிவடைந்தது (6 Trips அல்லது ₹1000). Block தானாக நீங்கும் அல்லது Admin நீக்கலாம்.'
                : '✅ Daily Limit அனுமதி உள்ளது. நீங்கள் வழக்கம் போல் Trips எடுக்கலாம்.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),

          // Block Countdown or Today's Stats
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isBlocked
                ? Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Block நீங்க மீதமுள்ள நேரம்', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              _formatBlockRemainingTime(_dailyLimitRemainingMinutes),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('இன்றைய Trips', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '$_dailyTripCount / 6',
                            style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: const Color(0xFF333333)),
                      Column(
                        children: [
                          const Text('இன்றைய வருமானம்', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '₹$_dailyEarnings / ₹1000',
                            style: const TextStyle(color: Color(0xFFFFCC00), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Card 3: Account & Stats
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildAccountStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'கணக்கு விபரங்கள் (Account Details)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.check_circle_outline, '$_totalTrips', 'மொத்த Trips'),
              _buildStatItem(Icons.directions_car, _vehicleNumber, 'வாகன எண்'),
              _buildStatItem(
                Icons.verified,
                _hasPaid ? 'Paid Pro' : 'Standard',
                'Status',
                color: _hasPaid ? const Color(0xFF00C853) : const Color(0xFFFFCC00),
              ),
            ],
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('App Version', style: TextStyle(color: Colors.white54, fontSize: 13)),
              Text('v$_appVersion', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_isBlocked) ...[
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Admin Account Status', style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text('🚫 Account Blocked', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, {Color color = const Color(0xFFFFCC00)}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}
