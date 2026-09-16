from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Remove the unused import that older media patches could add.
s = s.replace("import 'dart:io';\n", '', 1)

# Keep only the first dividerTheme declaration inside ThemeData.
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

# The chat feature patches are intentionally layered. Normalize the final
# ChatPage state so exactly one reactions map exists even if an earlier patch
# inserted it on an inline line.
a = s.find('class ChatPage extends StatefulWidget {')
b = s.find('class ProfilePage extends StatefulWidget {', a)
if a >= 0 and b > a:
    chat = s[a:b]
    chat = re.sub(
        r'\b(?:(?:final|late)\s+)?(?:Map\s*<\s*String\s*,\s*List\s*<\s*String\s*>\s*>|Map\s*<String\s*,\s*List<String>>|Map\s*<String,List<String>>|var)\s+reactions\s*=\s*\{\}\s*;\s*',
        '',
        chat,
    )
    if 'Map<String, List<String>> reactions = {};' not in chat:
        anchor = 'bool sending = false;'
        if anchor in chat:
            chat = chat.replace(anchor, anchor + '\n  Map<String, List<String>> reactions = {};', 1)
    s = s[:a] + chat + s[b:]

# A Wrap has no padding parameter. Some layered UI patches emitted
# Wrap(padding: ..., ...), which stops analysis. Remove only that invalid
# named argument; surrounding spacing/containers remain intact.
s = re.sub(r'Wrap\(\s*padding\s*:\s*(?:const\s+)?EdgeInsets\.[^,\n]+,\s*', 'Wrap(', s)

p.write_text(s, encoding='utf-8')
print('Applied final compile cleanup')
