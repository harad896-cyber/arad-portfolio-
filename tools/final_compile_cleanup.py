from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Remove the unused import that older media patches could add.
s = s.replace("import 'dart:io';\n", '', 1)

# Keep only the first dividerTheme declaration inside ThemeData. Multiple
# stacked UI patches may add the same named ThemeData property with slightly
# different formatting, which causes duplicate_named_argument.
def remove_duplicate_theme_property(source: str, property_name: str) -> str:
    matches = list(re.finditer(r'(?m)^        ' + re.escape(property_name) + r'\s*:', source))
    if len(matches) <= 1:
        return source

    # ThemeData is the only target here. Remove later occurrences by deleting
    # the complete Dart property expression through its matching top-level
    # closing comma. The property values in this project are const objects.
    for match in reversed(matches[1:]):
        start = match.start()
        brace = source.find('{', start)
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
p.write_text(s, encoding='utf-8')
print('Applied final compile cleanup')
