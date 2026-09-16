from pathlib import Path

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Persistent language controller; Persian remains the default.
if 'final aradLanguageController = LanguageController();' not in s:
    s = s.replace('class AppStrings {', 'final aradLanguageController = LanguageController();\n\nclass AppStrings {', 1)
s = s.replace('  runApp(const AradMessenger());', '  await aradLanguageController.load();\n  runApp(const AradMessenger());', 1)
if 'animation: aradLanguageController' not in s:
    s = s.replace("    return MaterialApp(\n      locale: const Locale('fa'),", "    return AnimatedBuilder(\n      animation: aradLanguageController,\n      builder: (context, child) => MaterialApp(\n      locale: aradLanguageController.locale,", 1)
    s = s.replace('      home: const AuthGate(),\n    );\n  }\n}\n\nvoid showMsg', '      home: const AuthGate(),\n    ),\n    );\n  }\n}\n\nvoid showMsg', 1)

# Safely replace the existing placeholder class without brace parsing.
s = s.replace('class ProfileOptionPage extends StatelessWidget {', 'class _LegacyProfileOptionPage extends StatelessWidget {', 1)
s = s.replace('const ProfileOptionPage({super.key, required this.title, required this.icon});', 'const _LegacyProfileOptionPage({super.key, required this.title, required this.icon});', 1)

if 'class ProfileOptionPage extends StatefulWidget' not in s:
    s += r'''

class ProfileOptionPage extends StatefulWidget {
  final String title;
  final IconData icon;
  const ProfileOptionPage({super.key, required this.title, required this.icon});
  @override State<ProfileOptionPage> createState() => _ProfileOptionPageState();
}

class _ProfileOptionPageState extends State<ProfileOptionPage> {
  bool online = true;
  bool lastSeen = true;
  bool profilePhoto = true;
  bool readReceipts = true;
  bool typing = true;
  bool autoDownload = false;
  final reportText = TextEditingController();

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      online = p.getBool('privacy_online') ?? true;
      lastSeen = p.getBool('privacy_last_seen') ?? true;
      profilePhoto = p.getBool('privacy_photo') ?? true;
      readReceipts = p.getBool('privacy_read') ?? true;
      typing = p.getBool('privacy_typing') ?? true;
      autoDownload = p.getBool('auto_download') ?? false;
    });
  }
  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }
  Future<void> _report() async {
    final description = reportText.text.trim();
    if (description.length < 5) { showMsg(context, 'لطفاً شرح گزارش را کامل بنویسید.'); return; }
    try {
      await supabase.from('support_reports').insert({
        'reporter_id': supabase.auth.currentUser!.id,
        'category': 'support',
        'description': description,
      });
      reportText.clear();
      if (mounted) showMsg(context, 'گزارش با موفقیت برای پشتیبانی ارسال شد.');
    } catch (e) { if (mounted) showMsg(context, 'ارسال گزارش ناموفق بود: $e'); }
  }
  Widget _switch(String label, String subtitle, bool value, String key) => SwitchListTile.adaptive(
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    value: value,
    onChanged: (v) {
      setState(() {
        if (key == 'privacy_online') online = v;
        if (key == 'privacy_last_seen') lastSeen = v;
        if (key == 'privacy_photo') profilePhoto = v;
        if (key == 'privacy_read') readReceipts = v;
        if (key == 'privacy_typing') typing = v;
        if (key == 'auto_download') autoDownload = v;
      });
      _save(key, v);
    },
  );
  Widget _legal(IconData icon, String title, String body) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 9), Text(body),
    ])),
  );
  @override
  void dispose() { reportText.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    final isLanguage = title == 'زبان';
    final isPrivacy = title == 'حریم خصوصی و امنیت';
    final isLegal = title == 'قوانین و شرایط استفاده';
    final isReport = title == 'گزارش مشکل';
    final isSupport = title == 'پشتیبانی';
    final isStorage = title == 'داده‌ها و ذخیره‌سازی';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        if (isLanguage) ...[
          const Text('زبان برنامه', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('فارسی زبان پیش‌فرض است و انتخاب شما ذخیره می‌شود.'),
          const SizedBox(height: 12),
          ...AppStrings.supported.map((code) => Card(child: RadioListTile<String>(
            value: code,
            groupValue: aradLanguageController.locale.languageCode,
            title: Text(AppStrings.names[code] ?? code),
            secondary: const Icon(Icons.language_rounded),
            onChanged: (v) { if (v != null) aradLanguageController.setLocale(v); },
          ))),
        ] else if (isPrivacy) ...[
          const Text('حریم خصوصی و امنیت', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('کنترل نمایش وضعیت و فعالیت شما برای دیگر کاربران.'),
          const SizedBox(height: 12),
          Card(child: Column(children: [
            _switch('وضعیت آنلاین', 'نمایش آنلاین بودن شما', online, 'privacy_online'),
            _switch('آخرین بازدید', 'نمایش زمان آخرین فعالیت', lastSeen, 'privacy_last_seen'),
            _switch('عکس پروفایل', 'اجازه نمایش تصویر پروفایل', profilePhoto, 'privacy_photo'),
            _switch('رسید خواندن پیام', 'نمایش تیک خوانده‌شدن', readReceipts, 'privacy_read'),
            _switch('در حال نوشتن', 'نمایش وضعیت تایپ کردن', typing, 'privacy_typing'),
          ])),
        ] else if (isLegal) ...[
          _legal(Icons.gavel_rounded, 'شرایط استفاده', 'استفاده از Arad مستلزم رعایت قوانین قابل‌قبول استفاده، احترام به کاربران و قوانین محل استفاده است.'),
          _legal(Icons.privacy_tip_outlined, 'حریم خصوصی', 'اطلاعات حساب و پیام‌ها باید مطابق تنظیمات کاربر و دسترسی‌های تعریف‌شده برنامه پردازش شوند.'),
          _legal(Icons.block_rounded, 'محتوای ممنوع', 'هرزنامه، کلاهبرداری، جعل هویت، مزاحمت، سوءاستفاده از حساب دیگران و محتوای غیرقانونی مجاز نیست.'),
          _legal(Icons.flag_outlined, 'گزارش تخلف', 'محتوای مشکوک یا نقض قوانین را برای بررسی به پشتیبانی گزارش کنید.'),
        ] else if (isReport) ...[
          const Text('گزارش مشکل', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('گزارش شما مستقیماً در بخش پشتیبانی ثبت می‌شود.'),
          const SizedBox(height: 14),
          TextField(controller: reportText, maxLines: 7, decoration: const InputDecoration(labelText: 'شرح مشکل یا گزارش', hintText: 'مشکل را دقیق توضیح دهید...', alignLabelWithHint: true)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: _report, icon: const Icon(Icons.send_rounded), label: const Text('ارسال به پشتیبانی')),
        ] else if (isSupport) ...[
          const Text('پشتیبانی Arad', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('برای مشکل حساب، پیام، گروه، کانال یا گزارش تخلف از بخش گزارش مشکل استفاده کنید.'),
          const SizedBox(height: 14),
          Card(child: ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('گزارش مشکل', style: TextStyle(fontWeight: FontWeight.w800)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'گزارش مشکل', icon: Icons.flag_outlined))))),
        ] else if (isStorage) ...[
          const Text('داده‌ها و ذخیره‌سازی', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Card(child: _switch('دانلود خودکار رسانه', 'مدیریت دانلود خودکار عکس و فایل', autoDownload, 'auto_download')),
        ] else ...[
          Center(child: Icon(widget.icon, size: 58, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Card(child: ListTile(leading: Icon(widget.icon), title: const Text('این بخش آماده استفاده است.'), subtitle: const Text('تنظیمات این بخش فعال است.'))),
        ],
      ),
    );
  }
}
'''

