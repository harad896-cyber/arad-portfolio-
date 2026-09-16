from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')
s = s.replace("import 'dart:io';\n", '', 1)

def remove_duplicate_theme_property(source: str, property_name: str) -> str:
    matches = list(re.finditer(r'(?m)^        ' + re.escape(property_name) + r'\s*:', source))
    if len(matches) <= 1:
        return source
    for match in reversed(matches[1:]):
        start = match.start()
        paren = source.find('(', start)
        if paren == -1:
            continue
        depth = 0
        in_string = False
        escape = False
        end = None
        for i in range(paren, len(source)):
            ch = source[i]
            if in_string:
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif ch == "'":
                    in_string = False
                continue
            if ch == "'":
                in_string = True
            elif ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
                if depth == 0:
                    j = i + 1
                    while j < len(source) and source[j] in ' \t':
                        j += 1
                    if j < len(source) and source[j] == ',':
                        j += 1
                    if j < len(source) and source[j] == '\n':
                        j += 1
                    end = j
                    break
        if end is not None:
            source = source[:start] + source[end:]
    return source

s = remove_duplicate_theme_property(s, 'dividerTheme')

a = s.find('class ChatPage extends StatefulWidget {')
b = s.find('class ProfilePage extends StatefulWidget {', a)
if a >= 0 and b > a:
    chat = s[a:b]
    # Remove every declaration form, including inferred generic literals and
    # declarations sharing a line with another state field.
    chat = re.sub(
        r'(?:(?:final|late|var)\s+)?(?:Map\s*<[^;=]+>\s+)?reactions\s*=\s*(?:<[^;=]+>\s*)?\{\}\s*;\s*',
        '',
        chat,
    )
    if 'Map<String, List<String>> reactions = {};' not in chat:
        anchor = 'bool sending = false;'
        if anchor in chat:
            chat = chat.replace(anchor, anchor + '\n  Map<String, List<String>> reactions = {};', 1)
    s = s[:a] + chat + s[b:]

# Wrap has no padding named argument.
s = re.sub(r'Wrap\(\s*padding\s*:\s*(?:const\s+)?EdgeInsets\.[^,\n]+,\s*', 'Wrap(', s)

p.write_text(s, encoding='utf-8')
print('Applied final compile cleanup')
