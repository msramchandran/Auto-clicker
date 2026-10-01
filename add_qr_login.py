import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Imports
if "import 'package:gal/gal.dart';" not in text:
    text = text.replace("import 'package:image_picker/image_picker.dart';", "import 'package:image_picker/image_picker.dart';\nimport 'package:gal/gal.dart';")

# 2. Make main async and add SharedPreferences logic
main_old = '''void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RapidoAutoClickerApp());
}'''

main_new = '''void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getString('driverId') != null;
  runApp(RapidoAutoClickerApp(home: isLoggedIn ? const HomePage() : const LoginPage()));
}'''
text = text.replace(main_old, main_new)

# 3. Change RapidoAutoClickerApp to take home widget
app_old = '''class RapidoAutoClickerApp extends StatelessWidget {
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
}'''

app_new = '''class RapidoAutoClickerApp extends StatelessWidget {
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
}'''
text = text.replace(app_old, app_new)

# 4. Add Download QR Code Button to dialog
# Search for the button Row in _enforcePaywallIfNeeded
button_pattern = r'''(OutlinedButton\.icon\(\s*onPressed: \(\) async \{\s*final ImagePicker picker = ImagePicker\(\);\s*final XFile\? image = await picker\.pickImage\(source: ImageSource\.gallery\);)'''

download_button = '''ElevatedButton.icon(
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
                            const SizedBox(height: 12),
                            '''
text = re.sub(button_pattern, download_button + r'\1', text)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)

# Edit login_page.dart to pre-fill ID
with open('lib/login_page.dart', 'r', encoding='utf-8') as f:
    login_text = f.read()

login_init = '''  @override
  void initState() {
    super.initState();
    _loadSavedId();
  }

  Future<void> _loadSavedId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('driverId');
    if (savedId != null && savedId.isNotEmpty) {
      _idController.text = savedId;
    }
  }

  String _generateDeviceId() {'''

login_text = login_text.replace("  String _generateDeviceId() {", login_init)

with open('lib/login_page.dart', 'w', encoding='utf-8') as f:
    f.write(login_text)
