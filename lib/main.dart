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
import 'location_profiles_page.dart';

import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:shared_preferences/shared_preferences.dart';




bool isTamil = false;
bool isDarkMode = true;
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);

// ─────────────────────────────────────────────────────────────────────────────
// Unified Dynamic App Theme Colors (Guarantees Perfect Contrast in Both Modes)
// ─────────────────────────────────────────────────────────────────────────────
class AppThemeColors {
  static bool get isDark => isDarkMode;

  // Scaffold & App Bar
  static Color get scaffoldBg => isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF6F8FA);
  static Color get appBarBg => isDark ? const Color(0xFF1A1A1A) : Colors.white;
  static Color get appBarTitle => isDark ? Colors.white : const Color(0xFF111827);

  // Cards & Containers
  static Color get cardBg => isDark ? const Color(0xFF1A1A1A) : Colors.white;
  static Color get cardInnerBg => isDark ? const Color(0xFF252525) : const Color(0xFFF8FAFC);
  static Color get cardBorder => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E4E8);

  // Selectors (Language / Theme buttons)
  static Color get selectorBg => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEDF0F3);
  static Color get selectorBorder => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFD1D5DB);
  static Color get selectorUnselectedText => isDark ? Colors.white : const Color(0xFF1E293B);

  // Typography
  static Color get textPrimary => isDark ? Colors.white : const Color(0xFF111827);
  static Color get textSecondary => isDark ? const Color(0xFFB3B3B3) : const Color(0xFF64748B);
  static Color get textMuted => isDark ? Colors.white54 : const Color(0xFF94A3B8);

  // Badges
  static Color get activeBadgeBg => isDark ? const Color(0xFF152A15) : const Color(0xFFE8F5E9);
  static Color get inactiveBadgeBg => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F5);

  // Dialogs
  static Color get dialogBg => isDark ? const Color(0xFF1E1E1E) : Colors.white;
}



final Map<String, String> _ta = {

  'Dark Mode': 'டார்க் மோட்',
  'Light Mode': 'லைட் மோட்',
  'Way 2 Right path': 'Way 2 Right path',
  'Azhai Auto Clicker': 'ஆட்டோ கிளிக்கர்',

  'Open Profile': 'புரொஃபைல்',

  'Ride Accept Automation': 'தானாக சவாரி ஏற்கும் வசதி',

  'Active': 'செயலில்',

  'Show Floating Icon': 'மிதக்கும் ஐகானைக் காட்டு',

  'Display status over other apps': 'மற்ற ஆப்கள் மீதும் நிலையைக் காட்டு',

  'Location Profiles': 'லொகேஷன் ப்ரொஃபைல்ஸ்',
  'Manage Profiles': 'நிர்வகிக்க',
  'Active Profiles': 'செயலில் உள்ளவை',
  'No Location Profile Active': 'எந்த லொகேஷன் ப்ரொஃபைலும் செயலில் இல்லை',
  'Tap to manage profiles or use Smart Fare': 'Profiles-ஐத் தொடவும் அல்லது Smart Fare பயன்படுத்தவும்',
  'Confirm & Start': 'உறுதி செய்து தொடங்கு',
  'Cancel': 'ரத்து செய்',


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
  isDarkMode = prefs.getBool('isDarkMode') ?? true;
  isDarkModeNotifier.value = isDarkMode;

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
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          title: 'Way 2 Right path',
          debugShowCheckedModeBanner: false,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFFCC00),
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Color(0xFF111827),
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F7F9),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF111827),
              elevation: 0.5,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFCC00),
              onPrimary: Color(0xFF0F0F0F),
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          home: home,
        );
      },
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

    isAvailable: true,

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
  AppInfo(
    id: 'zomato',
    name: 'Zomato',
    emoji: '🛵',
    primaryColor: Color(0xFFE23744),
    cardColor: Color(0xFF250D10),
    acceptButtonName: '"Swipe to accept" slider',
  ),
];



