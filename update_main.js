const fs = require('fs');
let text = fs.readFileSync('lib/main.dart', 'utf8');

// Add imports
text = text.replace('import \'package:flutter/services.dart\';', 'import \\'package:flutter/services.dart\\';\nimport \\'dart:convert\\';\nimport \\'package:http/http.dart\\' as http;\nimport \\'package:image_picker/image_picker.dart\\';\nimport \\'package:image_gallery_saver/image_gallery_saver.dart\\';');

// Find dialog code
const oldDialog = \        // Show un-dismissible dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return WillPopScope(
              onWillPop: () async => false, // prevent back button
              child: AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Free Trial Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: const Text(
                  'You have completed 20 accepted trips.\\n\\nPlease manually enter ?100 in your UPI app to purchase and continue using AutoClicker.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _launchPayment(),
                    child: const Text('Pay ?100 via UPI'),
                  ),
                ],
              ),
            );
          },
        );\;

const newDialog = \        // Show un-dismissible dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            bool isUploading = false;
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return WillPopScope(
                  onWillPop: () async => false, // prevent back button
                  child: AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Free Trial Ended', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'You have completed 20 accepted trips.\\n\\nPlease pay ?100 via UPI to continue using AutoClicker.\\n',
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
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \')));
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
        );\;

text = text.replace(oldDialog, newDialog);

const oldLaunch = \    Future<void> _launchPayment() async {
      const upiUri = 'upi://pay?pa=8637499525@kotakbank&pn=AutoClicker&tn=App%20Purchase&cu=INR';
      try {
        final String? response = await _channel.invokeMethod('launchUPI', {'url': upiUri});
        if (response != null && response != "FAILURE") {
          // Typical UPI response contains "Status=SUCCESS"
          if (response.toLowerCase().contains("success")) {
             // Wait for admin verification (for now, auto-unlock for demo or send to backend)
             _unlockApp();
             _showSnack('Payment Successful!');
          } else {
             // For P2P it might just return something generic.
             // In a real production app we check backend. For now we will unlock if not explicitly failed.
             if (response.toLowerCase().contains("failed")) {
                 _showSnack('Payment Failed. Please try again.');
             } else {
                 _showSnack('Payment status pending verification. Unlocking app...');
                 _unlockApp(); // Trusting response for this version
             }
          }
        } else {
          _showSnack('Payment Failed or Cancelled');
        }
      } catch (e) {
        _showSnack('Could not launch UPI app: \');
      }
    }\;
text = text.replace(oldLaunch, '');

const oldSocket = \        _socket?.on('clickerBlockStatus', (data) {
          if (data != null && data['isBlocked'] == true) {
             _disableAllAppsAndStopService("Your account has been blocked by Admin.");
          }
        });\;
const newSocket = \        _socket?.on('clickerBlockStatus', (data) {
          if (data != null && data['isBlocked'] == true) {
             _disableAllAppsAndStopService("Your account has been blocked by Admin.");
          }
        });

        _socket?.on('clickerPaymentStatus', (data) {
          if (data != null && data['hasPaidForClicker'] == true) {
             _unlockApp();
             _showSnack("Admin approved your payment. Enjoy!");
          }
        });\;

text = text.replace(oldSocket, newSocket);

fs.writeFileSync('lib/main.dart', text);
