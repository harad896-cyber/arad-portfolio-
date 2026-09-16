from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Persistent language: Persian is the default, and changing it rebuilds the app.
if 'final aradLanguageController = LanguageController();' not in s:
    s = s.replace('class AppStrings {', 'final aradLanguageController = LanguageController();\n\nclass AppStrings {', 1)
s = s.replace("  runApp(const AradMessenger());", "  await aradLanguageController.load();\n  runApp(const AradMessenger());", 1)
if 'AnimatedBuilder(animation: aradLanguageController' not in s:
    s = s.replace('    return MaterialApp(\n      locale: const Locale(\'fa\'),', "    return AnimatedBuilder(\n      animation: aradLanguageController,\n      builder: (context, child) => MaterialApp(\n      locale: aradLanguageController.locale,", 1)
    s = s.replace('      home: const AuthGate(),\n    );\n  }\n}\n\nvoid showMsg', '      home: const AuthGate(),\n    ),\n    );\n  }\n}\n\nvoid showMsg', 1)

# Remove the old empty option page and replace it with functional settings/legal/support screens.
pos = s.find('class ProfileOptionPage extends StatelessWidget {')
if pos >= 0:
    end = s.find('}', pos)
    # Find the actual final class closing by counting braces.
    depth = 0; i = pos; started = False; close = None
    while i < len(s):
        ch = s[i]
        if ch == '{': depth += 1; started = True
        elif ch == '}':
            depth -= 1
            if started and depth == 0:
                close = i + 1; break
        i += 1
    if close:
        replacement = r'''class ProfileOptionPage extends StatefulWidget {
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
  Future<void> _set(String key, bool value) async {
    final p = await SharedPreferences.getInstance(); await p.setBool(key, value);
  }
  Future<void> _report() async {
    final text = reportText.text.trim();
    if (text.length < 5) { showMsg(context, 'لطفاً توضیح گزارش را کامل بنویسید.'); return; }
    try {
      await supabase.from('support_reports').insert({'reporter_id': supabase.auth.currentUser!.id, 'category': 'support', 'description': text});
      reportText.clear(); if (mounted) { showMsg(context, 'گزارش با موفقیت به پشتیبانی ارسال شد.'); }
    } catch (e) { if (mounted) showMsg(context, 'ارسال گزارش ناموفق بود: $e'); }
  }
  Widget _switch(String label, String subtitle, bool value, String key, ValueChanged<bool> onChanged) => SwitchListTile.adaptive(
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), value: value,
    onChanged: (v) { onChanged(v); _set(key, v); },
  );
  @override void dispose() { reportText.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final t = widget.title;
    final isLang = t == 'زبان';
    final isPrivacy = t == 'حریم خصوصی و امنیت';
    final isLegal = t == 'قوانین و شرایط استفاده';
    final isReport = t == 'گزارش مشکل';
    final isSupport = t == 'پشتیبانی';
    return Scaffold(
      appBar: AppBar(title: Text(t)),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 30), children: [
        if (isLang) ...[
          const Text('زبان برنامه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8), const Text('فارسی به‌صورت پیش‌فرض فعال است. زبان انتخابی در برنامه ذخیره می‌شود.'), const SizedBox(height: 14),
          ...AppStrings.supported.map((code) => Card(child: RadioListTile<String>(value: code, groupValue: aradLanguageController.locale.languageCode, title: Text(AppStrings.names[code] ?? code), secondary: const Icon(Icons.language_rounded), onChanged: (v) async { if (v != null) await aradLanguageController.setLocale(v); }))),
        ] else if (isPrivacy) ...[
          const Text('حریم خصوصی و امنیت', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
          const Text('کنترل کنید چه اطلاعاتی از وضعیت و فعالیت شما برای دیگران نمایش داده شود.'), const SizedBox(height: 12),
          Card(child: Column(children: [
            _switch('وضعیت آنلاین', 'نمایش آنلاین بودن شما', online, 'privacy_online', (v) => setState(() => online = v)),
            _switch('آخرین بازدید', 'نمایش آخرین زمان فعالیت', lastSeen, 'privacy_last_seen', (v) => setState(() => lastSeen = v)),
            _switch('عکس پروفایل', 'اجازه نمایش تصویر پروفایل', profilePhoto, 'privacy_photo', (v) => setState(() => profilePhoto = v)),
            _switch('رسید خواندن پیام', 'نمایش تیک خوانده‌شدن', readReceipts, 'privacy_read', (v) => setState(() => readReceipts = v)),
            _switch('در حال نوشتن', 'نمایش وضعیت تایپ کردن', typing, 'privacy_typing', (v) => setState(() => typing = v)),
          ])),
          const SizedBox(height: 14), Card(child: ListTile(leading: const Icon(Icons.security_rounded), title: const Text('امنیت حساب', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('کد ورود و اطلاعات حساب را با دیگران به اشتراک نگذارید.'))),
        ] else if (isLegal) ...[
          _legalCard(Icons.gavel_rounded, 'شرایط استفاده', 'با استفاده از Arad باید قوانین قابل‌قبول استفاده، احترام به کاربران و قوانین محل استفاده رعایت شود.'),
          _legalCard(Icons.privacy_tip_outlined, 'حریم خصوصی', 'اطلاعات حساب و پیام‌ها باید فقط در چارچوب دسترسی‌های تعریف‌شده برنامه و تنظیمات کاربر پردازش شوند.'),
          _legalCard(Icons.block_rounded, 'محتوای ممنوع', 'هرزنامه، کلاهبرداری، جعل هویت، مزاحمت، سوءاستفاده از حساب دیگران و محتوای غیرقانونی مجاز نیست.'),
          _legalCard(Icons.flag_outlined, 'گزارش تخلف', 'برای محتوای مشکوک یا نقض قوانین، از گزینه گزارش استفاده کنید تا درخواست به پشتیبانی ارسال شود.'),
        ] else if (isReport || isSupport) ...[
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.support_agent_rounded, size: 30), const SizedBox(width: 10), Expanded(child: Text(isReport ? 'گزارش شما مستقیماً در صف پشتیبانی Arad ثبت می‌شود.' : 'پشتیبانی Arad برای مشکلات حساب، پیام‌ها و گزارش‌ها در دسترس است.', style: const TextStyle(fontWeight: FontWeight.w800)))])),
          const SizedBox(height: 14),
          if (isSupport) ...[
            Card(child: ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('گزارش مشکل', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: const Text('گزارش خود را برای بررسی پشتیبانی ارسال کنید.'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'گزارش مشکل', icon: Icons.flag_outlined))))),
            Card(child: ListTile(leading: const Icon(Icons.help_outline_rounded), title: const Text('راهنمای سریع'), subtitle: const Text('برای خطاهای ورود، پیام، گروه و کانال ابتدا برنامه را به آخرین نسخه به‌روزرسانی کنید.'))),
          ] else ...[
            TextField(controller: reportText, maxLines: 7, decoration: const InputDecoration(labelText: 'شرح مشکل یا گزارش', hintText: 'مشکل را دقیق توضیح دهید...', alignLabelWithHint: true)),
            const SizedBox(height: 14), FilledButton.icon(onPressed: _report, icon: const Icon(Icons.send_rounded), label: const Text('ارسال به پشتیبانی')),
          ],
        ] else ...[
          Center(child: Icon(widget.icon, size: 58, color: Theme.of(context).colorScheme.primary)), const SizedBox(height: 14),
          Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
          if (t == 'داده‌ها و ذخیره‌سازی') ...[
            Card(child: _switch('دانلود خودکار رسانه', 'عکس و فایل بدون درخواست شما دانلود نشود', autoDownload, 'auto_download', (v) => setState(() => autoDownload = v))),
            Card(child: ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('پاک‌سازی داده‌های موقت'), subtitle: const Text('تنظیمات محلی قابل پاک‌سازی هستند.'), onTap: () async { final p = await SharedPreferences.getInstance(); await p.remove('arad_seen_announcement'); if (mounted) showMsg(context, 'داده‌های موقت پاک‌سازی شد.'); })),
          ] else Card(child: ListTile(leading: Icon(widget.icon), title: Text('این بخش آماده استفاده است.'), subtitle: const Text('تنظیمات مربوط به این بخش در نسخه‌های بعدی گسترده‌تر می‌شوند.'))),
        ],
      ),
    );
  }
  Widget _legalCard(IconData icon, String title, String text) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]), const SizedBox(height: 9), Text(text)])));
}
'''
        s = s[:pos] + replacement + s[close:]