// LocationProfile model is imported from location_profiles_page.dart

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

  bool _isAdbConnected = false;
  int _adbConnectPort = -1;
  bool _olaDevBypassEnabled = true;
  bool _isDevOptionsActive = false;
  bool _hasSecureSettingsPermission = false;

  bool _isAppPurchased = false;

  int _totalAccepted = 0;

  int _totalSkipped = 0;

  double _totalEarnings = 0.0;

  String _lastActivity = 'Waiting for ride requests...';
  Map<String, dynamic>? _lastRideDetails;

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

  // Unified Global Ride Filters (Applies to all ride apps: Rapido, Ola, Uber)
  RangeValues _globalPickupRange = const RangeValues(0.0, 5.0);
  RangeValues _globalDropRange = const RangeValues(0.0, 50.0);
  RangeValues _globalPriceRange = const RangeValues(0.0, 1500.0);
  bool _hasUnsavedGlobalFilters = false;

  // Smart Fare Mode — per-app toggle (new feature)

  // When ON: accepts based on KM + Price only — no location name check needed

  final Map<String, bool> _smartFareModeEnabled = {};



  // Location Profiles

  List<LocationProfile> _profiles = [];
  final Map<String, bool> _hasUnsavedFilters = {};



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

    _checkAdbStatus();
    _checkOlaDevBypassStatus();

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

            backgroundColor: AppThemeColors.dialogBg,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

            title: Row(

              children: [

                const Icon(Icons.play_circle_filled, color: Color(0xFF00C853), size: 28),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    isTamil ? 'விளம்பரம் பார்க்கவும்' : 'Watch Ad to Continue',

                    style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),

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

                        style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 13),

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

                    foregroundColor: AppThemeColors.textPrimary,

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

      if (call.method == 'onRideEvent') {
        final raw = call.arguments as Map? ?? {};
        final data = Map<String, dynamic>.from(raw);
        setState(() {
          _lastRideDetails = data;
          final status = (data['status'] ?? '').toString();
          final app = data['appName'] ?? '';
          final loc = data['dropLocation'] ?? data['location'] ?? '';
          final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
          final fareStr = fare > 0 ? ' • ₹${fare.toStringAsFixed(0)}' : '';

          if (status == 'ACCEPTED') {
            _lastActivity = '✅ [$app] Accepted → $loc$fareStr';
          } else if (status == 'SKIPPED') {
            _lastActivity = '❌ [$app] Skipped → $loc$fareStr';
          } else if (status == 'DETECTED') {
            _lastActivity = '⏳ [$app] Incoming → $loc$fareStr';
          }
        });
      } else if (call.method == 'onRideAccepted') {

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

      } else if (call.method == 'onRideSkipped') {
        final appName = call.arguments['appName'] as String? ?? '';
        final location = call.arguments['location'] as String? ?? '';
        setState(() {
          _totalSkipped++;
          _lastActivity = '❌ [$appName] Skipped → $location';
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
          // Load Global Ride Filters
          double gPickupMin = (result['global_pickup_min'] as num?)?.toDouble() ?? (result['rapido_pickup_min'] as num?)?.toDouble() ?? 0.0;
          double gPickupMax = (result['global_pickup_max'] as num?)?.toDouble() ?? (result['rapido_pickup_max'] as num?)?.toDouble() ?? 5.0;
          if (gPickupMax > 5.0) gPickupMax = 5.0;
          _globalPickupRange = RangeValues(gPickupMin, gPickupMax);

          double gDropMin = (result['global_drop_min'] as num?)?.toDouble() ?? (result['rapido_drop_min'] as num?)?.toDouble() ?? 0.0;
          double gDropMax = (result['global_drop_max'] as num?)?.toDouble() ?? (result['rapido_drop_max'] as num?)?.toDouble() ?? 50.0;
          if (gDropMax > 100.0) gDropMax = 100.0;
          _globalDropRange = RangeValues(gDropMin, gDropMax);

          double gPriceMin = (result['global_price_min'] as num?)?.toDouble() ?? (result['rapido_price_min'] as num?)?.toDouble() ?? 0.0;
          double gPriceMax = (result['global_price_max'] as num?)?.toDouble() ?? (result['rapido_price_max'] as num?)?.toDouble() ?? 1500.0;
          if (gPriceMax > 2000.0) gPriceMax = 2000.0;
          _globalPriceRange = RangeValues(gPriceMin, gPriceMax);

          for (final app in kApps) {
            _appEnabled[app.id] = result['${app.id}_enabled'] as bool? ?? false;
            _pickupRanges[app.id] = _globalPickupRange;
            _dropRanges[app.id] = _globalDropRange;
            _priceRanges[app.id] = _globalPriceRange;
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

          final historyJson = result['ride_history'] as String? ?? '[]';
          try {
            final List hList = jsonDecode(historyJson);
            if (hList.isNotEmpty) {
              _lastRideDetails = Map<String, dynamic>.from(hList.last);
              final r = _lastRideDetails!;
              final status = r['status'] ?? '';
              final app = r['appName'] ?? '';
              final loc = r['dropLocation'] ?? r['location'] ?? '';
              final fare = (r['fare'] as num?)?.toDouble() ?? 0.0;
              final fareStr = fare > 0 ? ' • ₹${fare.toStringAsFixed(0)}' : '';
              if (status == 'ACCEPTED') {
                _lastActivity = '✅ [$app] Accepted → $loc$fareStr';
              } else if (status == 'SKIPPED') {
                _lastActivity = '❌ [$app] Skipped → $loc$fareStr';
              }
            }
          } catch (_) {}

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

                  backgroundColor: AppThemeColors.dialogBg,

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                  title: Text('Free Trial Ended', style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold)),

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

                        foregroundColor: AppThemeColors.textPrimary,

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

            backgroundColor: AppThemeColors.dialogBg,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

            title: Row(

              children: [

                const Icon(Icons.system_update, color: Colors.blueAccent, size: 28),

                const SizedBox(width: 8),

                Text(

                  isTamil ? 'புதிய அப்டேட் தேவை!' : 'Update Required!',

                  style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold),

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

                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),

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

                    foregroundColor: AppThemeColors.textPrimary,

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

                backgroundColor: AppThemeColors.dialogBg,

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                title: Row(

                  children: [

                    const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 28),

                    const SizedBox(width: 8),

                    Text(

                      isTamil ? 'இன்றைய வரம்பு முடிந்தது!' : "Today's Limit Reached!",

                      style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),

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

                            style: TextStyle(color: AppThemeColors.textMuted, fontSize: 11),

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

          backgroundColor: AppThemeColors.dialogBg,

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

          backgroundColor: AppThemeColors.dialogBg,

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
    final activeLocsList = <String>[];
    for (final p in _profiles) {
      if (p.isActive) {
        final split = p.locations.split(RegExp(r'[,;\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty);
        activeLocsList.addAll(split);
      }
    }
    final activeLocations = activeLocsList.join(',');

    try {
      await _channel.invokeMethod('setLocationProfiles', {
        'profilesJson': jsonStr,
        'activeLocations': activeLocations,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locationProfiles', jsonStr);
      await prefs.setString('global_active_locations', activeLocations);
    } catch (_) {}
  }

  Future<void> _openLocationProfilesPage() async {
    final activeSmartFareApps = kApps
        .where((a) => _smartFareModeEnabled[a.id] == true)
        .map((a) => a.name)
        .toList();

    final updatedProfiles = await Navigator.push<List<LocationProfile>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationProfilesPage(
          profiles: _profiles,
          isTamil: isTamil,
          isDarkMode: isDarkMode,
          isSmartFareActive: activeSmartFareApps.isNotEmpty,
          smartFareApps: activeSmartFareApps,
        ),
      ),
    );

    if (updatedProfiles != null && mounted) {
      final hasActive = updatedProfiles.any((p) => p.isActive);
      setState(() {
        _profiles = updatedProfiles;
        if (hasActive) {
          // If any profile is turned ON, turn OFF Smart Fare Mode for all apps
          for (final app in kApps) {
            if (_smartFareModeEnabled[app.id] == true) {
              _smartFareModeEnabled[app.id] = false;
              _setSmartFareMode(app.id, false);
            }
          }
        }
      });
      _saveProfiles();
    }
  }

  void _showAppEnableConfirmationDialog(AppInfo app) {
    if (app.id == 'zomato') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppThemeColors.dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.swipe_right_rounded, color: Color(0xFFE23744)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Zomato Auto Swipe',
                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            isTamil
                ? 'Zomato-வில் உணவு டெலிவரி ஆர்டர் வரும்போது "Swipe to accept" பட்டன் தானாகவே ஸ்வைப் செய்து ஏற்றுக்கொள்ளப்படும்.'
                : 'When a Zomato order arrives, the "Swipe to accept" slider will be automatically swiped to accept the order.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('Cancel'), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE23744),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _setAppEnabled(app.id, true);
              },
              child: Text(
                isTamil ? 'தொடங்கு (Start)' : 'START',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final isSmartFare = _smartFareModeEnabled[app.id] ?? false;

    if (isSmartFare) {
      final pMin = _pickupRanges[app.id]!.start.toStringAsFixed(1);
      final pMax = _pickupRanges[app.id]!.end.toStringAsFixed(1);
      final dMin = _dropRanges[app.id]!.start.toStringAsFixed(1);
      final dMax = _dropRanges[app.id]!.end.toStringAsFixed(1);
      final prMin = _priceRanges[app.id]!.start.toStringAsFixed(0);
      final prMax = _priceRanges[app.id]!.end.toStringAsFixed(0);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppThemeColors.dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.flash_on, color: Color(0xFF2979FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${app.name} - Smart Fare Confirm',
                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2979FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF2979FF), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTamil
                            ? 'Smart Fare ஆன்-ல் உள்ளது. Drop Location பெயர் பார்க்கப்படாது.'
                            : 'Smart Fare is ON. Drop location name is NOT required.',
                        style: const TextStyle(color: Color(0xFF2979FF), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isTamil ? 'சேமிக்கப்பட்ட ஃபில்டர்கள்:' : 'Saved Filter Range:',
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              _buildDialogInfoRow(Icons.directions_walk, 'Pickup', '$pMin - $pMax KM'),
              _buildDialogInfoRow(Icons.pin_drop, 'Drop', '$dMin - $dMax KM'),
              _buildDialogInfoRow(Icons.currency_rupee, 'Fare', '₹$prMin - ₹$prMax'),
              const SizedBox(height: 12),
              Text(
                isTamil
                    ? 'இந்த அளவுகளுக்குள் வரும் சவாரிகள் தானாக ஏற்றுக்கொள்ளப்படும்.'
                    : 'Rides falling within these limits will be automatically accepted.',
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('Cancel'), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2979FF),
                foregroundColor: AppThemeColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _setAppEnabled(app.id, true);
              },
              child: Text(
                isTamil ? 'உறுதி செய் (Confirm)' : 'CONFIRM & START',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      final activeProfiles = _profiles.where((p) => p.isActive).toList();

      if (activeProfiles.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppThemeColors.dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFFCC00)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No Active Profile',
                    style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              isTamil
                  ? 'எந்த Location Profile-ம் ஆன்-ல் இல்லை! Auto Clicker இயங்க குறைந்தபட்சம் ஒரு Profile ஆன்-ல் இருக்க வேண்டும், அல்லது Smart Fare Mode-ஐப் பயன்படுத்தவும்.'
                  : 'No Location Profile is turned ON! You must activate at least one profile to accept rides, or enable Smart Fare Mode.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('Cancel'), style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openLocationProfilesPage();
                },
                child: Text(
                  isTamil ? 'Profiles திற' : 'Open Profiles',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
        return;
      }

      final pMin = _pickupRanges[app.id]!.start.toStringAsFixed(1);
      final pMax = _pickupRanges[app.id]!.end.toStringAsFixed(1);
      final dMin = _dropRanges[app.id]!.start.toStringAsFixed(1);
      final dMax = _dropRanges[app.id]!.end.toStringAsFixed(1);
      final prMin = _priceRanges[app.id]!.start.toStringAsFixed(0);
      final prMax = _priceRanges[app.id]!.end.toStringAsFixed(0);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppThemeColors.dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF00C853)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${app.name} - Confirm Start',
                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTamil ? 'செயலில் உள்ள லொகேஷன் ப்ரொஃபைல்கள்:' : 'Active Location Profiles:',
                  style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...activeProfiles.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏡 ${p.name}',
                            style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.locations,
                            style: TextStyle(color: AppThemeColors.textSecondary, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 10),
                Text(
                  isTamil ? 'ஃபில்டர் அளவுகள்:' : 'Filter Limits:',
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                _buildDialogInfoRow(Icons.directions_walk, 'Pickup', '$pMin - $pMax KM'),
                _buildDialogInfoRow(Icons.pin_drop, 'Drop', '$dMin - $dMax KM'),
                _buildDialogInfoRow(Icons.currency_rupee, 'Fare', '₹$prMin - ₹$prMax'),
                const SizedBox(height: 10),
                Text(
                  isTamil
                      ? 'மேலே உள்ள Active Profile Drop Location மேட்ச் ஆனால் மட்டுமே சவாரி ஏற்றுக்கொள்ளப்படும்.'
                      : 'Rides will ONLY be accepted if the drop location matches these active profiles and limits.',
                  style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('Cancel'), style: const TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: AppThemeColors.textPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _setAppEnabled(app.id, true);
              },
              child: Text(
                isTamil ? 'உறுதி செய் (Confirm)' : 'CONFIRM & START',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(value, style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _setAppEnabled(String appId, bool value) async {

    setState(() => _appEnabled[appId] = value);

    try {

      await _channel.invokeMethod('setAppEnabled', {'appId': appId, 'enabled': value});

    } catch (_) {}

    // Auto-enable HUD floating icon when any app toggle is turned on
    if (value) {
      if (!_isHUDEnabled) {
        _setHUDEnabled(true);
      }
    } else {
      // Auto-hide HUD when all app automations are turned off
      final anyActive = _appEnabled.values.any((v) => v);
      if (!anyActive && _isHUDEnabled) {
        _setHUDEnabled(false);
      }
    }

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

        backgroundColor: AppThemeColors.dialogBg,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: Row(

          children: [

            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 26),

            SizedBox(width: 8),

            Text('Mode Conflict!', style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),

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

  Future<void> _saveGlobalFilters() async {
    try {
      await _channel.invokeMethod('setGlobalFilters', {
        'pickupMin': _globalPickupRange.start,
        'pickupMax': _globalPickupRange.end,
        'dropMin': _globalDropRange.start,
        'dropMax': _globalDropRange.end,
        'priceMin': _globalPriceRange.start,
        'priceMax': _globalPriceRange.end,
      });

      // Synchronize in-memory per-app ranges
      for (final app in kApps) {
        _pickupRanges[app.id] = _globalPickupRange;
        _dropRanges[app.id] = _globalDropRange;
        _priceRanges[app.id] = _globalPriceRange;
        _hasUnsavedFilters[app.id] = false;
      }

      setState(() {
        _hasUnsavedGlobalFilters = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTamil ? '✅ அனைத்து செயலிகளுக்குமான ஃபில்டர்கள் சேமிக்கப்பட்டன!' : '✅ Global filters saved for all apps!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {}
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
      backgroundColor: isDarkMode ? const Color(0xFF0F0F0F) : const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: Text(t('Way 2 Right path'), style: TextStyle(fontWeight: FontWeight.bold, color: AppThemeColors.appBarTitle)),
        backgroundColor: AppThemeColors.appBarBg,
        elevation: isDarkMode ? 0 : 0.5,
        systemOverlayStyle: isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,

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
              const SizedBox(height: 8),
              _buildThemeSelector(),
              const SizedBox(height: 12),

              _buildHeader(),

              const SizedBox(height: 16),

              _buildBankingModeCard(),

              const SizedBox(height: 16),

              _buildAdbWirelessCard(),

              const SizedBox(height: 16),

              _buildHUDToggleCard(),

              const SizedBox(height: 16),

              _buildProfilesCard(),

              const SizedBox(height: 16),

              _buildGlobalFilterCard(),

              const SizedBox(height: 16),

              SizedBox(

                width: double.infinity,

                child: ElevatedButton.icon(

                  icon: const Icon(Icons.history, size: 18),

                  label: Text(t('Open Ride History Page'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

              const SizedBox(height: 14),

              _buildLastActivityCard(),

              const SizedBox(height: 14),

              if (!_serviceActive) _buildAccessibilityWarningCard(),

              if (!_serviceActive) const SizedBox(height: 16),



              // ── 4 App Cards ──

              Text(

                t('Apps'),

                style: TextStyle(

                    fontSize: 18, fontWeight: FontWeight.bold, color: AppThemeColors.textPrimary),

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
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E4E8)),
      ),
      child: SegmentedButton<bool>(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) return const Color(0xFFFFCC00);
            return Colors.transparent;
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) return Colors.black;
            return isDarkMode ? Colors.white : const Color(0xFF111827);
          }),
        ),
        segments: const [
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

  Widget _buildThemeSelector() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E4E8)),
      ),
      child: SegmentedButton<bool>(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) return const Color(0xFFFFCC00);
            return Colors.transparent;
          }),
          foregroundColor: MaterialStateProperty.resolveWith<Color>((Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) return Colors.black;
            return isDarkMode ? Colors.white : const Color(0xFF111827);
          }),
        ),
        segments: [
          ButtonSegment(
            value: true,
            icon: const Icon(Icons.dark_mode, size: 16),
            label: Text(t('Dark Mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ButtonSegment(
            value: false,
            icon: const Icon(Icons.light_mode, size: 16),
            label: Text(t('Light Mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        selected: {isDarkMode},
        onSelectionChanged: (Set<bool> newSelection) async {
          setState(() {
            isDarkMode = newSelection.first;
            isDarkModeNotifier.value = isDarkMode;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isDarkMode', isDarkMode);
        },
      ),
    );
  }

  Widget _buildHeader() {
    final activeCount = _appEnabled.values.where((v) => v).length;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Way 2 Right path'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppThemeColors.textPrimary,
                ),
              ),
              Text(
                t('Smart Route Assistant'),
                style: TextStyle(fontSize: 13, color: AppThemeColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: activeCount > 0 ? AppThemeColors.activeBadgeBg : AppThemeColors.inactiveBadgeBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: activeCount > 0 ? const Color(0xFF4CAF50) : AppThemeColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: activeCount > 0 ? const Color(0xFF4CAF50) : AppThemeColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$activeCount ${t("Active")}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: activeCount > 0
                      ? (isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF1B5E20))
                      : AppThemeColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankingModeCard() {

    if (!_serviceActive) {

      return Container(

        width: double.infinity,

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(

          color: isDarkMode ? const Color(0xFF142414) : const Color(0xFFE8F5E9),

          borderRadius: BorderRadius.circular(14),

          border: Border.all(color: isDarkMode ? const Color(0xFF1B5E20) : const Color(0xFF81C784)),

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

                    style: TextStyle(color: AppThemeColors.textSecondary, fontSize: 11),

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

        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDarkMode ? const Color(0xFF2E3A4E) : const Color(0xFFE2E4E8)),

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

                  style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),

                ),

                const SizedBox(height: 2),

                Text(

                  isTamil ? 'GPay/PhonePe பயன்படுத்த 1-கிளிக்கில் ஆஃப் செய்யலாம்' : '1-tap disable before opening bank apps',

                  style: TextStyle(color: isDarkMode ? Colors.white60 : const Color(0xFF6B7280), fontSize: 11),

                ),

              ],

            ),

          ),

          const SizedBox(width: 8),

          ElevatedButton.icon(

            style: ElevatedButton.styleFrom(

              backgroundColor: isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD),
              foregroundColor: isDarkMode ? const Color(0xFF64B5F6) : const Color(0xFF1976D2),

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



  Future<void> _checkAdbStatus() async {
    try {
      final res = await _channel.invokeMethod<Map>('getAdbStatus');
      if (res != null && mounted) {
        setState(() {
          _isAdbConnected = res['isConnected'] == true;
          _adbConnectPort = (res['connectPort'] as int?) ?? -1;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkOlaDevBypassStatus() async {
    try {
      final res = await _channel.invokeMethod<Map>('getOlaDevBypassStatus');
      if (res != null && mounted) {
        setState(() {
          _olaDevBypassEnabled = res['isBypassEnabled'] == true;
          _isDevOptionsActive = res['isDevOptionsActive'] == true;
          _hasSecureSettingsPermission = res['hasPermission'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleOlaDevBypass(bool val) async {
    try {
      final res = await _channel.invokeMethod<Map>('setOlaDevBypass', {'enabled': val});
      final msg = res?['message'] ?? (val ? 'Ola Developer Options Bypass Activated' : 'Developer Options Restored');
      _showSnack(msg);
      await _checkOlaDevBypassStatus();
      await _checkAdbStatus();
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showAdbPairingDialog() {
    final pairingPortCtrl = TextEditingController();
    final pairingCodeCtrl = TextEditingController();
    final connectPortCtrl = TextEditingController(text: _adbConnectPort > 0 ? '$_adbConnectPort' : '');
    bool isPairing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppThemeColors.dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.wifi_tethering, color: Color(0xFF2196F3), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTamil ? 'WiFi ADB செட்டப் (Ola & Uber)' : 'WiFi ADB Setup (Ola & Uber)',
                  style: TextStyle(
                    color: AppThemeColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTamil ? '📖 எளிய வழிமுறைகள் (Steps):' : '📖 Simple Steps:',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isTamil
                            ? '1️⃣ Phone Settings ➔ Developer Options ➔ Wireless Debugging ஆன் செய்யவும்.\n'
                              '2️⃣ "Pair device with pairing code" தொடவும் (Keep in Split-screen).\n'
                              '3️⃣ பாப்-அப்பில் உள்ள 5-இலக்க Pairing Port & 6-இலக்க Code உள்ளிடவும்.\n'
                              '4️⃣ பாப்-அப்-க்கு வெளியே திரையில் காட்டும் 5-இலக்க Main Port-ஐ உள்ளிடவும்.\n'
                              '💡 ஏற்கனவே Settings-ல் AutoClicker "Paired devices"-ல் இருந்தால், Main Port மட்டும் கொடுத்து "Connect Only" அழுத்தினால் போதும்!'
                            : '1️⃣ Open Settings ➔ Developer Options ➔ Wireless Debugging.\n'
                              '2️⃣ Tap "Pair device with pairing code" (use Split-screen).\n'
                              '3️⃣ Enter 5-digit Pairing Port & 6-digit Code from popup.\n'
                              '4️⃣ Enter 5-digit Main Port from outside popup on main screen.\n'
                              '💡 If already paired in Settings, just enter Main Port and tap "Connect Only"!',
                        style: TextStyle(
                          color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pairingPortCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isTamil ? 'Pairing Port (எ.கா: 38491)' : 'Pairing Port (e.g. 38491)',
                    labelStyle: TextStyle(color: AppThemeColors.textSecondary, fontSize: 12),
                    hintText: '38491',
                    hintStyle: TextStyle(color: AppThemeColors.textMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.numbers, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: pairingCodeCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isTamil ? '6-Digit Pairing Code (எ.கா: 481923)' : '6-Digit Pairing Code (e.g. 481923)',
                    labelStyle: TextStyle(color: AppThemeColors.textSecondary, fontSize: 12),
                    hintText: '481923',
                    hintStyle: TextStyle(color: AppThemeColors.textMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.password, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: connectPortCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: isTamil ? 'Main Connect Port (எ.கா: 41235)' : 'Main Connect Port (e.g. 41235)',
                    labelStyle: TextStyle(color: AppThemeColors.textSecondary, fontSize: 12),
                    hintText: '41235',
                    hintStyle: TextStyle(color: AppThemeColors.textMuted, fontSize: 12),
                    prefixIcon: const Icon(Icons.lan, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (_isAdbConnected) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isTamil ? 'இணைப்பு செயலில் உள்ளது (Port: $_adbConnectPort)' : 'ADB is active on Port: $_adbConnectPort',
                            style: const TextStyle(color: Color(0xFF00C853), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _olaDevBypassEnabled
                        ? (isDarkMode ? const Color(0xFF0F2618) : const Color(0xFFF0FDF4))
                        : (isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _olaDevBypassEnabled ? const Color(0xFF00C853).withOpacity(0.5) : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: _olaDevBypassEnabled ? const Color(0xFF00C853) : Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTamil ? 'Ola Dev Options மறைப்பு' : 'Ola Dev Options Bypass',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppThemeColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isTamil ? 'Ola "Disable developer options" வராமல் தடுக்கும்' : 'Prevents Ola "Disable developer options" popup',
                              style: TextStyle(fontSize: 10, color: AppThemeColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _olaDevBypassEnabled,
                        activeColor: const Color(0xFF00C853),
                        onChanged: (v) async {
                          await _toggleOlaDevBypass(v);
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_isAdbConnected)
              TextButton.icon(
                icon: const Icon(Icons.touch_app, size: 16, color: Color(0xFF2196F3)),
                label: Text(
                  isTamil ? 'டச் டெஸ்ட்' : 'Test Tap',
                  style: const TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final ok = await _channel.invokeMethod<bool>('testAdbTap', {'x': 500.0, 'y': 1000.0});
                  _showSnack(ok == true ? '✅ Hardware tap sent!' : 'Tap failed - check port');
                },
              ),
            if (_isAdbConnected)
              TextButton(
                onPressed: () async {
                  await _channel.invokeMethod('disconnectAdb');
                  await _checkAdbStatus();
                  await _checkOlaDevBypassStatus();
                  Navigator.pop(ctx);
                  _showSnack('WiFi ADB Disconnected');
                },
                child: Text(isTamil ? 'துண்டி' : 'Disconnect', style: const TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isTamil ? 'மூடு' : 'Close', style: TextStyle(color: AppThemeColors.textSecondary)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2196F3),
                side: const BorderSide(color: Color(0xFF2196F3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isPairing
                  ? null
                  : () async {
                      final cPort = int.tryParse(connectPortCtrl.text.trim()) ?? 0;
                      if (cPort <= 0) {
                        _showSnack(isTamil ? 'தயவுசெய்து Main Connect Port உள்ளிடவும் (Settings திரையில் உள்ளது)' : 'Please enter Main Connect Port (shown on Settings screen)');
                        return;
                      }
                      setDialogState(() => isPairing = true);
                      try {
                        final res = await _channel.invokeMethod<Map>('connectAdbOnly', {'connectPort': cPort});
                        setDialogState(() => isPairing = false);
                        await _checkAdbStatus();
                        final isSuccess = res?['success'] == true;
                        if (isSuccess) {
                          Navigator.pop(ctx);
                        }
                        _showSnack(res?['message']?.toString() ?? (isSuccess ? 'Connected!' : 'Connect failed'));
                      } catch (e) {
                        setDialogState(() => isPairing = false);
                        _showSnack('Connect failed: $e');
                      }
                    },
              child: Text(isTamil ? 'இணை மட்டும்' : 'Connect Only', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFCC00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isPairing
                  ? null
                  : () async {
                      final pPort = int.tryParse(pairingPortCtrl.text.trim()) ?? 0;
                      final code = pairingCodeCtrl.text.trim();
                      final cPort = int.tryParse(connectPortCtrl.text.trim()) ?? pPort;

                      if (pPort <= 0 || cPort <= 0) {
                        _showSnack('Please enter a valid Port number');
                        return;
                      }

                      if (pPort == cPort) {
                        _showSnack(isTamil ? '⚠️ Pairing Port மற்றும் Main Port வெவ்வேறாக இருக்க வேண்டும்!' : '⚠️ Pairing Port & Main Port must be different!');
                        return;
                      }

                      setDialogState(() => isPairing = true);
                      try {
                        final res = await _channel.invokeMethod<Map>('pairAdb', {
                          'pairingPort': pPort,
                          'pairingCode': code,
                          'connectPort': cPort,
                        });
                        setDialogState(() => isPairing = false);
                        await _checkAdbStatus();
                        final isSuccess = res?['success'] == true;
                        if (isSuccess) {
                          Navigator.pop(ctx);
                        }
                        _showSnack(res?['message']?.toString() ?? (isSuccess ? 'Pairing complete!' : 'Pairing failed'));
                      } catch (e) {
                        setDialogState(() => isPairing = false);
                        _showSnack('Pairing failed: $e');
                      }
                    },
              child: isPairing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Text(isTamil ? 'Pair செய்து இணை' : 'Pair & Connect', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdbWirelessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAdbConnected ? const Color(0xFF00C853).withOpacity(0.5) : AppThemeColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: (_isAdbConnected ? const Color(0xFF00C853) : const Color(0xFF2196F3)).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_tethering,
              color: _isAdbConnected ? const Color(0xFF00C853) : const Color(0xFF2196F3),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isTamil ? 'WiFi ADB (Ola & Uber)' : 'WiFi ADB (Ola & Uber)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _isAdbConnected
                            ? (isDarkMode ? const Color(0xFF152A15) : const Color(0xFFDCFCE7))
                            : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isAdbConnected ? const Color(0xFF00C853) : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _isAdbConnected ? 'CONNECTED' : 'OFF',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: _isAdbConnected ? const Color(0xFF00C853) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _isAdbConnected
                      ? (isTamil
                          ? (_olaDevBypassEnabled
                              ? 'ஹார்டுவேர் டச் தயார் • Ola Bypass ஆன் (Port: $_adbConnectPort)'
                              : 'ஹார்டுவேர் டச் தயார் (Port: $_adbConnectPort)')
                          : (_olaDevBypassEnabled
                              ? 'Hardware touch active • Ola Bypass ON (Port: $_adbConnectPort)'
                              : 'Hardware touch active (Port: $_adbConnectPort)'))
                      : (isTamil ? 'Ola & Uber-ல் பிளாக் ஆகாமல் கிளிக் செய்ய Pair செய்' : 'Pair to bypass anti-bot click in Ola/Uber'),
                  style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAdbConnected ? const Color(0xFF1B5E20) : const Color(0xFFFFCC00),
              foregroundColor: _isAdbConnected ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showAdbPairingDialog,
            child: Text(
              _isAdbConnected ? (isTamil ? 'விவரம்' : 'Manage') : (isTamil ? 'இணை' : 'Pair'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
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
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers, color: Color(0xFFFFCC00), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Show Floating Icon'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
                Text(
                  t('Display status over other apps'),
                  style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: _isHUDEnabled,
            onChanged: _setHUDEnabled,
            activeColor: Colors.black,
            activeTrackColor: const Color(0xFFFFCC00),
            inactiveThumbColor: isDarkMode ? const Color(0xFF888888) : const Color(0xFF9E9E9E),
            inactiveTrackColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesCard() {
    final activeProfiles = _profiles.where((p) => p.isActive).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeProfiles.isNotEmpty ? const Color(0xFF00C853).withOpacity(0.5) : AppThemeColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFFCC00), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('Location Profiles'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.tune, color: Color(0xFFFFCC00), size: 16),
                label: Text(
                  t('Manage Profiles'),
                  style: TextStyle(
                    color: isDarkMode ? const Color(0xFFFFCC00) : const Color(0xFFB45309),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFFEF3C7),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openLocationProfilesPage,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (activeProfiles.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF152A15) : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00C853).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${t("Active Profiles")} (${activeProfiles.length})',
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFF00C853) : const Color(0xFF166534),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...activeProfiles.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppThemeColors.cardInnerBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00C853).withOpacity(isDarkMode ? 0.2 : 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Color(0xFF00C853)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppThemeColors.textPrimary,
                              ),
                            ),
                            Text(
                              p.locations,
                              style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check, size: 16, color: Color(0xFF00C853)),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            Text(
              isTamil
                  ? 'மேலே உள்ள Active Profile Drop Location மேட்ச் ஆனால் மட்டுமே சவாரி ஏற்றுக்கொள்ளப்படும்.'
                  : 'Rides will ONLY be accepted for drops matching these active profiles.',
              style: TextStyle(fontSize: 11, color: AppThemeColors.textMuted, fontStyle: FontStyle.italic),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2000) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCC00).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFCC00), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('No Location Profile Active'),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          t('Tap to manage profiles or use Smart Fare'),
                          style: TextStyle(
                            color: isDarkMode ? const Color(0xFFB3B3B3) : const Color(0xFF78350F),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Unified Global Ride Filters Card (Applies to all ride hailing apps) ─────
  Widget _buildGlobalFilterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _hasUnsavedGlobalFilters
              ? const Color(0xFFFFCC00).withOpacity(0.8)
              : AppThemeColors.cardBorder,
          width: _hasUnsavedGlobalFilters ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Color(0xFFFFCC00), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTamil ? 'ரைடு ஃபில்டர்கள் (அனைத்து செயலிகளுக்கும்)' : 'Ride Filters (All Apps)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isTamil
                          ? 'Rapido, Ola, Uber - அனைத்திற்கும் பொதுவான ஃபில்டர்'
                          : 'Applies to Rapido, Ola, Uber simultaneously',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppThemeColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Pickup Distance Slider ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.my_location, size: 14, color: Color(0xFF00C853)),
                  const SizedBox(width: 6),
                  Text(
                    isTamil ? 'பிக்கப் தூரம் (Pickup):' : 'Pickup Distance:',
                    style: TextStyle(
                      color: isDarkMode ? AppThemeColors.textSecondary : const Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_globalPickupRange.start.toStringAsFixed(1)} - ${_globalPickupRange.end.toStringAsFixed(1)} KM',
                style: const TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
              activeTrackColor: const Color(0xFF00C853),
              thumbColor: const Color(0xFF00C853),
              inactiveTrackColor: isDarkMode ? Colors.white12 : const Color(0xFFE2E4E8),
            ),
            child: RangeSlider(
              values: _globalPickupRange,
              min: 0.0,
              max: 5.0,
              divisions: 50,
              labels: RangeLabels(
                '${_globalPickupRange.start.toStringAsFixed(1)} KM',
                '${_globalPickupRange.end.toStringAsFixed(1)} KM',
              ),
              onChanged: (vals) => setState(() {
                _globalPickupRange = vals;
                _hasUnsavedGlobalFilters = true;
              }),
            ),
          ),

          // ── Drop Distance Slider ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF2979FF)),
                  const SizedBox(width: 6),
                  Text(
                    isTamil ? 'டிராப் தூரம் (Drop):' : 'Drop Distance:',
                    style: TextStyle(
                      color: isDarkMode ? AppThemeColors.textSecondary : const Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '${_globalDropRange.start.toStringAsFixed(1)} - ${_globalDropRange.end.toStringAsFixed(1)} KM',
                style: const TextStyle(
                  color: Color(0xFF2979FF),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
              activeTrackColor: const Color(0xFF2979FF),
              thumbColor: const Color(0xFF2979FF),
              inactiveTrackColor: isDarkMode ? Colors.white12 : const Color(0xFFE2E4E8),
            ),
            child: RangeSlider(
              values: _globalDropRange,
              min: 0.0,
              max: 100.0,
              divisions: 100,
              labels: RangeLabels(
                '${_globalDropRange.start.toStringAsFixed(1)} KM',
                '${_globalDropRange.end.toStringAsFixed(1)} KM',
              ),
              onChanged: (vals) => setState(() {
                _globalDropRange = vals;
                _hasUnsavedGlobalFilters = true;
              }),
            ),
          ),

          // ── Price Slider ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.currency_rupee, size: 14, color: Color(0xFFFFCC00)),
                  const SizedBox(width: 6),
                  Text(
                    isTamil ? 'கட்டணம் (Price):' : 'Price / Fare:',
                    style: TextStyle(
                      color: isDarkMode ? AppThemeColors.textSecondary : const Color(0xFF374151),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Text(
                '₹${_globalPriceRange.start.toStringAsFixed(0)} - ₹${_globalPriceRange.end.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFFFFCC00),
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
              activeTrackColor: const Color(0xFFFFCC00),
              thumbColor: const Color(0xFFFFCC00),
              inactiveTrackColor: isDarkMode ? Colors.white12 : const Color(0xFFE2E4E8),
            ),
            child: RangeSlider(
              values: _globalPriceRange,
              min: 0.0,
              max: 2000.0,
              divisions: 200,
              labels: RangeLabels(
                '₹${_globalPriceRange.start.toStringAsFixed(0)}',
                '₹${_globalPriceRange.end.toStringAsFixed(0)}',
              ),
              onChanged: (vals) => setState(() {
                _globalPriceRange = vals;
                _hasUnsavedGlobalFilters = true;
              }),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(
                Icons.save,
                size: 16,
                color: _hasUnsavedGlobalFilters
                    ? Colors.black
                    : (isDarkMode ? const Color(0xFFFFCC00) : const Color(0xFFD97706)),
              ),
              label: Text(
                _hasUnsavedGlobalFilters
                    ? (isTamil ? 'அனைத்து செயலிகளுக்கும் சேமிக்க (மாற்றங்கள் உள்ளன)' : 'SAVE FILTERS FOR ALL APPS (Unsaved)')
                    : (isTamil ? 'அனைத்து செயலிகளுக்கும் சேமிக்கப்பட்டது (SAVED)' : 'SAVE FILTERS FOR ALL APPS (SAVED)'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _hasUnsavedGlobalFilters
                      ? Colors.black
                      : (isDarkMode ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasUnsavedGlobalFilters
                    ? const Color(0xFFFFCC00)
                    : (isDarkMode ? const Color(0xFF262626) : const Color(0xFFF1F5F9)),
                foregroundColor: _hasUnsavedGlobalFilters
                    ? Colors.black
                    : (isDarkMode ? Colors.white70 : const Color(0xFF334155)),
                elevation: _hasUnsavedGlobalFilters ? 2 : 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _hasUnsavedGlobalFilters
                        ? const Color(0xFFFFCC00)
                        : (isDarkMode ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              onPressed: () async {
                await _saveGlobalFilters();
              },
            ),
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
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('$_totalAccepted',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? const Color(0xFFFFCC00) : const Color(0xFFD97706),
                        )),
                    Text(t('Accepted'), style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppThemeColors.cardBorder),
              Expanded(
                child: Column(
                  children: [
                    Text('$_totalSkipped',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.redAccent : const Color(0xFFDC2626),
                        )),
                    Text(t('Skipped'), style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppThemeColors.cardBorder),
              Expanded(
                child: Column(
                  children: [
                    Text('₹${_dailyEarnings.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.greenAccent : const Color(0xFF16A34A),
                        )),
                    Text(isTamil ? 'இன்றைய வருமானம்' : "Today's Earning", style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary)),
                    Text('Total: ₹${_totalEarnings.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: AppThemeColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppThemeColors.cardBorder, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isTamil ? 'செயல்பாடு சுருக்கம்' : 'Activity Summary',
                        style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      _lastActivity,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppThemeColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t('Status'), style: TextStyle(fontSize: 11, color: AppThemeColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(
                      _serviceActive ? t('Active') : 'Inactive',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _serviceActive
                            ? (isDarkMode ? const Color(0xFF00C853) : const Color(0xFF15803D))
                            : (isDarkMode ? Colors.redAccent : const Color(0xFFDC2626)),
                      ),
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





  Widget _buildLastActivityCard() {
    final hasDetails = _lastRideDetails != null;

    final String status = hasDetails ? (_lastRideDetails!['status'] ?? 'WAITING').toString() : 'WAITING';
    final bool isAccepted = status == 'ACCEPTED';
    final bool isSkipped = status == 'SKIPPED';
    final bool isDetected = status == 'DETECTED';

    final Color statusColor = isAccepted
        ? const Color(0xFF00C853)
        : (isSkipped
            ? const Color(0xFFE53935)
            : (isDetected ? const Color(0xFFFF9800) : Colors.grey));

    final String statusBadgeText = isAccepted
        ? (isTamil ? 'ஏற்றுக்கொள்ளப்பட்டது' : 'ACCEPTED')
        : (isSkipped
            ? (isTamil ? 'தவிர்க்கப்பட்டது' : 'SKIPPED')
            : (isDetected ? (isTamil ? 'சவாரி வந்தது' : 'INCOMING') : (isTamil ? 'காத்திருக்கிறது' : 'WAITING')));

    final int ts = hasDetails ? ((_lastRideDetails!['timestamp'] as num?)?.toInt() ?? 0) : 0;
    String timeStr = '';
    if (ts > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      timeStr = '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
    }

    final String appName = hasDetails ? (_lastRideDetails!['appName'] ?? '').toString() : '';
    final String rawPickup = hasDetails ? (_lastRideDetails!['pickupLocation'] ?? '').toString().trim() : '';
    final String rawDrop = hasDetails
        ? (_lastRideDetails!['dropLocation'] ?? _lastRideDetails!['location'] ?? '').toString().trim()
        : '';
    final double pickupKm = hasDetails ? ((_lastRideDetails!['pickupKm'] as num?)?.toDouble() ?? -1.0) : -1.0;
    final double dropKm = hasDetails ? ((_lastRideDetails!['dropKm'] as num?)?.toDouble() ?? -1.0) : -1.0;
    final double fare = hasDetails ? ((_lastRideDetails!['fare'] as num?)?.toDouble() ?? -1.0) : -1.0;
    final double tip = hasDetails ? ((_lastRideDetails!['tip'] as num?)?.toDouble() ?? -1.0) : -1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDetails ? statusColor.withOpacity(0.5) : AppThemeColors.cardBorder,
          width: hasDetails ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAccepted
                      ? Icons.check_circle_rounded
                      : (isSkipped ? Icons.cancel_rounded : (isDetected ? Icons.radar_rounded : Icons.hourglass_top_rounded)),
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTamil ? 'கடைசி சவாரி செயல்பாடு (Last Activity)' : 'Last Ride Activity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  statusBadgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppThemeColors.cardBorder, height: 1),
          const SizedBox(height: 12),

          if (!hasDetails) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTamil
                          ? 'சவாரிக்காக காத்திருக்கிறது... (Rapido, OLA, Uber)'
                          : 'Waiting for ride requests... (Listening on Rapido, OLA, Uber)',
                      style: TextStyle(fontSize: 12, color: AppThemeColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                if (appName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      appName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 11, color: AppThemeColors.textMuted),
                  ),
                const Spacer(),
                if (fare > 0)
                  Text(
                    '₹${fare.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.greenAccent : const Color(0xFF16A34A),
                    ),
                  ),
                if (tip > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+₹${tip.toStringAsFixed(0)} Tip',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            if (rawPickup.isNotEmpty || pickupKm >= 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.trip_origin, size: 14, color: Color(0xFF00C853)),
                    const SizedBox(width: 8),
                    Text(
                      isTamil ? 'பிக்கப்: ' : 'Pickup: ',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppThemeColors.textSecondary),
                    ),
                    Expanded(
                      child: Text(
                        rawPickup.isNotEmpty
                            ? (pickupKm >= 0 ? '$rawPickup (${pickupKm.toStringAsFixed(1)} km)' : rawPickup)
                            : (pickupKm >= 0 ? '${pickupKm.toStringAsFixed(1)} km' : 'N/A'),
                        style: TextStyle(fontSize: 12, color: AppThemeColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  isTamil ? 'டிராப்: ' : 'Drop: ',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppThemeColors.textSecondary),
                ),
                Expanded(
                  child: Text(
                    rawDrop.isNotEmpty
                        ? (dropKm >= 0 ? '$rawDrop (${dropKm.toStringAsFixed(1)} km)' : rawDrop)
                        : (dropKm >= 0 ? '${dropKm.toStringAsFixed(1)} km' : 'N/A'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppThemeColors.textPrimary),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RideHistoryPage()),
                ).then((_) => _loadAllStates());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isTamil ? 'அனைத்து சவாரி வரலாறு பார்க்க' : 'View Full Ride History',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF2196F3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityWarningCard() {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: isDarkMode ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: isDarkMode ? const Color(0xFF5A2020) : const Color(0xFFFECACA)),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(Icons.warning_amber_rounded,
                  color: isDarkMode ? const Color(0xFFF44336) : const Color(0xFFDC2626), size: 20),

              SizedBox(width: 8),

              Text('Accessibility Service Required',

                  style: TextStyle(

                      color: isDarkMode ? const Color(0xFFF44336) : const Color(0xFFDC2626),

                      fontWeight: FontWeight.bold,

                      fontSize: 14)),

            ],

          ),

          const SizedBox(height: 8),

          Text(

            '1️⃣ Open Settings → 2️⃣ Installed Apps → 3️⃣ Auto Clicker → 4️⃣ Enable',

            style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? const Color(0xFFB3B3B3) : const Color(0xFF991B1B)),

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
    final effectivePrimaryColor = (app.id == 'uber' && !isDarkMode) ? const Color(0xFF111827) : app.primaryColor;



    Widget cardContent = AnimatedContainer(

      duration: const Duration(milliseconds: 300),

      decoration: BoxDecoration(

        color: isEnabled ? (isDarkMode ? app.cardColor : Colors.white) : (isDarkMode ? const Color(0xFF1A1A1A) : Colors.white),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(

          color: isEnabled ? effectivePrimaryColor.withOpacity(isDarkMode ? 0.5 : 0.8) : (isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E4E8)),

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

                          style: TextStyle(

                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppThemeColors.textPrimary)),

                      Text(
                        !app.isAvailable
                            ? 'Coming Soon'
                            : (isEnabled
                                ? (app.id == 'zomato'
                                    ? (isTamil ? 'Swipe to Accept காத்திருக்கிறது...' : 'Listening for Swipe to Accept...')
                                    : (isTamil ? 'லொகேஷன் அடிப்படையில் தயார்' : 'Listening via Location Profile'))
                                : (isTamil ? 'முடக்கப்பட்டது' : 'Disabled')),
                        style: TextStyle(
                            fontSize: 12,
                            color: !app.isAvailable ? Colors.redAccent : (isEnabled ? effectivePrimaryColor : isDarkMode ? const Color(0xFF666666) : const Color(0xFF9CA3AF))),
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
                      _showAppEnableConfirmationDialog(app);
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





          // ── Ola Developer Options Bypass Card ──
          if (app.id == 'ola' && app.isAvailable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _olaDevBypassEnabled
                      ? (isDarkMode ? const Color(0xFF0F2618) : const Color(0xFFF0FDF4))
                      : (isDarkMode ? const Color(0xFF222222) : const Color(0xFFF9FAFB)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _olaDevBypassEnabled
                        ? (isDarkMode ? const Color(0xFF00C853).withOpacity(0.7) : const Color(0xFF16A34A))
                        : (isDarkMode ? Colors.white12 : const Color(0xFFE2E4E8)),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: _olaDevBypassEnabled
                          ? (isDarkMode ? const Color(0xFF00E676) : const Color(0xFF15803D))
                          : (isDarkMode ? Colors.white38 : const Color(0xFF64748B)),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  isTamil ? 'Dev Options Bypass' : 'Dev Options Bypass',
                                  style: TextStyle(
                                    color: _olaDevBypassEnabled
                                        ? (isDarkMode ? const Color(0xFF69F0AE) : const Color(0xFF166534))
                                        : (isDarkMode ? Colors.white : const Color(0xFF111827)),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _olaDevBypassEnabled ? const Color(0xFF00C853).withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _olaDevBypassEnabled ? 'ACTIVE' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: _olaDevBypassEnabled ? const Color(0xFF00C853) : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _olaDevBypassEnabled
                                ? (isTamil
                                    ? '✅ Ola "Disable developer options" பிளாக் பாப்-அப் மறைக்கப்பட்டது'
                                    : '✅ Ola developer options block dialog is bypassed')
                                : (isTamil
                                    ? 'Ola-வில் பிளாக் வராமல் தடுக்க இதை ஆன் செய்யவும்'
                                    : 'Enable to bypass Ola blocking developer options dialog'),
                            style: TextStyle(
                              color: _olaDevBypassEnabled
                                  ? (isDarkMode ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))
                                  : AppThemeColors.textSecondary,
                              fontSize: 11,
                              fontWeight: (_olaDevBypassEnabled && !isDarkMode) ? FontWeight.w500 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _olaDevBypassEnabled,
                      onChanged: (val) {
                        _toggleOlaDevBypass(val);
                      },
                      activeColor: const Color(0xFF00C853),
                      activeTrackColor: const Color(0xFF00C853).withOpacity(0.3),
                      inactiveThumbColor: isDarkMode ? const Color(0xFF888888) : const Color(0xFF9CA3AF),
                      inactiveTrackColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
                    ),
                  ],
                ),
              ),
            ),

          // ── Smart Fare Mode Toggle ──

          if (app.isAvailable && app.id != 'zomato')

            Padding(

              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),

              child: AnimatedContainer(

                duration: const Duration(milliseconds: 250),

                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

                decoration: BoxDecoration(

                  color: (_smartFareModeEnabled[app.id] ?? false)
                      ? (isDarkMode ? const Color(0xFF0A1628) : const Color(0xFFEFF6FF))
                      : (isDarkMode ? const Color(0xFF222222) : const Color(0xFFF9FAFB)),

                  borderRadius: BorderRadius.circular(12),

                  border: Border.all(

                    color: (_smartFareModeEnabled[app.id] ?? false)

                        ? (isDarkMode ? const Color(0xFF2979FF).withOpacity(0.7) : const Color(0xFF3B82F6))

                        : (isDarkMode ? Colors.white12 : const Color(0xFFE2E4E8)),

                    width: 1.2,

                  ),

                ),

                child: Row(

                  children: [

                    Icon(

                      Icons.price_check_rounded,

                      color: (_smartFareModeEnabled[app.id] ?? false)

                          ? (isDarkMode ? const Color(0xFF2979FF) : const Color(0xFF1D4ED8))

                          : (isDarkMode ? Colors.white38 : const Color(0xFF64748B)),

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

                                  ? (isDarkMode ? const Color(0xFF82B1FF) : const Color(0xFF1E40AF))

                                  : (isDarkMode ? Colors.white : const Color(0xFF111827)),

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

                            style: TextStyle(
                              color: (_smartFareModeEnabled[app.id] ?? false)
                                  ? (isDarkMode ? const Color(0xFF90CAF9) : const Color(0xFF1D4ED8))
                                  : AppThemeColors.textSecondary,
                              fontSize: 11,
                              fontWeight: ((_smartFareModeEnabled[app.id] ?? false) && !isDarkMode) ? FontWeight.w500 : FontWeight.normal,
                            ),

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

                      inactiveThumbColor: isDarkMode ? const Color(0xFF888888) : const Color(0xFF9CA3AF),

                      inactiveTrackColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),

                    ),

                  ],

                ),

              ),

            ),



          // ── Zomato Simple Info Box ──
          if (app.id == 'zomato')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? (isDarkMode ? const Color(0xFF2A0C0E) : const Color(0xFFFFF1F2))
                      : (isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isEnabled
                        ? const Color(0xFFE23744).withOpacity(0.5)
                        : (isDarkMode ? Colors.white12 : const Color(0xFFE5E7EB)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.swipe_right_rounded, color: Color(0xFFE23744), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTamil
                            ? 'Zomato-வில் "Swipe to accept" பட்டன் வந்தவுடன் ஆட்டோமேட்டிக்காக Swipe செய்து ஆர்டரை ஏற்கும்.'
                            : 'Automatically swipes to accept when "Swipe to accept" appears in Zomato.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
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
                app.id == 'zomato'
                    ? (isTamil ? '⚡ Zomato ஆர்டர் வரும்போது தானாகவே Swipe to Accept செய்யப்படும்' : '⚡ Automatically executes Swipe to Accept when order arrives')
                    : '🤖 Auto-clicks: ${app.acceptButtonName}',

                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode
                      ? effectivePrimaryColor.withOpacity(0.8)
                      : (app.id == 'rapido' ? const Color(0xFFB45309) : effectivePrimaryColor),
                  fontWeight: FontWeight.w600,
                ),

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

        color: AppThemeColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppThemeColors.cardBorder),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Text('ℹ️ How it works',

              style: TextStyle(

                  fontSize: 14, fontWeight: FontWeight.bold, color: AppThemeColors.textPrimary)),

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

            style: TextStyle(fontSize: 12, color: isDarkMode ? const Color(0xFFB3B3B3) : const Color(0xFF4B5563), height: 1.7),

          ),

          Divider(color: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFE2E4E8), height: 20),

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

      content: Text(msg, style: TextStyle(color: AppThemeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),

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

        backgroundColor: AppThemeColors.dialogBg,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

        title: Row(

          children: [

            const Icon(Icons.delete_sweep, color: Colors.redAccent),

            const SizedBox(width: 8),

            Text(

              isTamil ? 'வரலாற்றை அழிக்கவா?' : 'Clear History?',

              style: TextStyle(color: AppThemeColors.textPrimary, fontWeight: FontWeight.bold),

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

            child: Text(isTamil ? 'ரத்து' : 'Cancel', style: TextStyle(color: AppThemeColors.textSecondary)),

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



  bool _isRideDataValid(dynamic item) {
    if (item == null) return false;

    final appName = (item['appName'] ?? '').toString().toLowerCase();

    // Zomato food delivery exception
    if (appName.contains('zomato')) {
      final loc = (item['dropLocation'] ?? item['location'] ?? '').toString().trim();
      return loc.isNotEmpty && loc != 'Data not received';
    }

    // 1. Numeric validations (No -1 / N/A)
    final double fare = (item['fare'] as num?)?.toDouble() ?? -1.0;
    final double pickupKm = (item['pickupKm'] as num?)?.toDouble() ?? -1.0;
    final double dropKm = (item['dropKm'] as num?)?.toDouble() ?? -1.0;

    if (fare <= 0) return false; // Must have positive fare (not 'Data not received')
    if (pickupKm < 0) return false; // Must have valid pickup distance (not 'N/A')
    if (dropKm < 0) return false; // Must have valid drop distance (not 'N/A')

    // 2. Location string validations (No empty / "Data not received" / "TODO")
    final String rawPickupLoc = (item['pickupLocation'] ?? '').toString().trim();
    final String rawDropLoc = (item['dropLocation'] ?? '').toString().trim();
    final String fallbackLoc = (item['location'] ?? '').toString().split('(').first.trim();
    final String dropLoc = rawDropLoc.isNotEmpty ? rawDropLoc : fallbackLoc;

    if (dropLoc.isEmpty ||
        dropLoc == 'Data not received' ||
        dropLoc == 'Smart Fare' ||
        dropLoc.toUpperCase() == 'TODO' ||
        rawPickupLoc.toUpperCase() == 'TODO') {
      return false;
    }

    // For Uber: pickup location must also be successfully extracted
    if (appName.contains('uber')) {
      if (rawPickupLoc.isEmpty || rawPickupLoc == 'Data not received') {
        return false;
      }
    }

    return true;
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
      final bool hasValidData = _isRideDataValid(item);

      if (_currentFilter == DataFilter.withData && !hasValidData) return false;
      if (_currentFilter == DataFilter.withoutData && hasValidData) return false;

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
              icon: const Icon(Icons.refresh, color: Color(0xFFFFCC00)),
              tooltip: isTamil ? 'புதுப்பி' : 'Refresh',
              onPressed: _loadHistory,
            ),

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

