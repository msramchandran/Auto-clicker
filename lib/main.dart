import 'package:app_links/app_links.dart';

import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart';

import 'package:gal/gal.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:url_launcher/url_launcher.dart';

import 'login_page.dart';

import 'profile_page.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:speech_to_text/speech_to_text.dart' as stt;



bool isTamil = false;



final Map<String, String> _ta = {

  'Auto Clicker': 'ஆட்டோ கிளிக்கர்',

  'Open Profile': 'புரொஃபைல்',

  'Ride Accept Automation': 'தானாக சவாரி ஏற்கும் வசதி',

  'Active': 'செயலில்',

  'Show Floating Icon': 'மிதக்கும் ஐகானைக் காட்டு',

  'Display status over other apps': 'மற்ற ஆப்கள் மீதும் நிலையைக் காட்டு',

  'Location Profiles': 'லொகேஷன் ப்ரொஃபைல்ஸ்',

  'No profiles added. Add a profile for predefined locations.': 'இன்னும் ப்ரொஃபைல் சேர்க்கப்படவில்லை. மேலே புதிய ப்ரொஃபைலைச் சேர்க்கவும்.',

  'Accepted': 'ஏற்றுக்கொண்டவை',

  'Skipped': 'தவிர்த்தவை',

  'Earnings': 'வருமானம்',

  'Status': 'நிலை',

  'Open Ride History Page': 'சவாரி வரலாற்றைத் திறக்க',

  'Apps': 'ஆப்கள்',

  'Enable Auto Click': 'ஆட்டோ கிளிக்கரை ஆன் செய்',

  'Pickup Distance': 'பிக்-அப் தூரம்',

  'Drop Distance': 'ட்ராப் தூரம்',

  'Price Range': 'கட்டணம்',

  'Set Crop Box': 'க்ராப் பாக்ஸ் (Crop Box) அமை',

  'Save Filters': 'சேமி',

  'How It Works': 'இது எப்படி இயங்குகிறது?',

  'First enable Accessibility Service!': 'முதலில் Accessibility Service-ஐ ஆன் செய்யவும்!',

  'Enable Accessibility Service': 'Accessibility Service-ஐ ஆன் செய்யவும்',

  'Required to auto-click Accept buttons': 'Accept பட்டனை தானாக கிளிக் செய்ய இது அவசியம்',

  'GO TO SETTINGS': 'செட்டிங்ஸ் செல்',

  'Ride History': 'சவாரி வரலாறு',

  'Valid Data': 'சரியான தரவு',

  'All': 'அனைத்தும்',

};



String t(String text) {

  if (isTamil && _ta.containsKey(text)) {

    return _ta[text]!;

  }

  return text;

}



String gAppVersion = '1.0.3';



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  try {

    final info = await PackageInfo.fromPlatform();

    gAppVersion = info.version;

  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();

  isTamil = prefs.getBool('isTamil') ?? false;

  final bool isLoggedIn = prefs.getString('driverId') != null;

  runApp(RapidoAutoClickerApp(home: isLoggedIn ? const HomePage() : const LoginPage()));

}





// ─────────────────────────────────────────────────────────────────────────────

// App Root

// ─────────────────────────────────────────────────────────────────────────────

class RapidoAutoClickerApp extends StatelessWidget {

  final Widget home;

  const RapidoAutoClickerApp({super.key, required this.home});



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

      home: home,

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

  final bool isAvailable;



  const AppInfo({

    required this.id,

    required this.name,

    required this.emoji,

    required this.primaryColor,

    required this.cardColor,

    required this.acceptButtonName,

    this.isAvailable = true,

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

    isAvailable: false,

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

  Future<void> _requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('[Notification] Permission error: $e');
    }
  }

  Future<void> _showAppNotification(String title, String message, {int id = 1002}) async {

    try {

      await _channel.invokeMethod('showNotification', {

        'title': title,

        'message': message,

        'id': id,

      });

    } catch (e) {

      debugPrint('[Notification] Error: $e');

    }

  }



  Future<void> _scheduleBlockEndNotification(int triggerAtMillis) async {

    try {

      await _channel.invokeMethod('scheduleBlockEndNotification', {

        'triggerAtMillis': triggerAtMillis,

        'title': isTamil ? 'Auto Clicker - 12 மணி நேர தடை முடிந்தது!' : 'Auto Clicker - 12hr Block Ended',

        'message': isTamil

            ? 'உங்கள் தடை நீக்கப்பட்டது! இப்போது நீங்கள் ஆப்பை பயன்படுத்தலாம்.'

            : 'Your block is removed and you can use the app now.',

      });

    } catch (e) {

      debugPrint('[Notification] Schedule error: $e');

    }

  }



  Future<void> _cancelBlockEndNotification() async {

    try {

      await _channel.invokeMethod('cancelBlockEndNotification');

    } catch (e) {

      debugPrint('[Notification] Cancel error: $e');

    }

  }



  String? _driverId;

  String? _deviceId;

  IO.Socket? _socket;

  bool _serviceActive = false;

  bool _isHUDEnabled = true;

  bool _olaBlockerEnabled = true;

  bool _isAppPurchased = false;

  int _totalAccepted = 0;

  int _totalSkipped = 0;

  double _totalEarnings = 0.0;

  String _lastActivity = 'Waiting for ride requests...';

  bool _isDailyLimitActive = false;

  int _dailyLimitEndTime = 0;

  int _dailyTripCount = 0;

  double _dailyEarnings = 0.0;

  Timer? _dailyLimitCountdownTimer;

  String _currentAppVersion = gAppVersion;

  bool _isForceUpdateShowing = false;

  bool _isDailyLimitDialogShowing = false;

  bool _isAdRequired = true;

  double _adHoursRemaining = 0.0;

  bool _isAdDialogShowing = false;



  // Per-app state

  final Map<String, bool> _appEnabled = {};

  final Map<String, RangeValues> _pickupRanges = {};

  final Map<String, RangeValues> _dropRanges = {};

  final Map<String, RangeValues> _priceRanges = {};



  // Smart Fare Mode — per-app toggle (new feature)

  // When ON: accepts based on KM + Price only — no location name check needed

  final Map<String, bool> _smartFareModeEnabled = {};



  // Location Profiles

  List<LocationProfile> _profiles = [];



  @override

  void initState() {

    super.initState();

    _initDriverId();

    WidgetsBinding.instance.addObserver(this);

    for (final app in kApps) {

      _appEnabled[app.id] = false;

      _pickupRanges[app.id] = const RangeValues(0.0, 5.0);

      _dropRanges[app.id] = const RangeValues(0.0, 50.0);

      _priceRanges[app.id] = const RangeValues(0.0, 1500.0);

      _smartFareModeEnabled[app.id] = false;

    }

    _loadAllStates();

    _setupMethodCallHandler();

    _loadAppVersion();

    _initAdDeepLink();

    _requestNotificationPermission();

  }



  Future<void> _initDriverId() async {

    final prefs = await SharedPreferences.getInstance();

    setState(() {

      _driverId = prefs.getString('driverId');

      _deviceId = prefs.getString('deviceId');

    });

    _initSocketAndDriver();
    _checkAdStatus();

    _fetchAcceptedTripsFromDB();

  }

  

