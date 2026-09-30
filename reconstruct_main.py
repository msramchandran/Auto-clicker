import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Imports
imports = """import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
"""
if "image_picker" not in text:
    text = text.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\n" + imports)

# 2. Add variables
var_pattern = r'bool _isHUDEnabled = true;'
new_vars = '''bool _isHUDEnabled = true;
  bool _olaBlockerEnabled = true;
  bool _isAppPurchased = false;
  int _totalAccepted = 0;'''
text = text.replace(var_pattern, new_vars)

# 3. Add to _loadAllStates
load_pattern = r'_isHUDEnabled = states\[\'isHUDEnabled\'\] \?\? true;'
new_load = '''_isHUDEnabled = states['isHUDEnabled'] ?? true;
        _olaBlockerEnabled = states['ola_blocker_enabled'] ?? true;
        _isAppPurchased = states['isAppPurchased'] ?? false;
        _totalAccepted = states['totalAccepted'] ?? 0;'''
text = text.replace(load_pattern, new_load)

# Add fetch call at end of _loadAllStates
fetch_call_pattern = r'_profiles = \[\];\n          \}\n        \}\);\n      \} catch \(\_\) \{\}'
fetch_call_new = '''_profiles = [];
          }
        });
        _fetchAcceptedTripsFromDB();
      } catch (_) {}'''
text = re.sub(fetch_call_pattern, fetch_call_new, text)

# 4. Add methods
methods_anchor = r'Future<void> _checkServiceStatus\(\) async \{'
new_methods = '''
  Future<void> _fetchAcceptedTripsFromDB() async {
    if (_driverId == null) return;
    try {
      final response = await http.post(
        Uri.parse('http://43.205.135.3:3000/api/clicker-profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driver_id': _driverId, 'device_id': 'flutter_app'}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _totalAccepted = data['profile']['acceptedTrips'] ?? 0;
            _isAppPurchased = data['profile']['hasPaidForClicker'] ?? false;
          });
          _enforcePaywallIfNeeded();
        }
      }
    } catch (_) {}
  }

  void _enforcePaywallIfNeeded() {
    if (_totalAccepted >= 20 && !_isAppPurchased) {
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
                          'You have completed 20 accepted trips.\\n\\nPlease pay ₹100 via UPI to continue using AutoClicker.\\n',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        Container(
                          decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 2)),
                          child: Image.asset('assets/images/qr_code.jpg', width: 200, height: 200, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () async {
                             try {
                               final bytes = await rootBundle.load('assets/images/qr_code.jpg');
                               final result = await ImageGallerySaver.saveImage(bytes.buffer.asUint8List());
                               if (result['isSuccess'] == true) {
                                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR Code saved to Gallery!')));
                               }
                             } catch (e) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save QR Code')));
                             }
                          },
                          icon: const Icon(Icons.download, color: Colors.blue),
                          label: const Text('Download QR Code', style: TextStyle(color: Colors.blue)),
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
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ' + str(e))));
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

  void _unlockApp() async {
    setState(() => _isAppPurchased = true);
    await _channel.invokeMethod('setAppPurchased', {'purchased': true});
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context); // Close the dialog
    }
  }

  Future<void> _checkServiceStatus() async {'''
text = text.replace(methods_anchor, new_methods)

# 5. Socket updates
socket_pattern = r'_socket\?\.on\(\'forceLogout\', \(data\) async \{'
new_socket = '''_socket?.on('clickerPaymentStatus', (data) {
        if (data != null && data['hasPaidForClicker'] == true) {
           _unlockApp();
           if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Admin approved your payment! Enjoy!")));
           }
        }
      });

      _socket?.on('forceLogout', (data) async {'''
text = text.replace("      _socket?.on('forceLogout', (data) async {", new_socket)

# 6. Guard _setAppEnabled
set_enabled_pattern = r'Future<void> _setAppEnabled\(String appId, bool value\) async \{'
new_set_enabled = '''Future<void> _setAppEnabled(String appId, bool value) async {
    if (value && _totalAccepted >= 20 && !_isAppPurchased) {
      _enforcePaywallIfNeeded();
      return;
    }'''
text = text.replace(set_enabled_pattern, new_set_enabled)

# 7. Ola toggle logic
ola_toggle = '''
                if (app.id == 'ola') ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fast Accept Block',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
                ],
                const SizedBox(height: 12),
                Row('''
text = text.replace('                const SizedBox(height: 12),\n                Row(', ola_toggle, 1)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
