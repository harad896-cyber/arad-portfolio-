from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

marker = "class AradMessenger extends StatelessWidget {"
if marker not in s:
    raise SystemExit('AradMessenger marker not found')

if 'class ThemeController extends ChangeNotifier' not in s:
    controller = r'''
class ThemeController extends ChangeNotifier {
  static const _key = 'arad_theme_color_index';
  static const colors = <Color>[
    Color(0xFF229ED9), // آبی تلگرامی
    Color(0xFF4F46E5), // نیلی
    Color(0xFF2563EB), // آبی
    Color(0xFF7C3AED), // بنفش
    Color(0xFF059669), // سبز
    Color(0xFFDC2626), // قرمز
    Color(0xFFEA580C), // نارنجی
    Color(0xFFDB2777), // صورتی
    Color(0xFF0891B2), // فیروزه‌ای
  ];

  int index = 0;

  Color get seedColor => colors[index.clamp(0, colors.length - 1)];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null && saved >= 0 && saved < colors.length) {
      index = saved;
    }
    notifyListeners();
  }

  Future<void> setIndex(int value) async {
    if (value < 0 || value >= colors.length) return;
    index = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, value);
  }
}

'''
    s = s.replace(marker, controller + marker, 1)

old_app = '''class AradMessenger extends StatelessWidget {
  const AradMessenger({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('fa'),
      supportedLocales: AppStrings.supported.map((x) => Locale(x)),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      title: 'Arad Messenger',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,'''
new_app = '''class AradMessenger extends StatefulWidget {
  const AradMessenger({super.key});

  @override
  State<AradMessenger> createState() => _AradMessengerState();
}

class _AradMessengerState extends State<AradMessenger> {
  final ThemeController themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    themeController.addListener(_themeChanged);
    themeController.load();
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    themeController.removeListener(_themeChanged);
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('fa'),
      supportedLocales: AppStrings.supported.map((x) => Locale(x)),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      title: 'Arad Messenger',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeController.seedColor,
          brightness: Brightness.light,'''
if old_app not in s:
    raise SystemExit('AradMessenger theme block not found')
s = s.replace(old_app, new_app, 1)

profile_marker = 'class ProfilePage extends StatefulWidget {'
if profile_marker not in s:
    raise SystemExit('ProfilePage marker not found')
if 'class ThemeColorPage extends StatefulWidget' not in s:
    page = r'''
class ThemeColorPage extends StatefulWidget {
  const ThemeColorPage({super.key});

  @override
  State<ThemeColorPage> createState() => _ThemeColorPageState();
}

class _ThemeColorPageState extends State<ThemeColorPage> {
  int selected = 0;
  final ThemeController controller = ThemeController();

  static const names = [
    'آبی تلگرامی',
    'نیلی',
    'آبی',
    'بنفش',
    'سبز',
    'قرمز',
    'نارنجی',
    'صورتی',
    'فیروزه‌ای',
  ];

  @override
  void initState() {
    super.initState();
    controller.load().then((_) {
      if (mounted) setState(() => selected = controller.index);
    });
  }

  Future<void> choose(int index) async {
    setState(() => selected = index);
    await controller.setIndex(index);
    if (!mounted) return;
    Navigator.pop(context);
    showMsg(context, 'رنگ ${names[index]} انتخاب شد.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رنگ‌بندی برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('رنگ اصلی Arad Messenger را انتخاب کنید', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('انتخاب شما ذخیره می‌شود و بعد از باز کردن دوباره برنامه باقی می‌ماند.'),
          const SizedBox(height: 22),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ThemeController.colors.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.25),
            itemBuilder: (context, i) {
              final color = ThemeController.colors[i];
              final active = selected == i;
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => choose(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: active ? color : color.withValues(alpha: 0.25), width: active ? 3 : 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(radius: 17, backgroundColor: color, child: active ? const Icon(Icons.check, color: Colors.white, size: 20) : null),
                      const SizedBox(width: 10),
                      Text(names[i], style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

'''
    s = s.replace(profile_marker, page + profile_marker, 1)

needle = "ListTile(leading: const Icon(Icons.person_outline), title: const Text('حساب کاربری'), subtitle: const Text('نام، نام کاربری و اطلاعات حساب'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSetupPage()))),"
insert = needle + "\n          ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('رنگ‌بندی برنامه'), subtitle: const Text('انتخاب رنگ اصلی Arad Messenger'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ThemeColorPage()))),"
if needle not in s:
    raise SystemExit('Profile account ListTile not found')
s = s.replace(needle, insert, 1)

p.write_text(s, encoding='utf-8')
print('Applied Arad theme color selector with Telegram blue default')