  void _initSocketAndDriver() {

    if (_driverId == null) return;

    _socket = IO.io('http://43.205.135.3:3000', <String, dynamic>{

      'transports': ['websocket'],

      'autoConnect': true,

      'query': {'driver_id': _driverId},

    });



    _socket?.onConnect((_) {

      debugPrint('Connected to socket server');

      if (_driverId != null) {

        _socket?.emit('identifyClicker', {

          'driverId': _driverId,

          'appVersion': _currentAppVersion,

        });

      }

    });



    _socket?.on('clickerPaymentStatus', (data) {

      if (data['status'] == 'paid') {

        _unlockApp(showDialogMessage: true);

      } else {

        setState(() => _isAppPurchased = false);

        _handleUnpaidStatus();

      }

    });



    _socket?.on('clickerBlockStatus', (data) {

      if (data['isBlocked'] == true) {

        _fetchAcceptedTripsFromDB();

      }

    });



    _socket?.on('forceLogout', (data) {

      _handleLogout(data['message'] ?? 'Logged in from another device.');

    });



    _socket?.on('clickerFreeTrialEnd', (data) {

      if (mounted) {

        setState(() => _isAppPurchased = false);

        _enforcePaywallIfNeeded();

      }

    });



    _socket?.on('dailyLimitReached', (data) {

      if (mounted) {

        final endTime = data['endTime'] as int? ?? 0;

        final trips = data['dailyTrips'] as int? ?? 0;

        final earnings = (data['dailyEarnings'] as num?)?.toDouble() ?? 0.0;

        _handleDailyLimitTriggered(endTime, trips, earnings);

      }

    });



    _socket?.on('forceAppUpdate', (data) {

      if (mounted) {

        final ver = data['version'] as String? ?? 'Latest';

        final url = data['apkUrl'] as String? ?? '';

        _showForceUpdateDialog(ver, url);

      }

    });



    _socket?.on('adWatchCompleted', (data) {

      if (mounted) {

        _handleAdComplete();

      }

    });



    _socket?.on('dailyLimitRemoved', (data) {

      if (mounted) {

        _dailyLimitCountdownTimer?.cancel();

        _cancelBlockEndNotification();

        setState(() {

          _isDailyLimitActive = false;

          _dailyLimitEndTime = 0;

        });

        if (_isDailyLimitDialogShowing) {

          Navigator.of(context, rootNavigator: true).pop();

          _isDailyLimitDialogShowing = false;

        }

        final msg = (data != null && data['message'] != null)

            ? data['message'].toString()

            : (isTamil

                ? 'அட்மின் உங்கள் 12 மணி நேர தடையை நீக்கிவிட்டார்! இப்போது ஆப்களை பயன்படுத்தலாம்.'

                : 'Your block is removed and you can use the app.');



        _showAppNotification(

          isTamil ? 'Auto Clicker - தடை நீக்கப்பட்டது!' : 'Auto Clicker - Block Removed',

          msg,

          id: 1006,

        );



        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(msg),

            backgroundColor: Colors.green,

            duration: const Duration(seconds: 4),

          ),

        );

      }

    });

  }



  // ─── AD System (6-hour access & cross-app reward) ─────────────────────────



  Future<void> _checkAdStatus() async {

    if (_driverId == null) return;

    try {

      final response = await http.get(

        Uri.parse('http://43.205.135.3:3000/api/ad/status?driverId=$_driverId'),

      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        final bool needsAd = data['needsAd'] ?? true;

        final double hoursRem = (data['hoursRemaining'] as num?)?.toDouble() ?? 0.0;

        if (mounted) {

          setState(() {

            _isAdRequired = needsAd;

            _adHoursRemaining = hoursRem;

          });

          if (needsAd) {

            _disableAllApps();

            if (!_isAdDialogShowing) {

              _showWatchAdDialog(hoursRem);

            }

          } else {

            // Already valid, close dialog if open

            if (_isAdDialogShowing) {

              Navigator.of(context, rootNavigator: true).pop();

              _isAdDialogShowing = false;

            }

          }

        }

      }

    } catch (e) {

      debugPrint('[AD Check] Error: $e');

    }

  }



  void _disableAllApps() {

    for (final app in kApps) {

      if (_appEnabled[app.id] == true) {

        _setAppEnabled(app.id, false);

      }

    }

  }



  void _showWatchAdDialog(double hoursRemaining) {

    if (!mounted || _isAdDialogShowing) return;

    _isAdDialogShowing = true;

    _disableAllApps();



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (ctx) {

        return WillPopScope(

          onWillPop: () async => false,

          child: AlertDialog(

            backgroundColor: const Color(0xFF1E1E1E),

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

            title: Row(

              children: [

                const Icon(Icons.play_circle_filled, color: Color(0xFF00C853), size: 28),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    isTamil ? 'விளம்பரம் பார்க்கவும்' : 'Watch Ad to Continue',

                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),

                  ),

                ),

              ],

            ),

            content: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Container(

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: const Color(0xFF0D2B0D),

                    borderRadius: BorderRadius.circular(10),

                    border: Border.all(color: const Color(0xFF00C853).withOpacity(0.5)),

                  ),

                  child: Column(

                    children: [

                      const Icon(Icons.info_outline, color: Color(0xFF00C853), size: 24),

                      const SizedBox(height: 8),

                      Text(

                        isTamil

                            ? 'AutoClicker தொடர்ந்து பயன்படுத்த Azhai Partner செயலியில் ஒரு குறுகிய விளம்பரம் பார்க்கவும்.'

                            : 'Watch a short Rewarded AD in Azhai Partner to continue using AutoClicker.',

                        style: const TextStyle(color: Colors.white, fontSize: 13),

                        textAlign: TextAlign.center,

                      ),

                      const SizedBox(height: 6),

                      Text(

                        isTamil

                            ? '⚡ ஒரு முறை பார்த்தால் 6 மணி நேரம் பயன்பாடு கிடைக்கும்.'

                            : '⚡ Once watched, you get 6 hours of full access.',

                        style: const TextStyle(color: Color(0xFF00C853), fontSize: 12, fontWeight: FontWeight.bold),

                        textAlign: TextAlign.center,

                      ),

                    ],

                  ),

                ),

                const SizedBox(height: 12),

                Container(

                  padding: const EdgeInsets.all(8),

                  decoration: BoxDecoration(

                    color: Colors.red.withOpacity(0.15),

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(color: Colors.redAccent.withOpacity(0.4)),

                  ),

                  child: Row(

                    children: [

                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Text(

                          isTamil

                              ? 'விளம்பரம் பார்க்காமல் செயலியை பயன்படுத்த முடியாது.'

                              : 'All services disabled until AD is watched.',

                          style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

            actions: [

              SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  style: ElevatedButton.styleFrom(

                    backgroundColor: const Color(0xFF00C853),

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 14),

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                  ),

                  icon: const Icon(Icons.open_in_new, size: 20),

                  label: Text(

                    isTamil ? '▶️ விளம்பரம் பார் (Azhai Partner)' : '▶️ Watch AD on Azhai Partner',

                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),

                  ),

                  onPressed: _openAzhaiPartnerForAd,

                ),

              ),

            ],

          ),

        );

      },

    );

  }



  Future<void> _openAzhaiPartnerForAd() async {

    final driverId = _driverId ?? '';

    try {

      final uri = Uri.parse('azhai://watch-ad?driverId=$driverId');

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!launched && mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('Azhai Partner ஆப் திறக்க முடியவில்லை. நிறுவியுள்ளீர்களா என சரிபார்க்கவும்.'),

            backgroundColor: Colors.red,

          ),

        );

      }

    } catch (e) {

      debugPrint('[AD] Cannot open Azhai Partner: $e');

    }

  }



  void _initAdDeepLink() {

    try {

      final appLinks = AppLinks();

      appLinks.uriLinkStream.listen((uri) {

        debugPrint('[AutoClicker DeepLink] Received: $uri');

        if (uri.scheme == 'autoclicker' && uri.host == 'ad-complete') {

          _handleAdComplete();

        }

      });

      appLinks.getInitialLink().then((uri) {

        if (uri != null && uri.scheme == 'autoclicker' && uri.host == 'ad-complete') {

          _handleAdComplete();

        }

      });

    } catch (e) {

      debugPrint('[AutoClicker DeepLink] Init error: $e');

    }

  }



  void _handleAdComplete() {

    if (!mounted) return;

    setState(() {

      _isAdRequired = false;

      _adHoursRemaining = 6.0;

    });



    if (_isAdDialogShowing) {

      Navigator.of(context, rootNavigator: true).pop();

      _isAdDialogShowing = false;

    }



    _showAppNotification(

      isTamil ? 'Auto Clicker - சலுகை கிடைத்தது! 🎬' : 'Auto Clicker - Reward Unlocked! 🎬',

      isTamil

          ? 'விளம்பரம் பார்த்ததற்கு நன்றி! இப்போது 6 மணி நேர பாஸ் கிடைத்தது. ஆப் பயன்பாட்டிற்கு தயார்.'

          : 'Now you get reward! Now you can use the app (6 hours access).',

      id: 1007,

    );



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(

          isTamil

              ? '✅ விளம்பரம் முடிந்தது! இப்போது AutoClicker பயன்படுத்தலாம்.'

              : '✅ Ad watched! Now you can use the app (6 hrs access).',

        ),

        backgroundColor: const Color(0xFF00C853),

        duration: const Duration(seconds: 4),

      ),

    );

  }



  void _handleLogout(String message) async {

    for (final app in kApps) {

      if (_appEnabled[app.id] == true) {

        _setAppEnabled(app.id, false);

      }

    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', false);

    await prefs.remove('driverId');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));

    Navigator.pushAndRemoveUntil(

      context,

      MaterialPageRoute(builder: (context) => const LoginPage()),

      (route) => false,

    );

  }



  @override

  void dispose() {

    _dailyLimitCountdownTimer?.cancel();

    _socket?.disconnect();

    _socket?.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed) {
      _checkServiceStatus();
      _checkAdStatus();
      _fetchAcceptedTripsFromDB();
    }

  }



  // ── Method Channel Handler (receive from native) ──────────────────────────



  void _setupMethodCallHandler() {

    _channel.setMethodCallHandler((call) async {

      if (call.method == 'onRideAccepted') {

        final appName = call.arguments['appName'] as String? ?? '';

        final location = call.arguments['location'] as String? ?? '';

        final double fare = (call.arguments['fare'] as num?)?.toDouble() ?? 0.0;

        setState(() {

          _totalAccepted++;

          _lastActivity = '✅ [$appName] Accepted → $location';

        });



        // Notify backend about the accepted trip

        if (_driverId != null) {

          http.post(

            Uri.parse('http://43.205.135.3:3000/api/update-clicker-trip'),

            headers: {'Content-Type': 'application/json'},

            body: jsonEncode({

              'driver_id': _driverId,

              'fare': fare,

              'app_version': _currentAppVersion,

            }),

          ).then((response) {

            if (response.statusCode == 200) {

              final data = jsonDecode(response.body);

              final bool dailyActive = data['daily_limit_active'] ?? false;

              final int dailyEnd = data['daily_limit_end_time'] ?? 0;

              final int dailyTrips = data['daily_trip_count'] ?? 0;

              final double dailyEarn = (data['daily_earnings'] as num?)?.toDouble() ?? 0.0;



              setState(() {

                _dailyTripCount = dailyTrips;
                _dailyEarnings = dailyEarn;

              });



              if (dailyActive && dailyEnd > DateTime.now().millisecondsSinceEpoch) {

                _handleDailyLimitTriggered(dailyEnd, dailyTrips, dailyEarn);

              }

            }

          }).catchError((e) {

            debugPrint('Failed to update trip count to backend: $e');

          });

        }

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

            _totalSkipped = result['totalSkipped'] as int? ?? 0;

            _totalEarnings = (result['totalEarnings'] as num?)?.toDouble() ?? 0.0;

          _isHUDEnabled = result['isHUDEnabled'] as bool? ?? true;

          for (final app in kApps) {

            _smartFareModeEnabled[app.id] = result['${app.id}_smartFareMode'] as bool? ?? false;

          }



          final profilesJson = result['locationProfiles'] as String? ?? '[]';

          try {

            final List decoded = jsonDecode(profilesJson);

            _profiles = decoded.map((e) => LocationProfile.fromJson(e)).toList();

          } catch (_) {

            _profiles = [];

            }

          });

          _fetchAcceptedTripsFromDB();

        }

    } catch (_) {}

  }





  Future<void> _fetchAcceptedTripsFromDB() async {

    if (_driverId == null) return;

    if (_currentAppVersion == '1.0.0' && gAppVersion != '1.0.0') {

      _currentAppVersion = gAppVersion;

    }

    if (_deviceId == null || _deviceId!.isEmpty) {

      final prefs = await SharedPreferences.getInstance();

      _deviceId = prefs.getString('deviceId') ?? '';

    }

    try {

      final response = await http.post(

        Uri.parse('http://43.205.135.3:3000/api/clicker-profile'),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({

          'driver_id': _driverId,

          'device_id': _deviceId ?? '',

          'app_version': _currentAppVersion,

        }),

      );

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        if (data['status'] == 'logout') {

          _handleLogout(data['message'] ?? 'Logged in from another device.');

          return;

        }

        if (data['status'] == 'success') {

          final acceptedTrips = data['profile']['acceptedTrips'] ?? 0;

          final hasPaid = data['profile']['hasPaidForClicker'] ?? false;



          if (data['profile']['isBlocked'] == true) {

            _handleLogout('Access Blocked by Admin. Please contact support.');

            return;

          }



          final bool dailyActive = data['profile']['isDailyLimitActive'] ?? false;

          final int dailyEnd = data['profile']['dailyLimitEndTime'] ?? 0;

          final int dailyTrips = data['profile']['dailyTripCount'] ?? 0;

          final double dailyEarn = (data['profile']['dailyEarnings'] as num?)?.toDouble() ?? 0.0;
          final bool isAdPassActive = data['profile']['isAdPassActive'] ?? false;
          final double adHoursRem = (data['profile']['adPassHoursRemaining'] as num?)?.toDouble() ?? 0.0;



          setState(() {

            _totalAccepted = acceptedTrips;

            _isAppPurchased = hasPaid;

            _dailyTripCount = dailyTrips;
            _isAdRequired = !isAdPassActive;
            _adHoursRemaining = adHoursRem;

            _dailyEarnings = dailyEarn;

          });

          if (!isAdPassActive) {
            _disableAllApps();
          }



          if (dailyActive && dailyEnd > DateTime.now().millisecondsSinceEpoch) {

            _handleDailyLimitTriggered(dailyEnd, dailyTrips, dailyEarn);

          }

        }

      }

    } catch (_) {}

  }



  void _enforcePaywallIfNeeded() {

    if (!_isAppPurchased) {

      for (final app in kApps) {

        if (_appEnabled[app.id] == true) {

          _setAppEnabled(app.id, false);

        }

      }

      

      if (!mounted) return;

      showDialog(

        context: context,

        barrierDismissible: false,

        builder: (context) {

          bool isUploading = false;

          return StatefulBuilder(

            builder: (context, setDialogState) {

              return WillPopScope(

                onWillPop: () async => false,

                child: AlertDialog(

                  backgroundColor: const Color(0xFF1E1E1E),

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                  title: const Text('Free Trial Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

                  content: SingleChildScrollView(

                    child: Column(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        const Text(

                          'Your free trial has ended.\n\nPlease pay ₹100 via UPI to continue using AutoClicker.\n',

                          style: TextStyle(color: Colors.white70),

                          textAlign: TextAlign.center,

                        ),

                        Container(

                          decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 2)),

                          child: Image.asset('assets/images/qr_code.jpg', width: 200, height: 200, fit: BoxFit.cover),

                        ),

                        const SizedBox(height: 10),

                        const Text(

                          'After paying, upload the screenshot of the success page below for Admin verification.',

                          style: TextStyle(color: Colors.yellow, fontSize: 12),

                          textAlign: TextAlign.center,

                        ),

                      ],

                    ),

                  ),

                  actions: [

                      isUploading ? const SizedBox.shrink() : ElevatedButton.icon(

                        onPressed: () async {

                          try {

                            final byteData = await rootBundle.load('assets/images/qr_code.jpg');

                            final bytes = byteData.buffer.asUint8List();

                            await Gal.putImageBytes(bytes);

                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code saved to Gallery!')));

                          } catch (e) {

                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save QR Code')));

                          }

                        },

                        icon: const Icon(Icons.download, color: Colors.black),

                        label: const Text('Download QR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),

                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00)),

                      ),

                      isUploading 

                    ? const Padding(

                        padding: EdgeInsets.all(8.0),

                        child: CircularProgressIndicator(),

                      )

                    : ElevatedButton.icon(

                      style: ElevatedButton.styleFrom(

                        backgroundColor: Colors.green,

                        foregroundColor: Colors.white,

                      ),

                      onPressed: () async {

                        final picker = ImagePicker();

                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);

                        if (image != null) {

                           setDialogState(() => isUploading = true);

                           try {

                             var request = http.MultipartRequest('POST', Uri.parse('http://43.205.135.3:3000/api/clicker-payment/upload'));

                             request.fields['driver_id'] = _driverId ?? '';

                             request.files.add(await http.MultipartFile.fromPath('screenshot', image.path));

                             var res = await request.send();

                             if (res.statusCode == 200) {

                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screenshot sent! Please wait for Admin approval.')));

                             } else {

                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload screenshot.')));

                             }

                           } catch (e) {

                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ' + e.toString())));

                           }

                           setDialogState(() => isUploading = false);

                        }

                      },

                      icon: const Icon(Icons.upload_file),

                      label: const Text('Upload Screenshot'),

                    ),

                  ],

                ),

              );

            }

          );

        },

      );

    }

  }



    // ── Version Check & Force Update ──────────────────────────────────────────



  Future<void> _loadAppVersion() async {

    try {

      final info = await PackageInfo.fromPlatform();

      if (mounted) {

        setState(() {

          _currentAppVersion = info.version;

        });

      } else {

        _currentAppVersion = info.version;

      }

    } catch (_) {}



    // Sync app version to backend via socket and HTTP

    if (_driverId != null) {

      if (_socket != null && _socket!.connected) {

        _socket?.emit('identifyClicker', {

          'driverId': _driverId,

          'appVersion': _currentAppVersion,

        });

      }

      _fetchAcceptedTripsFromDB();

    }



    _checkForUpdate();

  }



  Future<void> _checkForUpdate() async {

    try {

      final response = await http

          .get(Uri.parse('http://43.205.135.3:3000/api/clicker-version'))

          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        final latestVersion = data['latestVersion'] as String? ?? '1.0.0';

        final apkUrl = data['apkUrl'] as String? ?? '';

        if (_isVersionOlder(_currentAppVersion, latestVersion)) {

          _showForceUpdateDialog(latestVersion, apkUrl);

        }

      }

    } catch (e) {

      debugPrint('Check update error: $e');

    }

  }



  bool _isVersionOlder(String current, String latest) {

    List<int> parse(String v) => v.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    final c = parse(current);

    final l = parse(latest);

    for (int i = 0; i < 3; i++) {

      final cv = i < c.length ? c[i] : 0;

      final lv = i < l.length ? l[i] : 0;

      if (cv < lv) return true;

      if (cv > lv) return false;

    }

    return false;

  }



  void _showForceUpdateDialog(String version, String apkUrl) {

    if (!mounted || _isForceUpdateShowing) return;

    _isForceUpdateShowing = true;



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (ctx) {

        return WillPopScope(

          onWillPop: () async => false,

          child: AlertDialog(

            backgroundColor: const Color(0xFF1E1E1E),

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

            title: Row(

              children: [

                const Icon(Icons.system_update, color: Colors.blueAccent, size: 28),

                const SizedBox(width: 8),

                Text(

                  isTamil ? 'புதிய அப்டேட் தேவை!' : 'Update Required!',

                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),

                ),

              ],

            ),

            content: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                const Icon(Icons.cloud_download_outlined, color: Colors.blueAccent, size: 50),

                const SizedBox(height: 12),

                Text(

                  'v$version',

                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),

                ),

                const SizedBox(height: 8),

                Text(

                  isTamil

                      ? 'தொடர்ந்து பயன்படுத்த புதிய பதிப்பிற்கு அப்டேட் செய்யவும்.'

                      : 'Please update to the latest version to continue using AutoClicker.',

                  style: const TextStyle(color: Colors.white70, fontSize: 13),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 8),

                Text(

                  isTamil ? 'தற்போதைய பதிப்பு: v$_currentAppVersion' : 'Current installed: v$_currentAppVersion',

                  style: const TextStyle(color: Colors.white38, fontSize: 11),

                ),

              ],

            ),

            actions: [

              SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  style: ElevatedButton.styleFrom(

                    backgroundColor: Colors.blueAccent,

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 12),

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),

                  ),

                  icon: const Icon(Icons.download),

                  label: Text(

                    isTamil ? 'இப்போதே அப்டேட் செய்' : 'Update Now',

                    style: const TextStyle(fontWeight: FontWeight.bold),

                  ),

                  onPressed: () async {

                    if (apkUrl.isNotEmpty) {

                      try {

                        final uri = Uri.parse(apkUrl);

                        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

                        if (!launched) {

                          await launchUrl(uri, mode: LaunchMode.platformDefault);

                        }

                      } catch (e) {

                        debugPrint('Could not launch apkUrl: $e');

                      }

                    }

                  },

                ),

              ),

            ],

          ),

        );

      },

    );

  }



  // ── Daily Limit Cooldown Handlers ──────────────────────────────────────────



  void _handleDailyLimitTriggered(int endTime, int trips, double earnings) {

    for (final app in kApps) {

      if (_appEnabled[app.id] == true) {

        _setAppEnabled(app.id, false);

      }

    }



    setState(() {

      _isDailyLimitActive = true;

      _dailyLimitEndTime = endTime;

      _dailyTripCount = trips;

      _dailyEarnings = earnings;

    });



    _startDailyCountdownTimer();

    _scheduleBlockEndNotification(endTime);



    if (!_isDailyLimitDialogShowing && mounted) {

      _showDailyLimitDialog();

    }

  }



  void _startDailyCountdownTimer() {

    _dailyLimitCountdownTimer?.cancel();

    _dailyLimitCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {

      final remaining = _dailyLimitEndTime - DateTime.now().millisecondsSinceEpoch;

      if (remaining <= 0) {

        timer.cancel();

        _cancelBlockEndNotification();

        setState(() {

          _isDailyLimitActive = false;

          _dailyLimitEndTime = 0;

        });

        if (_isDailyLimitDialogShowing) {

          Navigator.of(context, rootNavigator: true).pop();

          _isDailyLimitDialogShowing = false;

        }

        _showAppNotification(

          isTamil ? 'Auto Clicker - 12 மணி நேர தடை முடிந்தது!' : 'Auto Clicker - 12hr Block Ended',

          isTamil

              ? 'உங்கள் தடை நீக்கப்பட்டது! இப்போது நீங்கள் ஆப்பை பயன்படுத்தலாம்.'

              : 'Your block is removed and you can use the app now.',

          id: 1005,

        );

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(

              content: Text('✅ 12-hour limit completed! You can now turn ON apps.'),

              backgroundColor: Colors.green,

            ),

          );

        }

      } else {

        if (mounted) setState(() {});

      }

    });

  }



  void _showDailyLimitDialog() {

    if (!mounted || _isDailyLimitDialogShowing) return;

    _isDailyLimitDialogShowing = true;



    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (ctx) {

        return WillPopScope(

          onWillPop: () async => false,

          child: StatefulBuilder(

            builder: (ctx, setDialogState) {

              final remaining = _dailyLimitEndTime - DateTime.now().millisecondsSinceEpoch;

              if (remaining <= 0) {

                WidgetsBinding.instance.addPostFrameCallback((_) {

                  if (Navigator.canPop(ctx)) Navigator.pop(ctx);

                });

                return const SizedBox.shrink();

              }



              final hours = remaining ~/ 3600000;

              final minutes = (remaining % 3600000) ~/ 60000;

              final seconds = (remaining % 60000) ~/ 1000;



              Timer(const Duration(seconds: 1), () {

                if (ctx.mounted) setDialogState(() {});

              });



              final timeFormatted =

                  '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';



              return AlertDialog(

                backgroundColor: const Color(0xFF1E1E1E),

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                title: Row(

                  children: [

                    const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 28),

                    const SizedBox(width: 8),

                    Text(

                      isTamil ? 'இன்றைய வரம்பு முடிந்தது!' : "Today's Limit Reached!",

                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),

                    ),

                  ],

                ),

                content: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Text(

                      isTamil

                          ? 'இன்று நீங்கள் $_dailyTripCount சவாரிகள் / ₹${_dailyEarnings.toStringAsFixed(0)} ஈட்டியுள்ளீர்கள்.\n(வரம்பு: 6 சவாரிகள் அல்லது ₹1000)'

                          : 'You have completed $_dailyTripCount trips / ₹${_dailyEarnings.toStringAsFixed(0)} today.\n(Limit: 6 trips or ₹1000)',

                      style: const TextStyle(color: Colors.white70, fontSize: 13),

                      textAlign: TextAlign.center,

                    ),

                    const SizedBox(height: 16),

                    Container(

                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),

                      decoration: BoxDecoration(

                        color: Colors.red.withOpacity(0.15),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),

                      ),

                      child: Column(

                        children: [

                          Text(

                            isTamil ? 'மீண்டும் இயக்க மீதமுள்ள நேரம்:' : 'Time remaining to unlock:',

                            style: const TextStyle(color: Colors.white54, fontSize: 11),

                          ),

                          const SizedBox(height: 6),

                          Text(

                            timeFormatted,

                            style: const TextStyle(

                              color: Colors.redAccent,

                              fontSize: 32,

                              fontWeight: FontWeight.bold,

                              fontFeatures: [FontFeature.tabularFigures()],

                            ),

                          ),

                        ],

                      ),

                    ),

                    const SizedBox(height: 12),

                    Text(

                      isTamil

                          ? '12 மணி நேரம் முடியும் வரை ஆட்டோ கிளிக்கர் இயங்காது.'

                          : 'AutoClicker is disabled for 12 hours. Please wait.',

                      style: const TextStyle(color: Colors.white38, fontSize: 11),

                      textAlign: TextAlign.center,

                    ),

                  ],

                ),

                actions: [

                  TextButton(

                    onPressed: () {

                      _isDailyLimitDialogShowing = false;

                      Navigator.pop(ctx);

                    },

                    child: const Text('OK', style: TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold)),

                  ),

                ],

              );

            },

          ),

        );

      },

    ).then((_) {

      _isDailyLimitDialogShowing = false;

    });

  }



  void _unlockApp({bool showDialogMessage = false}) async {

    setState(() {

      _isAppPurchased = true;

      _totalAccepted = 0;

    });

    await _channel.invokeMethod('setAppPurchased', {'purchased': true});

    if (mounted && Navigator.canPop(context)) {

      Navigator.pop(context); // Close the dialog

    }

    if (showDialogMessage && mounted) {

      showDialog(

        context: context,

        builder: (context) => AlertDialog(

          backgroundColor: const Color(0xFF1E1E1E),

          title: const Text('Payment Successful', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),

          content: const Text('Your payment was received. Auto Clicker is now unlocked!', style: TextStyle(color: Colors.white)),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(context),

              child: const Text('OK', style: TextStyle(color: Color(0xFFFFCC00))),

            )

          ]

        )

      );

    }

  }



  void _handleUnpaidStatus() {

    if (mounted && Navigator.canPop(context)) {

      Navigator.pop(context); // Close any existing dialog

    }

    if (mounted) {

      showDialog(

        context: context,

        builder: (context) => AlertDialog(

          backgroundColor: const Color(0xFF1E1E1E),

          title: const Text('Payment Failed', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),

          content: const Text('Your payment was not received or please try again or contact the admin via WhatsApp.', style: TextStyle(color: Colors.white)),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

                _enforcePaywallIfNeeded();

              },

              child: const Text('OK', style: TextStyle(color: Color(0xFFFFCC00))),

            )

          ]

        )

      );

    }

  }



  Future<void> _checkServiceStatus() async {

    try {

      final bool result = await _channel.invokeMethod('isServiceEnabled') ?? false;

      if (mounted) setState(() => _serviceActive = result);

    } catch (_) {

      if (mounted) setState(() => _serviceActive = false);

    }

  }



  Future<void> _disableAccessibilityForBanking() async {

    try {

      await _channel.invokeMethod('disableAccessibility');

      if (mounted) {

        setState(() => _serviceActive = false);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(

              isTamil

                  ? '🏦 Banking Mode இயக்கப்பட்டது!\nAccessibility நிறுத்தப்பட்டது. இப்போது GPay, PhonePe பயன்படுத்தலாம்.'

                  : '🏦 Banking Mode Enabled!\nAccessibility disabled. You can now use banking apps safely.',

              style: const TextStyle(fontWeight: FontWeight.bold),

            ),

            backgroundColor: const Color(0xFF00C853),

            duration: const Duration(seconds: 4),

          ),

        );

      }

    } catch (e) {

      debugPrint('Error disabling accessibility: $e');

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

    

    stt.SpeechToText speech = stt.SpeechToText();

    bool isListening = false;



    showDialog(

      context: context,

      builder: (context) {

        return StatefulBuilder(

          builder: (context, setDialogState) {

            

            void _listen() async {

              if (!isListening) {

                bool available = await speech.initialize(

                  onStatus: (val) {

                    if (val == 'done' || val == 'notListening') {

                      setDialogState(() => isListening = false);

                    }

                  },

                  onError: (val) {

                    setDialogState(() => isListening = false);

                  },

                );

                if (available) {

                  setDialogState(() => isListening = true);

                  

                  String existingText = locsCtrl.text.trim();

                  if (existingText.isNotEmpty && !existingText.endsWith(',')) {

                    existingText += ', ';

                  }

                  

                  speech.listen(

                    onResult: (val) {

                      setDialogState(() {

                        locsCtrl.text = existingText + val.recognizedWords;

                        locsCtrl.selection = TextSelection.fromPosition(TextPosition(offset: locsCtrl.text.length));

                      });

                    },

                  );

                }

              } else {

                setDialogState(() => isListening = false);

                speech.stop();

              }

            }



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

                  Row(

                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: [

                      Expanded(

                        child: TextField(

                          controller: locsCtrl,

                          style: const TextStyle(color: Colors.white),

                          decoration: const InputDecoration(

                            labelText: 'Locations (comma separated)',

                            labelStyle: TextStyle(color: Colors.white54),

                          ),

                          maxLines: 3,

                        ),

                      ),

                      IconButton(

                        icon: Icon(

                          isListening ? Icons.mic : Icons.mic_none,

                          color: isListening ? Colors.red : const Color(0xFFFFCC00),

                          size: 32,

                        ),

                        onPressed: _listen,

                      ),

                    ],

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

          }

        );

      },

    );

  }



  void _toggleProfile(LocationProfile profile, bool value) {

    setState(() {

      profile.isActive = value;

      // STRICT: If any Location Profile is turned ON, disable Smart Fare mode all apps

      if (value) {

        for (final app in kApps) {

          if (_smartFareModeEnabled[app.id] == true) {

            _smartFareModeEnabled[app.id] = false;

            _channel.invokeMethod('setSmartFareMode', {'appId': app.id, 'enabled': false});

          }

        }

      }

    });

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







  // Smart Fare Mode toggle method

  Future<void> _setSmartFareMode(String appId, bool value) async {

    setState(() => _smartFareModeEnabled[appId] = value);

    try {

      await _channel.invokeMethod('setSmartFareMode', {'appId': appId, 'enabled': value});

    } catch (_) {}

  }



  // Smart Fare conflict dialog

  void _showSmartFareConflictDialog() {

    showDialog(

      context: context,

      builder: (ctx) => AlertDialog(

        backgroundColor: const Color(0xFF1E1E1E),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: Row(

          children: const [

            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 26),

            SizedBox(width: 8),

            Text('Mode Conflict!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),

          ],

        ),

        content: Text(

          isTamil

              ? 'Smart Fare Mode மற்றும் Location Profile இரண்டும் ஒரே நேரத்தில் ON பண்ண முடியாது.\\n\\n'

                'முதலில் Location Profiles section-ல் உள்ள அனைத்து toggles-ஐயும் OFF செய்யவும், பிறகு Smart Fare Mode ON பண்ணலாம்.'

              : 'Smart Fare Mode and Location Profile cannot be ON at the same time.\\n\\n'

                'Please turn OFF all Location Profiles first, then enable Smart Fare Mode.',

          style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13),

        ),

        actions: [

          SizedBox(

            width: double.infinity,

            child: TextButton(

              onPressed: () => Navigator.pop(ctx),

              child: Text(

                isTamil ? 'சரி (OK)' : 'Got it',

                style: const TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold, fontSize: 15),

              ),

            ),

          ),

        ],

      ),

    );

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

      appBar: AppBar(

        title: Text(t('Auto Clicker'), style: TextStyle(fontWeight: FontWeight.bold)),

        backgroundColor: const Color(0xFF1A1A1A),

        actions: [

          TextButton.icon(

            onPressed: () {

              Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (context) => ProfilePage(

                    initialDriverId: _driverId,

                    initialIsDailyLimitActive: _isDailyLimitActive,

                    initialDailyLimitEndTime: _dailyLimitEndTime,

                    initialIsAdRequired: _isAdRequired,

                    initialAdHoursRemaining: _adHoursRemaining,

                  ),

                ),

              );

            },

            icon: const Icon(Icons.person, color: Color(0xFFFFCC00)),

            label: Text(t('Open Profile'), style: TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold)),

          ),

        ],

      ),

      body: SafeArea(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(16),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              _buildLanguageSelector(),

              const SizedBox(height: 12),

              _buildHeader(),

              const SizedBox(height: 16),

              _buildBankingModeCard(),

              const SizedBox(height: 16),

              _buildHUDToggleCard(),

              const SizedBox(height: 16),

              _buildProfilesCard(),

              const SizedBox(height: 16),

              SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  icon: const Icon(Icons.history, size: 18),

                  label: Text(t('Open Ride History Page'), style: TextStyle(fontWeight: FontWeight.bold)),

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

              Text(

                t('Apps'),

                style: const TextStyle(

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



  Widget _buildLanguageSelector() {

    return Container(

      width: double.infinity,

      decoration: BoxDecoration(

        color: const Color(0xFF1A1A1A),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: const Color(0xFF2A2A2A)),

      ),

      child: SegmentedButton<bool>(

        style: ButtonStyle(

          backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {

            if (states.contains(MaterialState.selected)) return const Color(0xFFFFCC00);

            return Colors.transparent;

          }),

          foregroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {

            if (states.contains(MaterialState.selected)) return Colors.black;

            return Colors.white;

          }),

        ),

        segments: [

          ButtonSegment(value: false, label: Text('English', style: TextStyle(fontWeight: FontWeight.bold))),

          ButtonSegment(value: true, label: Text('தமிழ்', style: TextStyle(fontWeight: FontWeight.bold))),

        ],

        selected: {isTamil},

        onSelectionChanged: (Set<bool> newSelection) async {

          setState(() {

            isTamil = newSelection.first;

          });

          final prefs = await SharedPreferences.getInstance();

          await prefs.setBool('isTamil', isTamil);

        },

      ),

    );

  }



  // ── Header ────────────────────────────────────────────────────────────────



  Widget _buildHeader() {

    final activeCount = _appEnabled.values.where((v) => v).length;

    return Row(

      children: [

        Expanded(

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(t('Auto Clicker'),

                  style: TextStyle(

                      fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),

              Text(t('Ride Accept Automation'),

                  style: TextStyle(fontSize: 13, color: Color(0xFFB3B3B3))),

            ],

          ),

        ),

        const SizedBox(width: 8),

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

            '$activeCount ${t('Active')}',

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





  Widget _buildBankingModeCard() {

    if (!_serviceActive) {

      return Container(

        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(

          color: const Color(0xFF142414),

          borderRadius: BorderRadius.circular(14),

          border: Border.all(color: const Color(0xFF1B5E20)),

        ),

        child: Row(

          children: [

            const Icon(Icons.account_balance, color: Color(0xFF4CAF50), size: 24),

            const SizedBox(width: 12),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    isTamil ? '🏦 பேங்கிங் மோட் தயார் (GPay / PhonePe)' : '🏦 Banking Mode Ready (GPay / PhonePe)',

                    style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 13),

                  ),

                  const SizedBox(height: 2),

                  Text(

                    isTamil

                        ? 'Accessibility நிறுத்தப்பட்டுள்ளது. வங்கி செயலிகளை தடையின்றி பயன்படுத்தலாம்.'

                        : 'Accessibility is turned off. Banking apps will open without warnings.',

                    style: const TextStyle(color: Colors.white70, fontSize: 11),

                  ),

                ],

              ),

            ),

          ],

        ),

      );

    }



    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

      decoration: BoxDecoration(

        color: const Color(0xFF1A1A1A),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFF2E3A4E)),

      ),

      child: Row(

        children: [

          Container(

            padding: const EdgeInsets.all(8),

            decoration: BoxDecoration(

              color: const Color(0xFF2196F3).withValues(alpha: 0.15),

              shape: BoxShape.circle,

            ),

            child: const Icon(Icons.account_balance, color: Color(0xFF2196F3), size: 22),

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  isTamil ? 'வங்கி செயலிகள் (Banking Mode)' : 'Banking Apps (GPay / PhonePe)',

                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),

                ),

                const SizedBox(height: 2),

                Text(

                  isTamil ? 'GPay/PhonePe பயன்படுத்த 1-கிளிக்கில் ஆஃப் செய்யலாம்' : '1-tap disable before opening bank apps',

                  style: const TextStyle(color: Colors.white60, fontSize: 11),

                ),

              ],

            ),

          ),

          const SizedBox(width: 8),

          ElevatedButton.icon(

            style: ElevatedButton.styleFrom(

              backgroundColor: const Color(0xFF1E3A5F),

              foregroundColor: const Color(0xFF64B5F6),

              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

            ),

            icon: const Icon(Icons.power_settings_new, size: 16),

            label: Text(

              isTamil ? 'ஆஃப் செய்' : 'Turn Off',

              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),

            ),

            onPressed: _disableAccessibilityForBanking,

          ),

        ],

      ),

    );

  }



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

        children: [

          Icon(Icons.layers, color: Color(0xFFFFCC00), size: 24),

          SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(t('Show Floating Icon'),

                    style: TextStyle(

                        fontSize: 14,

                        fontWeight: FontWeight.bold,

                        color: Colors.white)),

                Text(t('Display status over other apps'),

                    style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),

              ],

            ),

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

            children: [

              Icon(Icons.location_on, color: Color(0xFFFFCC00), size: 20),

              SizedBox(width: 8),

              Expanded(

                child: Text(t('Location Profiles'),

                    style: TextStyle(

                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                        color: Colors.white)),

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

            Text(t('No profiles added. Add a profile for predefined locations.'),

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

      child: Column(

        children: [

          Row(

            children: [

              Expanded(

                child: Column(

                  children: [

                    Text('$_totalAccepted',

                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFFCC00))),

                    Text(t('Accepted'), style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),

                  ],

                ),

              ),

              Container(width: 1, height: 40, color: const Color(0xFF2A2A2A)),

              Expanded(

                child: Column(

                  children: [

                    Text('$_totalSkipped',

                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)),

                    Text(t('Skipped'), style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),

                  ],

                ),

              ),

              Container(width: 1, height: 40, color: const Color(0xFF2A2A2A)),

              Expanded(

                child: Column(

                  children: [

                    Text('₹${_dailyEarnings.toStringAsFixed(0)}',

                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent)),

                    Text(isTamil ? 'இன்றைய வருமானம்' : "Today's Earning", style: const TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),

                    Text('Total: ₹${_totalEarnings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.white38)),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          const Divider(color: Color(0xFF2A2A2A), height: 1),

          const SizedBox(height: 16),

          Row(

            children: [

              Expanded(

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

            ],

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

          Row(

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



    Widget cardContent = AnimatedContainer(

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

                        !app.isAvailable ? 'Coming Soon' : (isEnabled ? 'Listening via Location Profile' : 'Disabled'),

                        style: TextStyle(

                            fontSize: 12,

                            color: !app.isAvailable ? Colors.redAccent : (isEnabled ? app.primaryColor : const Color(0xFF666666))),

                      ),

                    ],

                  ),

                ),

                // Enable toggle

                Switch(

                  value: isEnabled,

                  onChanged: !app.isAvailable ? null : (val) {

                    if (val) {

                      if (_isAdRequired) {

                        _showWatchAdDialog(_adHoursRemaining);

                        return;

                      }

                      final now = DateTime.now().millisecondsSinceEpoch;

                      if (_isDailyLimitActive && _dailyLimitEndTime > now) {

                        _showDailyLimitDialog();

                        return; // STRICT: Does NOT turn on

                      }

                      if (!_serviceActive) {

                        _showSnack('First enable Accessibility Service!');

                        return;

                      }

                    }

                    _setAppEnabled(app.id, val);

                  },

                  activeColor: Colors.blue,

                  activeTrackColor: Colors.red.withOpacity(0.3),

                ),

              ],

            ),

          ),



          if (!app.isAvailable)

            Container(

              width: double.infinity,

              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

              decoration: BoxDecoration(

                color: Colors.redAccent.withOpacity(0.1),

              ),

              child: const Text(

                'Uber auto-accept is temporarily unavailable. We are working on bringing this feature in a future update.',

                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontStyle: FontStyle.italic),

                textAlign: TextAlign.center,

              ),

            ),



          // ── Location input (always visible) ──

          if (app.id == 'ola') ...[

            Padding(

              padding: const EdgeInsets.symmetric(horizontal: 16),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  const Text('Touch protection ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),

                  Switch(

                    value: _olaBlockerEnabled,

                    activeColor: const Color(0xFFFFCC00),

                    onChanged: (val) async {

                      setState(() => _olaBlockerEnabled = val);

                      try {

                        await _channel.invokeMethod('setOlaBlocker', {'enabled': val});

                      } catch (_) {}

                    },

                  ),

                ],

              ),

            ),

            const SizedBox(height: 12),

          ],

          // ── Smart Fare Mode Toggle ──

          if (app.isAvailable)

            Padding(

              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),

              child: AnimatedContainer(

                duration: const Duration(milliseconds: 250),

                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

                decoration: BoxDecoration(

                  color: (_smartFareModeEnabled[app.id] ?? false)

                      ? const Color(0xFF0A1628)

                      : const Color(0xFF222222),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(

                    color: (_smartFareModeEnabled[app.id] ?? false)

                        ? const Color(0xFF2979FF).withOpacity(0.7)

                        : Colors.white12,

                    width: 1.2,

                  ),

                ),

                child: Row(

                  children: [

                    Icon(

                      Icons.price_check_rounded,

                      color: (_smartFareModeEnabled[app.id] ?? false)

                          ? const Color(0xFF2979FF)

                          : Colors.white38,

                      size: 22,

                    ),

                    const SizedBox(width: 10),

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            isTamil ? 'Smart Fare Mode' : 'Smart Fare Mode',

                            style: TextStyle(

                              color: (_smartFareModeEnabled[app.id] ?? false)

                                  ? const Color(0xFF82B1FF)

                                  : Colors.white,

                              fontWeight: FontWeight.bold,

                              fontSize: 13,

                            ),

                          ),

                          const SizedBox(height: 2),

                          Text(

                            (_smartFareModeEnabled[app.id] ?? false)

                                ? (isTamil

                                    ? '✅ KM + கட்டணம் match ஆனால் தானாக accept'

                                    : '✅ Auto-accepts when KM + Price match (no location check)')

                                : (isTamil

                                    ? 'Location name இல்லாமல் KM + கட்டணம் மட்டும் பார்க்கும்'

                                    : 'Accept by KM & Price only — no drop location name needed'),

                            style: const TextStyle(color: Colors.white54, fontSize: 11),

                          ),

                        ],

                      ),

                    ),

                    Switch(

                      value: _smartFareModeEnabled[app.id] ?? false,

                      onChanged: (val) {

                        if (val) {

                          // STRICT: Block if any Location Profile is active

                          final hasActiveProfile = _profiles.any((p) => p.isActive);

                          if (hasActiveProfile) {

                            _showSmartFareConflictDialog();

                            return;

                          }

                        }

                        _setSmartFareMode(app.id, val);

                      },

                      activeColor: const Color(0xFF2979FF),

                      activeTrackColor: const Color(0xFF2979FF).withOpacity(0.3),

                      inactiveThumbColor: const Color(0xFF888888),

                      inactiveTrackColor: const Color(0xFF2A2A2A),

                    ),

                  ],

                ),

              ),

            ),



          Padding(

            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

            child: Column(

              children: [

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



    if (!app.isAvailable) {

      return Opacity(

        opacity: 0.6,

        child: IgnorePointer(child: cardContent),

      );

    }

    return cardContent;

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

          Text(

            isTamil

                ? 'Two Auto-Accept Modes:\n\n'

                  '1. Location Profile Mode:\n'

                  '   • Profile drop location name match aana accept\n'

                  '   • Pickup KM + Drop KM + Price also checked\n\n'

                  '2. Smart Fare Mode (each app card-layum toggle):\n'

                  '   • KM + Price mattum match aana accept (location name vendaam)\n\n'

                  'Oru nerathil oru mode mattum:\n'

                  '   • Smart Fare ON -> Location Profile ON-aa irundha block\n'

                  '   • Location Profile ON -> Smart Fare auto OFF'

                : 'Two Auto-Accept Modes available:\n\n'

                  '1. Location Profile Mode:\n'

                  '   • Accepts when drop location name matches your profile list\n'

                  '   • Also checks Pickup KM, Drop KM, Price range\n\n'

                  '2. Smart Fare Mode (toggle in each app card below):\n'

                  '   • Accepts when Pickup KM + Drop KM + Price match\n'

                  '   • No drop location name check needed\n\n'

                  'Only ONE mode at a time:\n'

                  '   • Smart Fare ON = blocked if any Location Profile is active\n'

                  '   • Location Profile ON = Smart Fare turns OFF automatically',

            style: const TextStyle(fontSize: 12, color: Color(0xFFB3B3B3), height: 1.7),

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

        _history = _history.reversed.toList();

        _loading = false;

      });

    } catch (e) {

      setState(() {

        _loading = false;

      });

    }

  }



  Future<void> _confirmClearHistory() async {

    final confirmed = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        backgroundColor: const Color(0xFF1E1E1E),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: Row(

          children: [

            const Icon(Icons.delete_sweep, color: Colors.redAccent),

            const SizedBox(width: 8),

            Text(

              isTamil ? 'வரலாற்றை அழிக்கவா?' : 'Clear History?',

              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),

            ),

          ],

        ),

        content: Text(

          isTamil

              ? 'அனைத்து சவாரி வரலாறு மற்றும் வருமான விவரங்கள் அழிக்கப்படும். தொடரவா?'

              : 'All saved ride history and earnings will be cleared. Continue?',

          style: const TextStyle(color: Colors.white70),

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: Text(isTamil ? 'ரத்து' : 'Cancel', style: const TextStyle(color: Colors.white54)),

          ),

          ElevatedButton(

            style: ElevatedButton.styleFrom(

              backgroundColor: Colors.redAccent,

              foregroundColor: Colors.white,

            ),

            onPressed: () => Navigator.pop(ctx, true),

            child: Text(isTamil ? 'அழி' : 'Clear', style: const TextStyle(fontWeight: FontWeight.bold)),

          ),

        ],

      ),

    );



    if (confirmed == true) {

      try {

        await _channel.invokeMethod('clearRideHistory');

        setState(() {

          _history = [];

        });

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text(isTamil ? 'சவாரி வரலாறு அழிக்கப்பட்டது!' : 'Ride history cleared successfully!'),

              backgroundColor: Colors.green,

            ),

          );

        }

      } catch (e) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),

          );

        }

      }

    }

  }



  Widget _buildSummaryCard(int trips, double earnings, String period) {

    String label = period;

    if (period == 'daily') {

      label = isTamil ? 'இன்று' : 'Today';

    } else if (period == 'weekly') {

      label = isTamil ? 'இந்த வாரம்' : 'This Week';

    } else if (period == 'monthly') {

      label = isTamil ? 'இந்த மாதம்' : 'This Month';

    } else {

      label = isTamil ? 'மொத்தம்' : 'All Time';

    }



    return Container(

      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: const Color(0xFF1E1E1E),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: const Color(0xFF2E2E2E)),

      ),

      child: Row(

        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [

          Column(

            children: [

              Text(

                '$trips',

                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFFFCC00)),

              ),

              const SizedBox(height: 2),

              Text(

                '$label Trips',

                style: const TextStyle(fontSize: 11, color: Colors.white54),

              ),

            ],

          ),

          Container(width: 1, height: 40, color: const Color(0xFF333333)),

          Column(

            children: [

              Text(

                '₹${earnings.toStringAsFixed(0)}',

                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.greenAccent),

              ),

              const SizedBox(height: 2),

              Text(

                '$label Earnings',

                style: const TextStyle(fontSize: 11, color: Colors.white54),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildPeriodList(String period) {

    final now = DateTime.now();

    final periodRides = _history.where((item) {

      final dt = DateTime.fromMillisecondsSinceEpoch(item['timestamp'] ?? 0);

      if (period == 'daily') {

        return dt.year == now.year && dt.month == now.month && dt.day == now.day;

      } else if (period == 'weekly') {

        final weekAgo = now.subtract(const Duration(days: 7));

        return dt.isAfter(weekAgo);

      } else if (period == 'monthly') {

        return dt.year == now.year && dt.month == now.month;

      }

      return true;

    }).toList();



    final acceptedList = periodRides.where((r) => r['status'] == 'ACCEPTED').toList();

    final int acceptedCount = acceptedList.length;

    final double periodEarnings = acceptedList.fold(0.0, (sum, r) {

      final double fare = (r['fare'] as num?)?.toDouble() ?? 0.0;

      final double tip = (r['tip'] as num?)?.toDouble() ?? 0.0;

      return sum + (fare > 0 ? fare : 0) + (tip > 0 ? tip : 0);

    });



    final filtered = periodRides.where((item) {

      final double fare = (item['fare'] ?? -1.0).toDouble();

      final double pickupKm = (item['pickupKm'] ?? -1.0).toDouble();

      final double dropKm = (item['dropKm'] ?? -1.0).toDouble();

      final bool hasData = fare > 0 || pickupKm >= 0 || dropKm >= 0;



      if (_currentFilter == DataFilter.withData && !hasData) return false;

      if (_currentFilter == DataFilter.withoutData && hasData) return false;



      return true;

    }).toList();



    return Column(

      children: [

        _buildSummaryCard(acceptedCount, periodEarnings, period),

        Expanded(

          child: filtered.isEmpty

              ? Center(

                  child: Text(

                    isTamil ? 'சவாரிகள் எதுவும் இல்லை' : 'No rides found',

                    style: const TextStyle(color: Colors.white54),

                  ),

                )

              : ListView.builder(

                  itemCount: filtered.length,

                  itemBuilder: (context, index) => _buildRideCard(filtered[index]),

                ),

        ),

      ],

    );

  }



  Widget _buildRideCard(dynamic item) {

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

          Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

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

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

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

          Row(

            children: [

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

  }



  @override

  Widget build(BuildContext context) {

    return DefaultTabController(

      length: 4,

      child: Scaffold(

        appBar: AppBar(

          title: Text(t('Ride History'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

          backgroundColor: const Color(0xFF1A1A1A),

          actions: [

            IconButton(

              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),

              tooltip: isTamil ? 'வரலாற்றை அழி' : 'Clear History',

              onPressed: _confirmClearHistory,

            ),

          ],

          bottom: TabBar(

            indicatorColor: const Color(0xFFFFCC00),

            labelColor: const Color(0xFFFFCC00),

            unselectedLabelColor: Colors.white54,

            tabs: [

              Tab(text: isTamil ? 'இன்று' : 'Daily'),

              Tab(text: isTamil ? 'வாரம்' : 'Weekly'),

              Tab(text: isTamil ? 'மாதம்' : 'Monthly'),

              Tab(text: isTamil ? 'அனைத்தும்' : 'All Rides'),

            ],

          ),

        ),

        body: _loading

            ? const Center(child: CircularProgressIndicator())

            : Column(

                children: [

                  Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

                    child: SizedBox(

                      width: double.infinity,

                      child: SegmentedButton<DataFilter>(

                        segments: [

                          ButtonSegment(value: DataFilter.all, label: Text(t('All'))),

                          ButtonSegment(value: DataFilter.withData, label: Text(t('Valid Data'))),

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

                        _buildPeriodList('daily'),

                        _buildPeriodList('weekly'),

                        _buildPeriodList('monthly'),

                        _buildPeriodList('all'),

                      ],

                    ),

                  ),

                ],

              ),

      ),

    );

  }

}