# Add legal/report entries to profile settings if not already present.
needle = "          ListTile(leading: const Icon(Icons.support_agent_outlined), title: const Text('پشتیبانی'),"
if "title: const Text('قوانین و شرایط استفاده')" not in s and needle in s:
    s = s.replace(needle, "          ListTile(leading: const Icon(Icons.gavel_rounded), title: const Text('قوانین و شرایط استفاده'), subtitle: const Text('قوانین استفاده و حریم خصوصی'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileOptionPage(title: 'قوانین و شرایط استفاده', icon: Icons.gavel_rounded)))),\n          " + needle, 1)

# Make group creation return to Home so the new group immediately appears in the chat list.
s = s.replace("        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatPage(id: '${c['id']}', title: title.text.trim())));", "        Navigator.pop(context, true);", 1)

# Remove any hidden five-member validation text/condition from group creation.
s = s.replace("if (title.text.trim().isEmpty || selected.isEmpty)", "if (title.text.trim().isEmpty)", 1)
s = s.replace("'نام گروه و حداقل یک عضو را وارد کنید.'", "'نام گروه را وارد کنید. می‌توانید گروه را ابتدا فقط با خودتان بسازید و بعداً عضو اضافه کنید.'", 1)

# Add a dedicated channel creator and a channel button to Home.
if 'class ChannelCreatePage extends StatefulWidget' not in s:
    channel = r'''

class ChannelCreatePage extends StatefulWidget {
  const ChannelCreatePage({super.key});
  @override State<ChannelCreatePage> createState() => _ChannelCreatePageState();
}
class _ChannelCreatePageState extends State<ChannelCreatePage> {
  final title = TextEditingController(); final description = TextEditingController(); bool busy = false;
  Future<void> create() async {
    if (title.text.trim().isEmpty) { showMsg(context, 'نام کانال را وارد کنید.'); return; }
    setState(() => busy = true);
    try {
      final uid = supabase.auth.currentUser!.id;
      final c = await supabase.from('conversations').insert({'type':'channel','title':title.text.trim(),'created_by':uid}).select().single();
      await supabase.from('conversation_members').insert({'conversation_id':c['id'],'user_id':uid,'role':'owner'});
      if (mounted) Navigator.pop(context, true);
    } catch (e) { if (mounted) showMsg(context, 'ساخت کانال ناموفق بود: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override void dispose(){title.dispose();description.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('ساخت کانال')),body:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(18)),child:const Text('کانال بعد از ساخت فوراً در فهرست گفتگوها نمایش داده می‌شود.',style:TextStyle(fontWeight:FontWeight.w800))),const SizedBox(height:16),TextField(controller:title,decoration:const InputDecoration(labelText:'نام کانال',prefixIcon:Icon(Icons.campaign_rounded))),const SizedBox(height:12),TextField(controller:description,maxLines:4,decoration:const InputDecoration(labelText:'توضیح کانال',alignLabelWithHint:true)),const SizedBox(height:18),FilledButton.icon(onPressed:busy?null:create,icon:const Icon(Icons.campaign_rounded),label:Text(busy?'در حال ساخت...':'ساخت کانال'))]));
}
'''
    marker = 'class ChatPage extends StatefulWidget {'
    s = s.replace(marker, channel + '\n' + marker, 1)