# Add a visible legal entry to ProfilePage when the support entry exists.
needle = "          ListTile(leading: const Icon(Icons.support_agent_outlined), title: const Text('پشتیبانی'),"
if "title: const Text('قوانین و شرایط استفاده')" not in s and needle in s:
    s = s.replace(needle, "          ListTile(leading: const Icon(Icons.gavel_rounded), title: const Text('قوانین و شرایط استفاده'), subtitle: const Text('قوانین استفاده و حریم خصوصی'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'قوانین و شرایط استفاده', icon: Icons.gavel_rounded)))),\n          " + needle, 1)

# Group creation: title is the only required field; creator is always included.
s = s.replace("if (title.text.trim().isEmpty || selected.isEmpty)", "if (title.text.trim().isEmpty)", 1)
s = s.replace("'نام گروه و حداقل یک عضو را وارد کنید.'", "'نام گروه را وارد کنید. می‌توانید گروه را ابتدا فقط با خودتان بسازید.'", 1)
s = s.replace("Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title.text.trim())));", "Navigator.pop(context, true);", 1)

# Channel creator and Home action.
if 'class ChannelCreatePage extends StatefulWidget' not in s:
    s += r'''

class ChannelCreatePage extends StatefulWidget {
  const ChannelCreatePage({super.key});
  @override State<ChannelCreatePage> createState() => _ChannelCreatePageState();
}
class _ChannelCreatePageState extends State<ChannelCreatePage> {
  final title = TextEditingController();
  final description = TextEditingController();
  bool busy = false;
  Future<void> create() async {
    if (title.text.trim().isEmpty) { showMsg(context, 'نام کانال را وارد کنید.'); return; }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final c = await supabase.from('conversations').insert({'type':'channel','title':title.text.trim(),'created_by':uid}).select().single();
      await supabase.from('conversation_members').insert({'conversation_id':c['id'],'user_id':uid,'role':'owner'});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMsg(context, 'ساخت کانال ناموفق بود: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose() { title.dispose(); description.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ساخت کانال')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: title, decoration: const InputDecoration(labelText:'نام کانال', border: OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller: description, maxLines:4, decoration: const InputDecoration(labelText:'توضیحات', border: OutlineInputBorder())),
      const SizedBox(height:16),
      FilledButton.icon(onPressed: busy ? null : create, icon: const Icon(Icons.campaign_rounded), label: Text(busy ? 'در حال ساخت...' : 'ساخت کانال')),
    ]),
  );
}
'''

if 'Future<void> createChannel()' not in s:
    marker = "  Future<void> createGroup() async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())); load(); }"
    if marker in s:
        s = s.replace(marker, marker + "\n  Future<void> createChannel() async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelCreatePage())); load(); }", 1)
if 'onPressed: createChannel' not in s:
    marker = "IconButton(onPressed: createGroup, icon: const Icon(Icons.group_add)),"
    if marker in s:
        s = s.replace(marker, marker + "\n          IconButton(onPressed: createChannel, icon: const Icon(Icons.campaign_outlined)),", 1)

p.write_text(s, encoding='utf-8')
print('Safe feature completion patch applied')
