from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Telegram-inspired visual language: clean surfaces, blue accent, compact controls,
# subtle separators and consistent rounded touch targets. This intentionally does not
# copy Telegram's proprietary assets or exact UI.
s = s.replace(
"""        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17181C),
          ),
          iconTheme: IconThemeData(color: Color(0xFF30323A)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE6E8EF)),
          ),
        ),""",
"""        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17212B),
          ),
          iconTheme: IconThemeData(color: Color(0xFF229ED9)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          dense: false,
          minVerticalPadding: 8,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          iconColor: Color(0xFF229ED9),
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF17212B)),
          subtitleTextStyle: TextStyle(fontSize: 13, color: Color(0xFF718096)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        ),
        dividerTheme: const DividerThemeData(
          space: 1,
          thickness: 1,
          indent: 72,
          color: Color(0xFFE7ECF2),
        ),""",
1,
)

# Replace the seed color only if an earlier selectable-theme patch did not already
# control it. The runtime theme controller remains authoritative when present.
s = s.replace("seedColor: const Color(0xFF4F46E5),", "seedColor: const Color(0xFF229ED9),", 1)
s = s.replace("borderSide: BorderSide(color: Color(0xFFD9DCE6)),", "borderSide: BorderSide(color: Color(0xFFDCE4EC)),", 2)
s = s.replace("borderSide: BorderSide(color: Color(0xFF4F46E5), width: 1.8),", "borderSide: BorderSide(color: Color(0xFF229ED9), width: 1.8),", 1)

# Make the profile/settings page feel like a native messenger settings screen:
# keep all existing options and functionality, but add section cards around the list.
old = """          const Divider(),
          const SizedBox(height: 8),
          const Text('تنظیمات پروفایل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),"""
new = """          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تنظیمات Arad', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      SizedBox(height: 3),
                      Text('شخصی‌سازی، حریم خصوصی و امکانات برنامه', style: TextStyle(fontSize: 12, color: Color(0xFF718096))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('تنظیمات پروفایل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),"""
if old in s:
    s = s.replace(old, new, 1)

# Give the profile header a cleaner Telegram-like identity card.
old_header = """          Text('${p['display_name'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('@${p['username'] ?? ''}'),
          const SizedBox(height: 8),
          Text('${p['bio'] ?? ''}'),
          const SizedBox(height: 30),"""
new_header = """          const SizedBox(height: 10),
          Text('${p['display_name'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF17212B))),
          const SizedBox(height: 2),
          Text('@${p['username'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF229ED9), fontWeight: FontWeight.w700)),
          if ('${p['bio'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('${p['bio'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF718096))),
          ],
          const SizedBox(height: 22),"""
if old_header in s:
    s = s.replace(old_header, new_header, 1)

p.write_text(s, encoding='utf-8')
