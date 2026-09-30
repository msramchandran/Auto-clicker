import sys

file = 'android/app/src/main/kotlin/com/example/autoclicker/RapidoAutoClickService.kt'
with open(file, 'r', encoding='utf-8') as f:
    data = f.read()

# 1. Update tipRegex
old_regex = 'val tipRegex = Regex("(?:\\\\+|tip|bonus|extra)\\\\s*(?:?|rs\\\\.?)*\\\\s*([0-9]+\\\\.?[0-9]*)|([0-9]+\\\\.?[0-9]*)\\\\s*(?:tip|bonus|extra)", RegexOption.IGNORE_CASE)'
new_regex = 'val tipRegex = Regex("(?:\\\\+|tip|bonus|extra)[^0-9]*?([0-9]+\\\\.?[0-9]*)|([0-9]+\\\\.?[0-9]*)[^0-9]*?(?:tip|bonus|extra)", RegexOption.IGNORE_CASE)'

data = data.replace(old_regex, new_regex)

# 2. Add Wait Logic
old_wait = '''        Log.d(TAG, "[${appConfig.displayName}] Target Match Found! Drop: ''")
        updateHUD("?? Match: ", "#88FF9800", true)

        // Step 6: ? MATCH — Click!'''

new_wait = '''        Log.d(TAG, "[${appConfig.displayName}] Target Match Found! Drop: ''")
        updateHUD("?? Match: ", "#88FF9800", true)

        if (appConfig.packageName == "com.olacabs.oladriver") {
            val btnText = acceptButton.text?.toString()?.lowercase() ?: acceptButton.contentDescription?.toString()?.lowercase() ?: ""
            if ("accept in" in btnText) {
                Log.d(TAG, "[OLA] Waiting for countdown... Button text: ")
                updateHUD("? Waiting...", "#FF9800", true)
                return true
            }
        }

        // Step 6: ? MATCH — Click!'''
data = data.replace(old_wait, new_wait)

# 3. Add 3 Clicks Logic
old_click = '''        val clicked = if (forceGesture) {
            performGestureClick(bounds)
            true
        } else {
            acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }'''

new_click = '''        val clicked = if (forceGesture) {
            performGestureClick(bounds)
            true
        } else {
            if (appConfig.packageName == "com.olacabs.oladriver") {
                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                Thread.sleep(50)
                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                Thread.sleep(50)
                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                true
            } else {
                acceptButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            }
        }'''

data = data.replace(old_click, new_click)

with open(file, 'w', encoding='utf-8') as f:
    f.write(data)
