from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

page = r'''

class SecurityEfficiencyRulesPage extends StatelessWidget {
  const SecurityEfficiencyRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('قوانین و امنیت')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _RulesCard(
            icon: Icons.shield_outlined,
            title: 'امنیت حساب',
            items: const [
              'کد ورود و کد تأیید را با هیچ‌کس به اشتراک نگذارید.',
              'لینک‌ها و فایل‌های ناشناس را با احتیاط باز کنید.',
              'دسترسی‌های دوربین، میکروفون و فایل‌ها فقط برای قابلیت مربوطه استفاده می‌شوند.',
              'نشست‌ها و دستگاه‌های فعال را از بخش امنیت حساب بررسی کنید.',
              'اطلاعات خصوصی کاربران نباید بدون مجوز در اختیار دیگران قرار گیرد.',
            ],
          ),
          const SizedBox(height: 12),
          _RulesCard(
            icon: Icons.speed_outlined,
            title: 'مصرف کم اینترنت و باتری',
            items: const [
              'برنامه از دریافت و همگام‌سازی غیرضروری اطلاعات جلوگیری می‌کند.',
              'رسانه‌ها بدون نیاز کاربر به‌صورت خودکار دانلود نمی‌شوند.',
              'دانلود خودکار رسانه‌ها را می‌توان برای اینترنت همراه یا Wi‑Fi تنظیم کرد.',
              'تصاویر و فایل‌ها تا حد امکان بهینه می‌شوند تا مصرف داده کاهش یابد.',
              'کش و داده‌های موقت قابل مدیریت و پاک‌سازی هستند.',
              'فعالیت‌های پس‌زمینه تا حد امکان محدود می‌شوند تا مصرف باتری کاهش پیدا کند.',
            ],
          ),
          const SizedBox(height: 12),
          _RulesCard(
            icon: Icons.rule_outlined,
            title: 'قوانین استفاده',
            items: const [
              'از Arad برای مزاحمت، کلاهبرداری، ارسال هرزنامه یا فعالیت غیرقانونی استفاده نکنید.',
              'به حریم خصوصی، حساب و اطلاعات سایر کاربران احترام بگذارید.',
              'محتوای مشکوک یا سوءاستفاده را از قابلیت گزارش پیام اعلام کنید.',
              'Arad هیچ تضمین مطلقی برای امنیت در برابر همه تهدیدهای خارج از کنترل برنامه ارائه نمی‌کند؛ امنیت دستگاه و حساب نیز بر عهده کاربر است.',
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded),
                SizedBox(width: 10),
                Expanded(child: Text('این بخش برای اطلاع‌رسانی امنیتی و مصرف منابع است و جایگزین تنظیمات حریم خصوصی حساب نمی‌شود.')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  const _RulesCard({required this.icon, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 10),
            ...items.map((x) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 5), child: Icon(Icons.circle, size: 6)),
                const SizedBox(width: 9),
                Expanded(child: Text(x)),
              ]),
            )),
          ],
        ),
      ),
    );
  }
}
'''

if 'class SecurityEfficiencyRulesPage' not in s:
    s += page

helper = """
void openSecurityEfficiencyRules(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityEfficiencyRulesPage()));
}
"""
if 'void openSecurityEfficiencyRules(' not in s:
    s += '\n' + helper

needle = "const Text('تنظیمات پروفایل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),"
entry = needle + """
          const SizedBox(height: 6),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('قوانین و امنیت'),
            subtitle: const Text('امنیت حساب، حریم خصوصی و مصرف کم منابع'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => openSecurityEfficiencyRules(context),
          ),"""
if "title: const Text('قوانین و امنیت')" not in s and needle in s:
    s = s.replace(needle, entry, 1)

# Final compile cleanup: remove a duplicate DividerThemeData declaration if two
# identical blocks were injected by the theme/UI patches.
block = '''        dividerTheme: const DividerThemeData(\n          space: 1,\n          thickness: 1,\n          indent: 72,\n          color: Color(0xFFE7ECF2),\n        ),\n'''
first = s.find(block)
if first >= 0:
    second = s.find(block, first + len(block))
    if second >= 0:
        s = s[:second] + s[second + len(block):]

# The current media implementation does not use dart:io in main.dart.
s = s.replace("import 'dart:io';\n", '', 1)

p.write_text(s, encoding='utf-8')
