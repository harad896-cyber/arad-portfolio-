from pathlib import Path
import re

p = Path('lib/main.dart')
s = p.read_text(encoding='utf-8')

# Owner dashboard: add a broadcast/announcement button.
marker = "appBar: AppBar(title: const Text('مدیریت مالک'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),"
if marker in s and "tooltip: 'پیام همگانی'" not in s:
    s = s.replace(marker, "appBar: AppBar(title: const Text('مدیریت مالک'), actions: [IconButton(tooltip: 'پیام همگانی', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerBroadcastPage())), icon: const Icon(Icons.campaign_rounded)), IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))]),", 1)

# Publish page.
if 'class OwnerBroadcastPage extends StatefulWidget' not in s:
    s += r'''

class OwnerBroadcastPage extends StatefulWidget {
  const OwnerBroadcastPage({super.key});
  @override
  State<OwnerBroadcastPage> createState() => _OwnerBroadcastPageState();
}

class _OwnerBroadcastPageState extends State<OwnerBroadcastPage> {
  final title = TextEditingController();
  final body = TextEditingController();
  final link = TextEditingController();
  bool sending = false;

  Future<void> publish() async {
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      showMsg(context, 'عنوان و متن پیام را وارد کنید.');
      return;
    }
    setState(() => sending = true);
    try {
      await supabase.rpc('owner_create_announcement', params: {
        'p_title': title.text.trim(),
        'p_body': body.text.trim(),
        'p_link_url': link.text.trim().isEmpty ? null : link.text.trim(),
      });
      if (mounted) {
        showMsg(context, 'پیام همگانی برای همه کاربران منتشر شد.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) showMsg(context, 'انتشار پیام ناموفق بود.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    title.dispose(); body.dispose(); link.dispose(); super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پیام همگانی')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20)), child: const Row(children: [Icon(Icons.campaign_rounded, size: 34), SizedBox(width: 12), Expanded(child: Text('هر چیزی اینجا منتشر کنید، به‌عنوان اطلاعیه/تبلیغ برای همه کاربران نمایش داده می‌شود.', style: TextStyle(fontWeight: FontWeight.w800)))])),
      const SizedBox(height: 18),
      TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان پیام', prefixIcon: Icon(Icons.title_rounded))),
      const SizedBox(height: 12),
      TextField(controller: body, maxLines: 6, decoration: const InputDecoration(labelText: 'متن پیام همگانی', hintText: 'متن اطلاعیه، تبلیغ یا خبر را بنویسید.')),
      const SizedBox(height: 12),
      TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'لینک اختیاری', hintText: 'https://... ', prefixIcon: Icon(Icons.link_rounded))),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: sending ? null : publish, icon: const Icon(Icons.send_rounded), label: Text(sending ? 'در حال انتشار...' : 'انتشار برای همه')),
    ]),
  );
}

class GlobalAnnouncementGate extends StatefulWidget {
  final Widget child;
  const GlobalAnnouncementGate({super.key, required this.child});
  @override
  State<GlobalAnnouncementGate> createState() => _GlobalAnnouncementGateState();
}

class _GlobalAnnouncementGateState extends State<GlobalAnnouncementGate> {
  bool shown = false;
  Future<void> check() async {
    if (shown || supabase.auth.currentUser == null) return;
    try {
      final row = await supabase.from('announcements').select('id,title,body,link_url,created_at').eq('is_active', true).order('created_at', ascending: false).limit(1).maybeSingle();
      if (row == null || !mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final id = '${row['id']}';
      if (prefs.getString('arad_last_announcement_seen') == id) return;
      await prefs.setString('arad_last_announcement_seen', id);
      shown = true;
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (d) => AlertDialog(
        title: Row(children: [Icon(Icons.campaign_rounded, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Expanded(child: Text('${row['title']}'))]),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${row['body']}'), if ('${row['link_url'] ?? ''}'.trim().isNotEmpty) ...[const SizedBox(height: 14), SelectableText('${row['link_url']}')]])),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('بستن'))],
      ));
    } catch (_) {}
  }
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => check()); }
  @override
  Widget build(BuildContext context) => widget.child;
}
'''

# Wrap the authenticated home with the announcement gate.
needle = "return snapshot.data! ? const OwnerAwareHomePage() : const ProfileSetupPage();"
if needle in s and 'GlobalAnnouncementGate(child:' not in s:
    s = s.replace(needle, "return snapshot.data! ? const GlobalAnnouncementGate(child: OwnerAwareHomePage()) : const ProfileSetupPage();", 1)

p.write_text(s, encoding='utf-8')
