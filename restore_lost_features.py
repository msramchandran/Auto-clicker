import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. Add ProfilePage import
if "import 'profile_page.dart';" not in text:
    text = text.replace("import 'login_page.dart';", "import 'login_page.dart';\nimport 'profile_page.dart';")

# 2. Add vars
text = text.replace("int _totalAccepted = 0;", "int _totalAccepted = 0;\n  int _totalSkipped = 0;\n  double _totalEarnings = 0.0;")

# 3. Add to loadAllStates
text = text.replace("_totalAccepted = result['totalAccepted'] as int? ?? 0;", 
                    "_totalAccepted = result['totalAccepted'] as int? ?? 0;\n            _totalSkipped = result['totalSkipped'] as int? ?? 0;\n            _totalEarnings = (result['totalEarnings'] as num?)?.toDouble() ?? 0.0;")

# 4. Handle onRideSkipped method channel call
handler_old = "});\n        } else if (call.method == 'onRideDetected') {"
handler_new = "});\n        } else if (call.method == 'onRideSkipped') {\n          setState(() {\n            _totalSkipped++;\n          });\n        } else if (call.method == 'onRideDetected') {"
text = text.replace(handler_old, handler_new)

# 5. Add Profile button to Header
header_old = "Container(\n            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),"
header_new = '''IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),'''
text = text.replace(header_old, header_new)

# 6. Rewrite OverallStatusCard to fit the new stats
status_card_regex = r'Widget _buildOverallStatusCard\(\) \{.*?return Container\(.*?\);.*?\}'
new_status_card = '''Widget _buildOverallStatusCard() {
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
                    const Text('Accepted', style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFF2A2A2A)),
              Expanded(
                child: Column(
                  children: [
                    Text('$_totalSkipped',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const Text('Skipped', style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: const Color(0xFF2A2A2A)),
              Expanded(
                child: Column(
                  children: [
                    Text('₹${_totalEarnings.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    const Text('Earnings', style: TextStyle(fontSize: 11, color: Color(0xFFB3B3B3))),
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
  }'''
text = re.sub(status_card_regex, new_status_card, text, flags=re.DOTALL)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
