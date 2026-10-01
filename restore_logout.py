import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add Socket import
if "import 'package:socket_io_client/socket_io_client.dart' as IO;" not in text:
    text = text.replace("import 'profile_page.dart';", "import 'profile_page.dart';\nimport 'package:socket_io_client/socket_io_client.dart' as IO;")

# 2. Add vars
text = text.replace("String? _driverId;", "String? _driverId;\n  String? _deviceId;\n  IO.Socket? _socket;")

# 3. Read deviceId in _initDriverId
init_old = '''  Future<void> _initDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverId = prefs.getString('driverId');
    });
  }'''
init_new = '''  Future<void> _initDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _driverId = prefs.getString('driverId');
      _deviceId = prefs.getString('deviceId');
    });
    _initSocketAndDriver();
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
    });

    _socket?.on('clickerPaymentStatus', (data) {
      if (data['status'] == 'paid') {
        _unlockApp();
      } else {
        setState(() => _isAppPurchased = false);
      }
    });

    _socket?.on('forceLogout', (data) {
      _handleLogout(data['message'] ?? 'Logged in from another device.');
    });
  }

  void _handleLogout(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }'''
text = text.replace(init_old, init_new)

# 4. Modify _fetchAcceptedTripsFromDB
fetch_old = '''        body: jsonEncode({'driver_id': _driverId, 'device_id': 'flutter_app'}),'''
fetch_new = '''        body: jsonEncode({'driver_id': _driverId, 'device_id': _deviceId ?? ''}),'''
text = text.replace(fetch_old, fetch_new)

fetch_logic_old = '''          if (data['status'] == 'success') {
            setState(() {
              _totalAccepted = data['profile']['acceptedTrips'] ?? 0;
              _isAppPurchased = data['profile']['hasPaidForClicker'] ?? false;
            });
            _enforcePaywallIfNeeded();
          }'''
fetch_logic_new = '''          if (data['status'] == 'logout') {
            _handleLogout(data['message'] ?? 'Logged in from another device.');
            return;
          }
          if (data['status'] == 'success') {
            setState(() {
              _totalAccepted = data['profile']['acceptedTrips'] ?? 0;
              _isAppPurchased = data['profile']['hasPaidForClicker'] ?? false;
            });
            _enforcePaywallIfNeeded();
          }'''
text = text.replace(fetch_logic_old, fetch_logic_new)

# 5. Dispose socket
dispose_old = '''    WidgetsBinding.instance.removeObserver(this);'''
dispose_new = '''    _socket?.disconnect();
    _socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);'''
text = text.replace(dispose_old, dispose_new)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
