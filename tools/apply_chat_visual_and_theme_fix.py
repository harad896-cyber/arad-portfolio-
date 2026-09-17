from pathlib import Path

main = Path('lib/main.dart')
s = main.read_text(encoding='utf-8')

old = """  @override\n  void initState() {\n    super.initState();\n    load();\n    _loadChatType().then((_) => _loadGroupMemberCount());\n"""
new = """  @override\n  void initState() {\n    super.initState();\n    appTheme.addListener(_onAppThemeChanged);\n    load();\n    _loadChatType();\n"""
if old in s:
    s = s.replace(old, new, 1)
elif "appTheme.addListener(_onAppThemeChanged);" not in s:
    raise SystemExit('ChatPage initState pattern not found')

old = """  @override\n  void dispose() {\n    if (channel != null) supabase.removeChannel(channel!);\n"""
new = """  void _onAppThemeChanged() {\n    if (mounted) setState(() {});\n  }\n\n  @override\n  void dispose() {\n    appTheme.removeListener(_onAppThemeChanged);\n    if (channel != null) supabase.removeChannel(channel!);\n"""
if old in s:
    s = s.replace(old, new, 1)
elif "void _onAppThemeChanged()" not in s:
    raise SystemExit('ChatPage dispose pattern not found')

old = """      body: Container(\n        decoration: BoxDecoration(\n          color: dark ? const Color(0xFF14171B) : const Color(0xFFEFF2F5),\n        ),\n"""
new = """      body: Container(\n        decoration: BoxDecoration(\n          color: Color(appTheme.backgroundSeed),\n          gradient: LinearGradient(\n            begin: Alignment.topCenter,\n            end: Alignment.bottomCenter,\n            colors: [\n              Color(appTheme.backgroundSeed).withValues(alpha: .98),\n              Color(appTheme.backgroundSeed).withValues(alpha: .90),\n            ],\n          ),\n        ),\n"""
if old not in s:
    raise SystemExit('ChatPage background pattern not found')
s = s.replace(old, new, 1)

# Keep message bubbles readable on dark backgrounds.
old = """  Widget _glassMessageBubble(Map<String, dynamic> m) {\n    final scheme = Theme.of(context).colorScheme;\n"""
new = """  Widget _glassMessageBubble(Map<String, dynamic> m) {\n    final scheme = Theme.of(context).colorScheme;\n    final chatBackground = Color(appTheme.backgroundSeed);\n    final isDarkBackground = ThemeData.estimateBrightnessForColor(chatBackground) == Brightness.dark;\n"""
if old in s:
    s = s.replace(old, new, 1)
    # Add local contrast vars only where the bubble already computes mine.
    marker = """    final mine = m['sender_id'] == supabase.auth.currentUser?.id;\n"""
    replacement = """    final mine = m['sender_id'] == supabase.auth.currentUser?.id;\n    final bubbleTextColor = isDarkBackground ? Colors.white : Colors.black87;\n"""
    if marker in s:
        s = s.replace(marker, replacement, 1)
        # Only replace plain bubble text color literals inside the bubble method region.
        start = s.index("  Widget _glassMessageBubble")
        end = s.index("  Future<void> sendText", start) if "  Future<void> sendText" in s[start:] else min(len(s), start + 16000)
        region = s[start:end]
        region = region.replace("color: mine ? Colors.white : Colors.black87", "color: mine ? Colors.white : bubbleTextColor")
        s = s[:start] + region + s[end:]

# Wire the global appearance toggle into MaterialApp so dark mode is real, not local UI state.
old = """      theme: ThemeData(\n        useMaterial3: true,\n"""
new = """      themeMode: appTheme.dark ? ThemeMode.dark : ThemeMode.light,\n      theme: ThemeData(\n        useMaterial3: true,\n"""
if old in s and "themeMode: appTheme.dark ? ThemeMode.dark : ThemeMode.light" not in s:
    s = s.replace(old, new, 1)

# Add a matching dark theme before MaterialApp's closing theme configuration.
needle = """        ),\n      ),\n    );\n  }\n}\n\nclass AuthGate"""
dark_block = """        ),\n      ),\n      darkTheme: ThemeData(\n        useMaterial3: true,\n        fontFamily: 'Vazirmatn',\n        brightness: Brightness.dark,\n        colorScheme: ColorScheme.fromSeed(seedColor: Color(appTheme.seed), brightness: Brightness.dark),\n        scaffoldBackgroundColor: const Color(0xFF101318),\n        appBarTheme: const AppBarTheme(\n          elevation: 0,\n          scrolledUnderElevation: 0,\n          backgroundColor: Color(0xD914171C),\n          surfaceTintColor: Colors.transparent,\n        ),\n        cardTheme: CardThemeData(\n          elevation: 2,\n          color: Color(0xB81E232A),\n          surfaceTintColor: Colors.transparent,\n          margin: EdgeInsets.zero,\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),\n        ),\n        inputDecorationTheme: InputDecorationTheme(\n          filled: true,\n          fillColor: Color(0xB81E232A),\n          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15))),\n        ),\n      ),\n    );\n  }\n}\n\nclass AuthGate"""
if needle in s and "darkTheme: ThemeData(" not in s:
    s = s.replace(needle, dark_block, 1)

main.write_text(s, encoding='utf-8')

bg = Path('lib/chat_background_page.dart')
b = bg.read_text(encoding='utf-8')
b = b.replace("value == 0x20242B || value == 0x111827", "value == 0xFF20242B || value == 0xFF111827")
bg.write_text(b, encoding='utf-8')

# Source-level guardrails.
assert "appTheme.addListener(_onAppThemeChanged);" in s
assert "Color(appTheme.backgroundSeed)" in s
assert "themeMode: appTheme.dark ? ThemeMode.dark : ThemeMode.light" in s
assert "darkTheme: ThemeData(" in s
assert "0xFF20242B" in b and "0xFF111827" in b
print('chat visual/theme patch applied')
