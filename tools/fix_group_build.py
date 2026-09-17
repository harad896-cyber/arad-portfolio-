from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if "import 'group_management.dart';" not in s:
    marker = "import 'package:qr_flutter/qr_flutter.dart';"
    if marker in s:
        s = s.replace(marker, marker + "\nimport 'group_management.dart';", 1)

start = s.find('class GroupManagementPage extends StatefulWidget')
end = s.find('class ConversationToolsPage', start)
if start < 0 or end < 0:
    raise SystemExit('GroupManagementPage block markers not found')

s = s[:start] + s[end:]
p.write_text(s, encoding='utf-8')
print('group page block replaced with lib/group_management.dart')
