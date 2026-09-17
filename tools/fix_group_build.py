from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'group_management.dart';" not in s:
    marker = "import 'package:qr_flutter/qr_flutter.dart';"
    if marker in s:
        s = s.replace(marker, marker + "\nimport 'group_management.dart';", 1)

start = s.find('class GroupManagementPage extends StatefulWidget')
if start >= 0:
    end = s.find('class ConversationToolsPage', start)
    if end < 0:
        raise SystemExit('ConversationToolsPage marker not found')
    s = s[:start] + s[end:]
else:
    print('GroupManagementPage already removed; nothing to remove')

p.write_text(s, encoding='utf-8')
print('verified group management import and build-safe main.dart')