# Home: channel creation method and button.
if 'Future<void> createChannel() async' not in s:
    s = s.replace("  Future<void> createGroup() async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())); load(); }", "  Future<void> createGroup() async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())); load(); }\n  Future<void> createChannel() async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChannelCreatePage())); load(); }", 1)
s = s.replace("          IconButton(onPressed: createGroup, icon: const Icon(Icons.group_add)),", "          IconButton(tooltip: 'ساخت گروه', onPressed: createGroup, icon: const Icon(Icons.group_add)),\n          IconButton(tooltip: 'ساخت کانال', onPressed: createChannel, icon: const Icon(Icons.campaign_rounded)),", 1)

# Replace the Home empty-state helper text so it is accurate for groups/channels.
s = s.replace("const Text('با پیدا کردن یک کاربر، اولین گفتگوی خود را شروع کنید.', textAlign: TextAlign.center),", "Text(selectedFilter == 2 ? 'گروه را حتی بدون عضو دیگر بسازید و بعداً اعضا را اضافه کنید.' : selectedFilter == 3 ? 'یک کانال بسازید تا بلافاصله در فهرست گفتگوها نمایش داده شود.' : 'با پیدا کردن یک کاربر، اولین گفتگوی خود را شروع کنید.', textAlign: TextAlign.center),", 1)

p.write_text(s, encoding='utf-8')
print('Feature completion patch applied')
