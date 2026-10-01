import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

pattern = r'(\s*Padding\(\s*padding: const EdgeInsets.fromLTRB\(16, 0, 16, 16\),)'
replace = r'''
          if (app.id == 'ola') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fast Accept Block', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
          ],\1'''

text = re.sub(pattern, replace, text, count=1)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
