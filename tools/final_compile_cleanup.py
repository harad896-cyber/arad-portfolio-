from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# The theme patches may both add DividerThemeData to ThemeData. Keep one valid
# declaration by removing duplicate blocks while preserving the first one.
block = '''        dividerTheme: const DividerThemeData(\n          space: 1,\n          thickness: 1,\n          indent: 72,\n          color: Color(0xFFE7ECF2),\n        ),\n'''
first = s.find(block)
if first >= 0:
    second = s.find(block, first + len(block))
    if second >= 0:
        s = s[:second] + s[second + len(block):]

# Remove an unused dart:io import introduced by an earlier media patch.
s = s.replace("import 'dart:io';\n", '', 1)

p.write_text(s, encoding='utf-8')
print('Applied final compile cleanup')
