from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

if 'final aradThemeController = ThemeController();' not in s:
    marker = '\nclass AradMessenger extends StatefulWidget {'
    if marker not in s:
        raise SystemExit('AradMessenger marker not found')
    s = s.replace(marker, '\nfinal aradThemeController = ThemeController();\n' + marker, 1)

s = s.replace('final ThemeController themeController = ThemeController();', 'final ThemeController themeController = aradThemeController;', 1)
# The theme page is the second controller declaration; make it use the same live controller.
s = s.replace('final ThemeController controller = ThemeController();', 'final ThemeController controller = aradThemeController;', 1)

p.write_text(s, encoding='utf-8')
print('Connected theme picker to the live app theme controller')
