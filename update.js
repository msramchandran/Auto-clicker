const fs = require('fs');
const file = 'android/app/src/main/kotlin/com/example/autoclicker/RapidoAutoClickService.kt';
let data = fs.readFileSync(file, 'utf8');

// 1. Tip regex
let oldTip = 'val tipRegex = Regex("(?:\\\\+|tip|bonus|extra)\\\\s*(?:₹|rs\\\\.?)*\\\\s*([0-9]+\\\\.?[0-9]*)|([0-9]+\\\\.?[0-9]*)\\\\s*(?:tip|bonus|extra)", RegexOption.IGNORE_CASE)';
let newTip = 'val tipRegex = Regex("(?:\\\\+|tip|bonus|extra)[^0-9]*?([0-9]+\\\\.?[0-9]*)|([0-9]+\\\\.?[0-9]*)[^0-9]*?(?:tip|bonus|extra)", RegexOption.IGNORE_CASE)';
data = data.replace(oldTip, newTip);

// 2. Add wait logic (using regex to avoid exact emoji mismatch)
let waitRegex = /(Log\.d\(TAG, "\[\$\{appConfig\.displayName\}\] Target Match Found! Drop: '\'"\)\s*updateHUD\([^)]+\)\s*)/g;
data = data.replace(waitRegex, "\n        if (appConfig.packageName == \"com.olacabs.oladriver\") {\n            val btnText = acceptButton.text?.toString()?.lowercase() ?: acceptButton.contentDescription?.toString()?.lowercase() ?: \"\"\n            if (btnText.contains(\"accept in\")) {\n                Log.d(TAG, \"[OLA] Waiting for countdown... Button text: $$btnText\")\n                updateHUD(\"⏳ Waiting...\", \"#FF9800\", true)\n                return true\n            }\n        }\n\n");

// 3. Add 3 Clicks
let clickRegex = /(val clicked = if \(forceGesture\) \{\s*performGestureClick\(bounds\)\s*true\s*\} else \{\s*)acceptButton\.performAction\(AccessibilityNodeInfo\.ACTION_CLICK\)(\s*\})/g;
let newClick = " (appConfig.packageName == \"com.olacabs.oladriver\") {\n                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)\n                Thread.sleep(50)\n                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)\n                Thread.sleep(50)\n                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)\n                true\n            } else {\n                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)\n            }";
data = data.replace(clickRegex, newClick);

fs.writeFileSync(file, data, 'utf8');
